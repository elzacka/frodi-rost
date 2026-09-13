import Foundation
import UIKit

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
            duration: recording.duration,
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
        duration: TimeInterval,
        transcript: String?
    ) async throws -> [URL] {
        var urls: [URL] = []

        let stamp = Self.stamp(createdAt)
        let folder = AudioStorage.scratchDirectory
            .appendingPathComponent("Eksport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // A recording stopped on a locked device is still PCM until the next unlock;
        // the export then carries the format it actually has.
        let format = fileName.hasSuffix(AudioStorage.pendingSuffix) ? "caf" : "m4a"
        let audio = folder.appendingPathComponent("frodi-\(stamp).\(format)")
        try AudioStorage.plaintext(fileName: fileName).write(to: audio, options: [.completeFileProtectionUnlessOpen])
        urls.append(audio)

        if let transcript, !transcript.isEmpty {
            let text = folder.appendingPathComponent("frodi-\(stamp).txt")
            try utf8WithBOM(transcript).write(to: text, options: [.completeFileProtectionUnlessOpen])
            urls.append(text)

            let document = folder.appendingPathComponent("frodi-\(stamp).rtf")
            try rtf(transcript, createdAt: createdAt, duration: duration).write(to: document, options: [.completeFileProtectionUnlessOpen])
            urls.append(document)
        }

        return urls
    }

    /// The text as a document: a heading, the date and the length, then the
    /// paragraphs with their marks.
    ///
    /// RTF rather than `.docx` because Apple writes it natively and Word, Pages
    /// and Notes all open it with the structure intact. A `.txt` loses the
    /// heading and the paragraphs the moment it is pasted into a report; this
    /// does not. The fonts are the system's own, not the app's: the document is
    /// read on another machine, and asking for Inter there gives a fallback anyway.
    static func rtf(_ transcript: String, createdAt: Date, duration: TimeInterval) throws -> Data {
        let body = UIFont.systemFont(ofSize: 12)
        let heading = UIFont.boldSystemFont(ofSize: 16)
        let meta = UIFont.systemFont(ofSize: 10)
        let secondary = UIColor(white: 0.4, alpha: 1)

        let spaced = NSMutableParagraphStyle()
        spaced.paragraphSpacing = 8

        let document = NSMutableAttributedString()
        document.append(NSAttributedString(
            string: "Opptak \(createdAt.formatted(exportDate))\n",
            attributes: [.font: heading, .paragraphStyle: spaced]
        ))
        document.append(NSAttributedString(
            string: "Lengde \(Duration.seconds(duration).formatted(exportLength)). Tatt opp med Fróði røst.\n\n",
            attributes: [.font: meta, .foregroundColor: secondary, .paragraphStyle: spaced]
        ))

        for paragraph in Transcript.paragraphs(in: transcript) {
            if let mark = paragraph.mark {
                document.append(NSAttributedString(
                    string: "[\(Transcript.mark(mark))] ",
                    attributes: [.font: meta, .foregroundColor: secondary]
                ))
            }
            document.append(NSAttributedString(
                string: paragraph.text + "\n",
                attributes: [.font: body, .paragraphStyle: spaced]
            ))
        }

        return try document.data(
            from: NSRange(location: 0, length: document.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    /// «14. september 2026 kl. 10:30», in Bokmål whatever the device says.
    private static var exportDate: Date.FormatStyle {
        Date.FormatStyle(date: .long, time: .shortened, locale: AppLocale.norwegian)
    }

    /// «58 min, 12 sek».
    private static var exportLength: Duration.UnitsFormatStyle {
        .units(allowed: [.hours, .minutes, .seconds], width: .abbreviated).locale(AppLocale.norwegian)
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
