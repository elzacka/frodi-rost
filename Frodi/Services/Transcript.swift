import Foundation

/// One paragraph of text and where in the audio it was said.
struct TranscriptParagraph: Codable, Equatable, Sendable {
    var start: TimeInterval
    var end: TimeInterval
    var text: String
}

/// The text as stored and shown: paragraphs, each opened by the time it starts at, «[12:37] …», so a reader can find the passage in the audio.
/// Text, not a structure, on purpose: the sealed transcript stays a string, and one made before the marks existed is one paragraph with no mark.
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

/// Transcription progress on disk, to resume: an hour-long recording outlasts the time before suspension, and a restart never finishes.
/// Written sealed through the vault after each piece, named by the recording's stem (its own name changes when sealed).
/// Existence means the user asked for it (long recordings wait); `begin` keeps that across launches.
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
