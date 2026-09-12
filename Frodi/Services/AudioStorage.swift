import Foundation
import SwiftData

/// Where the audio files live, and how they are protected.
///
/// Two things are governed from here, and they pull in opposite directions:
/// the recording must be writable while the screen is locked, and the finished
/// file must not be readable while the screen is locked.
enum AudioStorage {
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
        let sealed = try Data(contentsOf: directory.appendingPathComponent(fileName))
        let plaintext = try RecordingVault.open(sealed)

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        try plaintext.write(to: temporary, options: [.completeFileProtectionUnlessOpen])
        return temporary
    }

    /// Keeps the database out of the iCloud backup.
    ///
    /// The text in it is sealed, so what would otherwise travel is metadata: dates,
    /// lengths and file names. Little, but none of it belongs in a backup. Set at
    /// every launch, for the same reason as the recordings folder. SQLite writes to
    /// three files, and all three must be covered.
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
