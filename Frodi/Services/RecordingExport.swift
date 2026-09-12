import Foundation

/// Exports a recording for further use.
///
/// Export is a deliberate action, not an open door. The files are encrypted at
/// rest and unlocked only at the moment you ask. The plaintext goes into the
/// temporary directory and is cleaned up after sharing.
///
/// Sharing goes through iOS' own share sheet. Where the files go is your choice
/// there: Files on the device and AirDrop keep them local, Mail, Messages and
/// iCloud Drive do not. Fróði uploads nothing itself, and has no network code
/// to do it with.
enum RecordingExport {
    /// Writes audio and text to temporary files ready for sharing.
    ///
    /// The recording is a SwiftData object and cannot be passed to another thread.
    /// So we pull the values out here and pass only those.
    static func prepare(_ recording: Recording) async throws -> [URL] {
        try await write(
            fileName: recording.fileName,
            createdAt: recording.createdAt,
            transcript: try recording.transcript()
        )
    }

    /// Reading, decrypting and writing a whole audio file takes time that grows
    /// with the length of the recording. An hour of audio is about 30 MB, and all
    /// three steps take the whole file at once.
    ///
    /// `@concurrent` keeps it off the main thread. Without it, it lands there:
    /// `SWIFT_APPROACHABLE_CONCURRENCY` makes a `nonisolated async` function inherit
    /// the caller's actor, and here the view calls. Measured 9 September 2026: the
    /// interface froze until the share sheet came up.
    @concurrent
    private static func write(
        fileName: String,
        createdAt: Date,
        transcript: String?
    ) async throws -> [URL] {
        var urls: [URL] = []

        let stamp = Self.stamp(createdAt)
        let folder = AudioStorage.scratchDirectory
            .appendingPathComponent("Eksport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let audio = folder.appendingPathComponent("frodi-\(stamp).m4a")
        try AudioStorage.plaintext(fileName: fileName).write(to: audio, options: [.completeFileProtectionUnlessOpen])
        urls.append(audio)

        if let transcript, !transcript.isEmpty {
            let text = folder.appendingPathComponent("frodi-\(stamp).txt")
            try utf8WithBOM(transcript).write(to: text, options: [.completeFileProtectionUnlessOpen])
            urls.append(text)
        }

        return urls
    }

    /// Writes the text as UTF-8 with a byte order mark.
    ///
    /// Without the BOM many readers guess that a `.txt` is Latin-1, and «så» becomes
    /// «sÃ¥». The file is UTF-8 either way; the three bytes tell the reader so.
    static func utf8WithBOM(_ text: String) -> Data {
        Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
    }

    /// Cleans up the plaintext once sharing is done.
    static func cleanUp(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        formatter.locale = Locale(identifier: "nb_NO")
        return formatter.string(from: date)
    }
}
