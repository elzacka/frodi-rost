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
    /// What goes to the share sheet. Chosen where the export is made: a note
    /// pasted into a message wants the text alone, an interview sent to a
    /// colleague for a second listen wants the audio alone.
    enum Content {
        case both, audio, text
    }

    /// The document the text becomes. Chosen once, in Innstillinger, and kept
    /// in `UserDefaults`: a format name is not personal data, so it needs none
    /// of the vault the word list gets.
    enum TextFormat: String, CaseIterable {
        case txt, rtf

        static let key = "exportTextFormat"

        /// `.rtf` until chosen otherwise: it is the one that opens as a document,
        /// with the heading, the date and the marks intact.
        static var chosen: TextFormat {
            UserDefaults.standard.string(forKey: key).flatMap(TextFormat.init) ?? .rtf
        }

        /// «.txt», the way a user knows the format.
        var label: String { ".\(rawValue)" }
    }

    /// Writes audio and text to temporary files ready for sharing.
    ///
    /// The recording is a SwiftData object and cannot be passed to another thread.
    /// So we pull the values out here and pass only those.
    static func prepare(
        _ recording: Recording,
        content: Content = .both,
        format: TextFormat = .chosen
    ) async throws -> [URL] {
        try await write(
            fileName: recording.fileName,
            createdAt: recording.createdAt,
            duration: recording.duration,
            title: recording.title(),
            origin: recording.origin(),
            transcript: content == .audio ? nil : try recording.transcript(),
            audio: content != .text,
            format: format
        )
    }

    /// Reading, decrypting and writing a whole audio file takes time that grows
    /// with the length of the recording. An hour of audio is about 30 MB, and all
    /// three steps take the whole file at once.
    ///
    /// `@concurrent` keeps it off the main thread. Without it, it lands there:
    /// `SWIFT_APPROACHABLE_CONCURRENCY` makes a `nonisolated async` function inherit
    /// the caller's actor, and here the view calls. Measured 2026-09-09: the
    /// interface froze until the share sheet came up.
    @concurrent
    private static func write(
        fileName: String,
        createdAt: Date,
        duration: TimeInterval,
        title: String?,
        origin: OriginState,
        transcript: String?,
        audio: Bool,
        format: TextFormat
    ) async throws -> [URL] {
        var urls: [URL] = []

        let stamp = Self.stamp(createdAt)
        let folder = AudioStorage.scratchDirectory
            .appendingPathComponent("Eksport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // A recording stopped on a locked device is still PCM until the next unlock;
        // the export then carries the format it actually has.
        let container = fileName.hasSuffix(AudioStorage.pendingSuffix) ? "caf" : "m4a"
        let audioName = "frodi-\(stamp).\(container)"
        let wantsDocument = transcript?.isEmpty == false && format == .rtf
        // The document names the audio by its checksum, so it is read for a text
        // alone too. The bytes are the same at every export: the vault opens the
        // sealed file to the same plaintext each time.
        let audioData = audio || wantsDocument ? try AudioStorage.plaintext(fileName: fileName) : nil

        if audio, let audioData {
            let file = folder.appendingPathComponent(audioName)
            try audioData.write(to: file, options: [.completeFileProtectionUnlessOpen])
            urls.append(file)
        }

        if let transcript, !transcript.isEmpty {
            let file = folder.appendingPathComponent("frodi-\(stamp).\(format.rawValue)")
            let data = switch format {
            case .txt: utf8WithBOM(transcript)
            case .rtf: try rtf(
                transcript,
                createdAt: createdAt,
                duration: duration,
                title: title,
                origin: origin,
                audio: audioData.map { (name: audioName, sha256: RecordingOrigin.checksum($0)) }
            )
            }
            try data.write(to: file, options: [.completeFileProtectionUnlessOpen])
            urls.append(file)
        }

        return urls
    }

    /// The text as a document: a heading, the date and the length, where the
    /// recording came from, then the paragraphs with their marks.
    ///
    /// The checksum of the audio file ties the document to it. A reader holding
    /// the two can check with `shasum -a 256` that the audio is the one the text
    /// was made from, and an imported recording names its original the same way.
    ///
    /// RTF rather than `.docx` because Apple writes it natively and Word, Pages
    /// and Notes all open it with the structure intact. A `.txt` loses the
    /// heading and the paragraphs the moment it is pasted into a report; this
    /// does not. The fonts are the system's own, not the app's: the document is
    /// read on another machine, and asking for Inter there gives a fallback anyway.
    static func rtf(
        _ transcript: String,
        createdAt: Date,
        duration: TimeInterval,
        title: String? = nil,
        origin: OriginState = .none,
        audio: (name: String, sha256: String)? = nil
    ) throws -> Data {
        let body = UIFont.systemFont(ofSize: 12)
        let heading = UIFont.boldSystemFont(ofSize: 16)
        let meta = UIFont.systemFont(ofSize: 10)
        let secondary = UIColor(white: 0.4, alpha: 1)

        let spaced = NSMutableParagraphStyle()
        spaced.paragraphSpacing = 8

        let document = NSMutableAttributedString()
        let dated = "Opptak \(createdAt.recordingStamp)"
        document.append(NSAttributedString(
            string: "\(title ?? dated)\n",
            attributes: [.font: heading, .paragraphStyle: spaced]
        ))
        var about = [
            title == nil ? nil : "\(dated).",
            "Lengde \(Duration.seconds(duration).formatted(exportLength)). Laget med Fróði røst."
        ].compactMap(\.self)
        if let original = origin.verified?.original, let importedAt = origin.verified?.importedAt {
            about.append("Importert \(importedAt.recordingStamp) fra \(original.name). Sjekksum for originalen (SHA-256): \(original.sha256)")
        }
        if let audio {
            about.append("Sjekksum for \(audio.name) (SHA-256): \(audio.sha256)")
        }
        // Said in the document, not left out: a reader cannot tell a missing
        // line from one that was held back.
        let audioDiffers = origin.verified.flatMap { origin in audio.map { $0.sha256 != origin.audioSHA256 } } ?? false
        if origin.isDoubtful || audioDiffers {
            about.append("Fróði kan ikke bekrefte opplysningene om dette opptaket. De kan være endret utenfor appen.")
        }
        document.append(NSAttributedString(
            string: about.joined(separator: "\n") + "\n\n",
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
