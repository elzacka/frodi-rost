import AVFoundation
import Foundation
import SwiftData

/// Where the audio files live, and how they are protected.
///
/// Two things are governed from here, and they pull in opposite directions:
/// the recording must be writable while the screen is locked, and the finished
/// file must not be readable while the screen is locked.
enum AudioStorage {
    /// The suffix of a sealed recording. A file without it is plaintext that is
    /// still waiting to be sealed; see `seal(fileName:)`.
    static let sealedSuffix = ".enc"

    static var directory: URL {
        let base = URL.documentsDirectory.appendingPathComponent("Opptak", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(
                at: base,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
            )
        }
        // Set every time, not only on creation. The flag can be reset by file
        // operations, and a folder made by an earlier version does not have it at all.
        excludeFromBackup(base)
        return base
    }

    /// Plaintext that exists only while a job runs: transcription and export.
    ///
    /// One folder, so it can be emptied at launch. Each job removes its own files
    /// in a `defer`, but a `defer` does not run if the process is killed, and a
    /// transcription can take minutes. Whatever a crash leaves behind is removed
    /// by `clearScratch()` the next time the app starts.
    static var scratchDirectory: URL {
        if !FileManager.default.fileExists(atPath: scratchURL.path) {
            try? FileManager.default.createDirectory(
                at: scratchURL,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
            )
        }
        return scratchURL
    }

    private static let scratchURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("Klartekst", isDirectory: true)

    /// Removes every temporary plaintext file. Called at launch, when no job is
    /// running and everything in the folder is a leftover.
    static func clearScratch() {
        try? FileManager.default.removeItem(at: scratchURL)
    }

    /// Protection while the recording runs.
    ///
    /// `completeUnlessOpen` lets a file that is already open keep being written
    /// after the screen locks. With `complete` the recording would have stopped the
    /// moment the device locked, which is exactly in the car, the whole point.
    static func protectWhileRecording(_ url: URL) {
        setProtection(.completeUnlessOpen, on: url)
    }

    /// Protection once the recording is finished.
    ///
    /// Now the file is closed, and `complete` is right: the content cannot be read
    /// while the device is locked, not even by something with physical access.
    static func protectFinished(_ url: URL) {
        setProtection(.complete, on: url)
        excludeFromBackup(url)
    }

    static func isSealed(_ fileName: String) -> Bool {
        fileName.hasSuffix(sealedSuffix)
    }

    /// The suffix of a recording in progress or waiting to be sealed: linear PCM in
    /// a CAF container, see `AudioRecorder.start`. Recordings made before build 6
    /// wait as `.m4a`, and `seal` takes both.
    static let pendingSuffix = ".caf"

    /// The name a plaintext file gets once sealed. Always `.m4a.enc`, whatever the
    /// plaintext was: a PCM recording is turned into AAC on the way.
    static func sealedName(for fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        return stem + ".m4a" + sealedSuffix
    }

    /// Seals a recording that is still plaintext, and returns its new file name.
    ///
    /// The plaintext is removed only once the sealed copy is written. If sealing
    /// fails, the plaintext stays where it is: it is `.completeUnlessOpen` and
    /// closed, so it cannot be read while the device is locked, and the caller
    /// tries again at the next unlock. Deleting it would lose the recording, and a
    /// delay is the lesser harm.
    ///
    /// Failing here is the expected outcome when the Action Button stops a
    /// recording on a locked device. A `.completeUnlessOpen` file cannot be
    /// reopened once closed until the device is unlocked, and a `.complete` file
    /// cannot be created at all. The Secure Enclave key would have been available,
    /// but the file classes are not. See `RecordingController.sealPending()`.
    ///
    /// A sealed copy that already exists is taken as finished: it is written
    /// atomically, so it is either whole or absent. That covers a crash between
    /// writing the copy and removing the plaintext, and a crash between removing
    /// the plaintext and saving the new name on the recording; either way the
    /// next pass lands here and gets the same answer.
    ///
    /// `@concurrent` for the same reason as `decryptToTemporary`: an hour of
    /// audio is many megabytes read, encoded, encrypted and written whole.
    @concurrent
    static func seal(fileName: String) async throws -> String {
        let source = directory.appendingPathComponent(fileName)
        let sealedName = sealedName(for: fileName)
        let target = directory.appendingPathComponent(sealedName)

        if !FileManager.default.fileExists(atPath: target.path) {
            let audio = fileName.hasSuffix(pendingSuffix)
                ? try await encodeToAAC(source)
                : source
            defer { if audio != source { try? FileManager.default.removeItem(at: audio) } }
            try RecordingVault.seal(fileAt: audio).write(to: target, options: [.atomic, .completeFileProtection])
        }
        try? FileManager.default.removeItem(at: source)
        protectFinished(target)
        return sealedName
    }

    /// Encodes a PCM recording as AAC in an `.m4a`, in the scratch folder.
    ///
    /// The recording is written as PCM so a crash cannot take it; see
    /// `AudioRecorder.start`. Stored, it should be a quarter of that size and in
    /// the format everything else already expects. The export session streams
    /// from disk to disk, so an hour of audio never sits in memory here.
    private static func encodeToAAC(_ source: URL) async throws -> URL {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let target = scratchDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try await session.export(to: target, as: .m4a)
        setProtection(.completeUnlessOpen, on: target)
        return target
    }

    /// The length of a plaintext recording, read from the file itself.
    ///
    /// Nil if the file cannot be opened. The recorder's own `currentTime` is zero
    /// once it has stopped, so this is what `AudioRecorder.stop` trusts.
    static func duration(fileName: String) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: directory.appendingPathComponent(fileName)) else {
            return nil
        }
        return Double(file.length) / file.fileFormat.sampleRate
    }

    /// Every recording file on disk, sealed or not, by file name.
    ///
    /// The list is the truth about what exists; the database is a view of it.
    /// `RecordingController.reconcile` compares the two.
    static func storedFileNames() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter { isSealed($0) || $0.hasSuffix(pendingSuffix) || $0.hasSuffix(".m4a") }
    }

    /// When a file was made, from the file system. Used for a recording whose row
    /// was lost; the recorder itself does not store the date anywhere else.
    static func creationDate(fileName: String) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(fileName).path)
        return attributes?[.creationDate] as? Date
    }

    /// The audio of a recording, unlocked.
    ///
    /// A sealed file goes through the vault. A file still waiting to be sealed is
    /// read as it is; that only happens while the device has not been unlocked
    /// since the recording was stopped.
    static func plaintext(fileName: String) throws -> Data {
        let stored = try Data(contentsOf: directory.appendingPathComponent(fileName))
        return isSealed(fileName) ? try RecordingVault.open(stored) : stored
    }

    /// Runs a job with the recording temporarily decrypted.
    ///
    /// The plaintext lives only as long as the job, in the temporary directory, and
    /// is deleted however the job ends.
    static func withDecrypted<T>(
        fileName: String,
        _ body: (URL) async throws -> T
    ) async throws -> T {
        let temporary = try await decryptToTemporary(fileName: fileName)
        defer { try? FileManager.default.removeItem(at: temporary) }

        return try await body(temporary)
    }

    /// Unlocks the audio file and puts the plaintext in a temporary file.
    ///
    /// `@concurrent` keeps the reading, decrypting and writing off the main thread.
    /// Without it they land there: `SWIFT_APPROACHABLE_CONCURRENCY` makes a
    /// `nonisolated async` function inherit the caller's actor, and
    /// `Transcription.run` calls from the main actor. All three steps take the whole
    /// file at once, and an hour of audio is about 30 MB.
    ///
    /// `body` stays with the caller. The engine is bound to the main actor and must
    /// still be called from there.
    @concurrent
    private static func decryptToTemporary(fileName: String) async throws -> URL {
        let audio = try plaintext(fileName: fileName)

        let temporary = scratchDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try audio.write(to: temporary, options: [.completeFileProtectionUnlessOpen])
        return temporary
    }

    /// Keeps the database out of the iCloud backup.
    ///
    /// The text in it is sealed, so what would otherwise travel is metadata: dates,
    /// lengths and file names. Little, but none of it belongs in a backup. Set at
    /// every launch, for the same reason as the recordings folder, and again after
    /// the first save: SQLite creates `-wal` and `-shm` on the first write, and a
    /// flag set on a file that does not exist yet sets nothing.
    static func excludeFromBackup(store container: ModelContainer) {
        for configuration in container.configurations {
            let url = configuration.url
            excludeFromBackup(url)
            for suffix in ["-wal", "-shm"] {
                excludeFromBackup(
                    url.deletingLastPathComponent().appending(path: url.lastPathComponent + suffix)
                )
            }
        }
    }

    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }

    private static func setProtection(_ level: FileProtectionType, on url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: level],
            ofItemAtPath: url.path
        )
    }

    /// Keeps the recordings out of the iCloud backup.
    ///
    /// Apple calls this guidance to the system, not a guarantee, and the flag can be
    /// reset by file operations. So we set it again every time a file is finished.
    /// For a guarantee, the content has to be encrypted with a key that does not
    /// exist outside this device.
    private static func excludeFromBackup(_ url: URL) {
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }
}
