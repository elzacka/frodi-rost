import AVFoundation
import Foundation
import SwiftData

/// Where the audio files live, and how they are protected.
/// The recording must be writable while the screen is locked; the finished file must not be readable while it is
/// locked.
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

    /// Plaintext that exists only while a job runs (transcription, export), in one folder so `clearScratch()` empties
    /// it at launch: a `defer` does not run if the process is killed mid-transcription.
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

    /// Protection while the recording runs. `completeUnlessOpen` keeps an open file writable after the screen locks;
    /// with `complete` the recording would stop when the device locks (in the car).
    static func protectWhileRecording(_ url: URL) {
        setProtection(.completeUnlessOpen, on: url)
    }

    /// Protection once sealed. The file is closed, so `complete` applies: unreadable on a locked device, even with
    /// physical access. The key has the matching class, see `RecordingVault.createKey`.
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

    /// The file a recording continues in after an interruption: `X.1.caf` follows `X.caf`. See
    /// `AudioRecorder.interruptionEnded`. The segments are one recording under the first file's name (row, `duration`,
    /// `delete`, `seal`, which joins them); never listed alone, so a kill between two still gives one row.
    static func continuationName(for fileName: String, index: Int) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        return "\(stem).\(index)" + pendingSuffix
    }

    static func isContinuation(_ fileName: String) -> Bool {
        guard fileName.hasSuffix(pendingSuffix) else { return false }
        let index = ((fileName as NSString).deletingPathExtension as NSString).pathExtension
        return !index.isEmpty && index.allSatisfy(\.isNumber)
    }

    /// The recording's files in order: the file itself, then its continuations.
    /// A sealed recording is one file.
    static func segmentNames(of fileName: String) -> [String] {
        guard fileName.hasSuffix(pendingSuffix) else { return [fileName] }
        let prefix = (fileName as NSString).deletingPathExtension + "."
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let continuations = names
            .filter { isContinuation($0) && $0.hasPrefix(prefix) }
            .sorted { index(of: $0) < index(of: $1) }
        return [fileName] + continuations
    }

    private static func index(of continuation: String) -> Int {
        Int(((continuation as NSString).deletingPathExtension as NSString).pathExtension) ?? 0
    }

    /// Seals a plaintext recording. The checksum is taken from the bytes going in: reading back needs the private key,
    /// refused on a locked device. Plaintext goes only after the atomic sealed copy exists (an existing copy counts as
    /// done); failure, expected when the Action Button stops it locked, retries at unlock.
    @concurrent
    static func seal(fileName: String) async throws -> (name: String, audioSHA256: String?) {
        let source = directory.appendingPathComponent(fileName)
        let sealedName = sealedName(for: fileName)
        let target = directory.appendingPathComponent(sealedName)

        let audioSHA256: String?
        if !FileManager.default.fileExists(atPath: target.path) {
            let audio = fileName.hasSuffix(pendingSuffix)
                ? try await encodeToAAC(segmentNames(of: fileName).map { directory.appendingPathComponent($0) })
                : source
            defer { if audio != source { try? FileManager.default.removeItem(at: audio) } }
            let plaintext = try Data(contentsOf: audio)
            try RecordingVault.seal(plaintext).write(to: target, options: [.atomic, .completeFileProtection])
            audioSHA256 = RecordingOrigin.checksum(plaintext)
        } else {
            audioSHA256 = try? RecordingOrigin.checksum(plaintext(fileName: sealedName))
        }
        for name in segmentNames(of: fileName) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
        protectFinished(target)
        return (sealedName, audioSHA256)
    }

    /// Encodes a PCM recording as AAC in an `.m4a` in the scratch folder, streamed disk to disk. Segments are composed
    /// in order; one without an audio track (an empty CAF) is skipped, and if all are empty the export fails and the
    /// caller keeps the plaintext.
    private static func encodeToAAC(_ segments: [URL]) async throws -> URL {
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CocoaError(.fileWriteUnknown)
        }
        for segment in segments {
            let asset = AVURLAsset(url: segment)
            guard let source = try await asset.loadTracks(withMediaType: .audio).first else { continue }
            try track.insertTimeRange(try await source.load(.timeRange), of: source, at: composition.duration)
        }
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let target = scratchDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try await session.export(to: target, as: .m4a)
        setProtection(.completeUnlessOpen, on: target)
        return target
    }

    /// Seals an imported file in the scratch folder; returns the sealed copy and the audio checksum. An import reaches
    /// the recordings folder sealed or not at all: a plain file there would be taken by `reconcile` and the seal for a
    /// recording made here. The caller moves the copy in and writes its row in one step.
    @concurrent
    static func sealImport(_ pcm: URL) async throws -> (url: URL, audioSHA256: String) {
        let target = scratchDirectory.appendingPathComponent(sealedName(for: pcm.lastPathComponent))
        let audio = try await encodeToAAC([pcm])
        defer { try? FileManager.default.removeItem(at: audio) }
        let plaintext = try Data(contentsOf: audio)
        try RecordingVault.seal(plaintext).write(to: target, options: [.atomic, .completeFileProtection])
        return (target, RecordingOrigin.checksum(plaintext))
    }

    /// The checksum of a recording's audio as an export hands it over: the
    /// sealed file opened. `@concurrent` for the same reason as the seal.
    @concurrent
    static func audioChecksum(fileName: String) async throws -> String {
        RecordingOrigin.checksum(try plaintext(fileName: fileName))
    }

    /// The length of a plaintext recording, summed over its segments from the files; nil if any cannot be opened. The
    /// recorder's `currentTime` is zero once stopped, so `AudioRecorder.stop` trusts this.
    static func duration(fileName: String) -> TimeInterval? {
        var total: TimeInterval = 0
        for name in segmentNames(of: fileName) {
            guard let file = try? AVAudioFile(forReading: directory.appendingPathComponent(name)) else {
                return nil
            }
            total += Double(file.length) / file.fileFormat.sampleRate
        }
        return total
    }

    /// Every recording on disk, sealed or not, by file name; continuations are not listed. The disk is the truth about
    /// what exists; the database is a view of it (`RecordingController.reconcile`).
    static func storedFileNames() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter { (isSealed($0) || $0.hasSuffix(pendingSuffix) || $0.hasSuffix(".m4a")) && !isContinuation($0) }
    }

    /// When a file was made, from the file system. Used for a recording whose row
    /// was lost; the recorder itself does not store the date anywhere else.
    static func creationDate(fileName: String) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(fileName).path)
        return attributes?[.creationDate] as? Date
    }

    /// The audio of a recording, unlocked. A sealed file goes through the vault; an unsealed one is read as is (only
    /// before the first unlock after stopping), and for an interrupted one that is the part before the first call.
    static func plaintext(fileName: String) throws -> Data {
        let stored = try Data(contentsOf: directory.appendingPathComponent(fileName))
        return isSealed(fileName) ? try RecordingVault.open(stored) : stored
    }

    /// Runs a job with the recording temporarily decrypted; the plaintext lives in the temporary directory and is
    /// deleted however the job ends.
    static func withDecrypted<T>(
        fileName: String,
        _ body: (URL) async throws -> T
    ) async throws -> T {
        let temporary = try await decryptToTemporary(fileName: fileName)
        defer { try? FileManager.default.removeItem(at: temporary) }

        return try await body(temporary)
    }

    /// Unlocks the audio into a temp file. `@concurrent`: `SWIFT_APPROACHABLE_CONCURRENCY` would run it on the main
    /// actor (`Transcription.run` calls from there) with an hour of audio read whole. `.completeUnlessOpen`: the
    /// held-open file stays readable after the screen locks. `body` stays with the caller (main-actor engine).
    @concurrent
    private static func decryptToTemporary(fileName: String) async throws -> URL {
        let audio = try plaintext(fileName: fileName)

        let temporary = scratchDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try audio.write(to: temporary, options: [.completeFileProtectionUnlessOpen])
        return temporary
    }

    /// Keeps the database out of the iCloud backup: its text is sealed, but dates, lengths and file names would travel.
    /// Set at every launch and again after the first save, since SQLite creates `-wal` and `-shm` on the first write
    /// and a flag on a missing file sets nothing.
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
        for name in segmentNames(of: fileName) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
        TranscriptProgress.clear(for: fileName)
    }

    private static func setProtection(_ level: FileProtectionType, on url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: level],
            ofItemAtPath: url.path
        )
    }

    /// Keeps the recordings out of the iCloud backup. Apple treats this as guidance, not a guarantee, and file
    /// operations can reset it, so it is set again whenever a file is finished. A guarantee needs content encrypted
    /// with a key that never leaves the device.
    private static func excludeFromBackup(_ url: URL) {
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }
}
