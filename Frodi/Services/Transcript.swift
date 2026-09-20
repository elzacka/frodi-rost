import Foundation

/// One paragraph of text and where in the audio it was said.
struct TranscriptParagraph: Codable, Equatable, Sendable {
    var start: TimeInterval
    var end: TimeInterval
    var text: String
}

/// The text as it is stored and shown: paragraphs, each opened by the time it
/// starts at, «[12:37] …». An hour of interview is not one block of text; the
/// marks are what let a reader find the passage in the audio behind a line.
///
/// The format is text, not a structure, on purpose. The sealed transcript stays a
/// string, so nothing about what is stored changed shape, and a transcript made
/// before the marks existed is one paragraph with no mark, which reads as it did.
enum Transcript {
    /// «[m:ss] text», paragraphs separated by a blank line. A single paragraph
    /// carries no mark; it can only start at the beginning.
    static func compose(_ paragraphs: [TranscriptParagraph]) -> String {
        let kept = paragraphs.filter { !$0.text.isEmpty }
        if kept.count == 1 { return kept[0].text }
        return kept
            .map { "[\(mark($0.start))] \($0.text)" }
            .joined(separator: "\n\n")
    }

    /// Splits stored text back into paragraphs. The mark is nil where there is none.
    static func paragraphs(in text: String) -> [(mark: TimeInterval?, text: String)] {
        text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { paragraph in
                guard let match = paragraph.firstMatch(of: markPattern) else {
                    return (nil, paragraph)
                }
                let hours = match.output.2.flatMap { Double($0) } ?? 0
                let minutes = Double(match.output.3) ?? 0
                let seconds = Double(match.output.4) ?? 0
                let body = String(paragraph[match.range.upperBound...])
                return (hours * 3600 + minutes * 60 + seconds, body)
            }
    }

    /// «4:07», «1:02:05». The seconds are rounded down; nobody scrubs to a tenth.
    static func mark(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.down))
        let hours = whole / 3600, minutes = (whole % 3600) / 60, rest = whole % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    /// `[h:mm:ss] ` or `[m:ss] ` at the start of a paragraph. A property, not a
    /// stored constant: `Regex` is not `Sendable`, and a literal is cheap to build.
    private static var markPattern: Regex<(Substring, Substring, Substring?, Substring, Substring)> {
        /^(\[(?:(\d+):)?(\d+):(\d{2})\] )/
    }
}

/// Where a transcription has got to, kept on disk so it can go on from there.
///
/// A recording of an hour takes long enough that the app will be suspended
/// before it is done, and a transcription that starts over each time never
/// finishes. So after every piece the paragraphs so far and the position reached
/// are written here, sealed through the vault like the text itself. The file
/// lives beside the recording, named by the recording's stem, since the
/// recording's own name changes when it is sealed.
///
/// The file also carries a decision: its existence means the transcription was
/// asked for. A long recording is not transcribed until the user says so, and
/// `begin` is how that is remembered across a launch.
struct TranscriptProgress: Codable, Sendable {
    var position: TimeInterval = 0
    var paragraphs: [TranscriptParagraph] = []

    static let suffix = ".tekst"

    /// The part of a recording's file name that does not change when it is sealed.
    static func stem(of fileName: String) -> String {
        var name = fileName
        if name.hasSuffix(AudioStorage.sealedSuffix) { name.removeLast(AudioStorage.sealedSuffix.count) }
        return (name as NSString).deletingPathExtension
    }

    private static func url(for fileName: String) -> URL {
        AudioStorage.directory.appendingPathComponent(stem(of: fileName) + suffix)
    }

    /// Whether a transcription has been asked for. A file check only; the rows in
    /// the list ask this on every draw, and opening the file would cost a
    /// decryption each time.
    static func exists(for fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName).path)
    }

    /// Nil when no transcription has been asked for.
    static func load(for fileName: String) -> TranscriptProgress? {
        guard let sealed = try? Data(contentsOf: url(for: fileName)),
              let json = try? RecordingVault.openText(sealed),
              let progress = try? JSONDecoder().decode(TranscriptProgress.self, from: Data(json.utf8))
        else { return nil }
        return progress
    }

    static func begin(for fileName: String) {
        TranscriptProgress().save(for: fileName)
    }

    func save(for fileName: String) {
        guard let json = try? JSONEncoder().encode(self),
              let sealed = try? RecordingVault.seal(String(decoding: json, as: UTF8.self))
        else { return }
        // `completeUnlessOpen`, not `complete`: a piece can finish after the user
        // has locked the screen, and this class lets a new file be written then.
        // It is read back on an unlocked device. Ciphertext either way.
        try? sealed.write(to: Self.url(for: fileName), options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    static func clear(for fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}
