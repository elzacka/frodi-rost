import Foundation

/// One word and when it was said, as the model wrote it (with its leading space).
struct TimedWord: Codable, Equatable, Sendable {
    var start: TimeInterval
    var end: TimeInterval
    var text: String
}

/// One paragraph of text and where in the audio it was said.
struct TranscriptParagraph: Codable, Equatable, Sendable {
    var start: TimeInterval
    var end: TimeInterval
    var text: String
    /// Avansert: the words with their times, kept until the speakers are known.
    var words: [TimedWord]?
    /// Avansert: 1, 2, … in the order the voices are first heard.
    var speaker: Int?
}

/// The text as stored and shown: paragraphs, each opened by the time it starts at, «[12:37] …», so a reader can find the passage in the audio.
/// Text, not a structure, on purpose: the sealed transcript stays a string, and one made before the marks existed is one paragraph with no mark.
enum Transcript {
    /// «[m:ss] text», or «[m:ss] Person 1: text» in Avansert, paragraphs separated by a blank line.
    /// A single paragraph carries no mark; it can only start at the beginning.
    static func compose(_ paragraphs: [TranscriptParagraph]) -> String {
        let kept = paragraphs.filter { !$0.text.isEmpty }
        if kept.count == 1 { return kept[0].text }
        return kept
            .map { "[\(mark($0.start))] \(label($0.speaker))\($0.text)" }
            .joined(separator: "\n\n")
    }

    private static func label(_ speaker: Int?) -> String {
        speaker.map { String(localized: "Person \($0)") + ": " } ?? ""
    }

    /// A paragraph as read back: its mark, its speaker in Avansert, its text.
    struct Paragraph: Equatable {
        var mark: TimeInterval?
        var speaker: String?
        var text: String
    }

    /// Splits stored text back into paragraphs. The mark is nil where there is none.
    /// A speaker is read only when every marked paragraph opens with one and there are at least two, as `compose`
    /// writes them; an Enkel paragraph that happens to open «Merk: …» stays text.
    static func paragraphs(in text: String) -> [Paragraph] {
        let marked: [Paragraph] = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { paragraph in
                guard let match = paragraph.firstMatch(of: markPattern) else {
                    return Paragraph(mark: nil, text: paragraph)
                }
                let hours = match.output.2.flatMap { Double($0) } ?? 0
                let minutes = Double(match.output.3) ?? 0
                let seconds = Double(match.output.4) ?? 0
                let body = String(paragraph[match.range.upperBound...])
                return Paragraph(mark: hours * 3600 + minutes * 60 + seconds, text: body)
            }

        let labelled = marked.filter { $0.mark != nil }.map { $0.text.firstMatch(of: speakerPattern) }
        let names = Set(labelled.compactMap { $0.map { String($0.output.1) } })
        guard !labelled.isEmpty, labelled.allSatisfy({ $0 != nil }), names.count > 1 else { return marked }
        return marked.map { paragraph in
            guard paragraph.mark != nil, let match = paragraph.text.firstMatch(of: speakerPattern) else { return paragraph }
            return Paragraph(mark: paragraph.mark, speaker: String(match.output.1), text: String(paragraph.text[match.range.upperBound...]))
        }
    }

    /// The speakers in the order they first speak.
    static func speakers(in text: String) -> [String] {
        var seen: [String] = []
        for case let name? in paragraphs(in: text).map(\.speaker) where !seen.contains(name) { seen.append(name) }
        return seen
    }

    /// Whether the user has changed the names: anything but «Person 1», «Person 2», … in the order the diarization
    /// writes them, so a merge that breaks the numbering counts too.
    static func hasGivenNames(in text: String) -> Bool {
        let names = speakers(in: text)
        return names != names.indices.map { String(localized: "Person \($0 + 1)") }
    }

    /// The longest name a speaker can be given, and the characters it cannot hold: they would end the label.
    static let longestName = 40

    /// The text with one speaker renamed everywhere. Two speakers given the same name become one, which mends a voice
    /// the diarization split in two; with one name left the labels go, as for one voice. An empty name changes nothing.
    static func renaming(_ speaker: String, to name: String, in text: String) -> String {
        let clean = String(name
            .replacingOccurrences(of: ":", with: "")
            .components(separatedBy: .newlines).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
            .prefix(longestName))
        guard !clean.isEmpty, clean != speaker else { return text }
        let read = paragraphs(in: text)
        let names = Set(read.compactMap(\.speaker).map { $0 == speaker ? clean : $0 })
        return read
            .map { paragraph in
                let mark = paragraph.mark.map { "[\(Self.mark($0))] " } ?? ""
                let label = names.count > 1 ? paragraph.speaker.map { "\($0 == speaker ? clean : $0): " } ?? "" : ""
                return mark + label + paragraph.text
            }
            .joined(separator: "\n\n")
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

    /// «Person 1: » or a name given since, at the start of a paragraph's text.
    private static var speakerPattern: Regex<(Substring, Substring)> {
        #/^([^:\n]{1,40}): /#
    }
}

/// Transcription progress on disk, to resume: an hour-long recording outlasts the time before suspension, and a restart never finishes.
/// Written sealed through the vault after each piece, named by the recording's stem (its own name changes when sealed).
/// Existence means the user asked for it (long recordings wait); `begin` keeps that across launches.
struct TranscriptProgress: Codable, Sendable {
    var position: TimeInterval = 0
    var paragraphs: [TranscriptParagraph] = []
    /// Avansert, fixed when the text is begun, so a run resumed after the setting changed finishes as it started.
    /// Nil in progress saved before the setting existed, which reads as Enkel.
    var speakers: Bool? = TextMode.current == .avansert
    /// Speaker passes begun. After two that did not finish, the text is kept without labels.
    var speakerAttempts: Int?

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
