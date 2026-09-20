import Foundation

/// Names and terms the model should know: companies, people, abbreviations.
///
/// Whisper takes a short text before it starts listening and leans towards
/// spelling what it hears the way that text does. It adds nothing to the
/// transcript; it settles how an ambiguous sound is written. A surname it has
/// never seen comes out as two words or an invented one; the same surname in
/// the list comes out right. In an interview those are the words that matter.
///
/// This is the app's one setting. It is stored sealed through the vault, like
/// the text: the names of a user's clients are as exposing as anything said
/// about them. `UserDefaults` would have put them in the iCloud backup in the
/// clear.
enum WordList {
    /// The `UserDefaults` key for the height of the field in Innstillinger. A
    /// height is not personal data, so it does not go through the vault.
    static let heightKey = "wordListFieldHeight"

    static var url: URL {
        URL.documentsDirectory.appendingPathComponent("Ordliste.enc")
    }

    static func load() -> String {
        guard let sealed = try? Data(contentsOf: url),
              let text = try? RecordingVault.openText(sealed) else { return "" }
        return text
    }

    static func save(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        guard let sealed = try? RecordingVault.seal(trimmed) else { return }
        // Read only on an unlocked device: on the settings page and when a
        // transcription starts. The content is ciphertext either way.
        try? sealed.write(to: url, options: [.atomic, .completeFileProtection])
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }

    /// The entries, one per name or term, as the user wrote them.
    static func entries(in text: String) -> [String] {
        text
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Spells the listed names the way the list does, where the model nearly did.
    ///
    /// The prompt is a bias, not a rule: measured on 2026-09-14, it fixed
    /// «Osserud» to «Aaserud» and left «Norgkvist» for «Nordkvist» and «TASK» for
    /// «Tazk» every time. Those are one or two letters off, and the user has said
    /// what the word is. So the finished text is compared against the list, whole
    /// words only, and a word within a small edit distance of an entry becomes
    /// the entry. A multi-word entry is matched as a unit, so «Maskin» on its own
    /// never touches «maskinen».
    ///
    /// Conservative on purpose: nothing shorter than four letters, no more than
    /// one letter in six, never a word that is only a case away, never a word
    /// that already equals another entry. A false replacement is worse than a
    /// missed one, because the user cannot see it happened.
    static func correct(_ text: String, entries: [String]) -> String {
        let entries = entries.filter { $0.count >= 4 }
        guard !entries.isEmpty else { return text }

        let exact = Set(entries.map { $0.lowercased() })
        let words = text.matches(of: /[\p{L}\p{N}]+/)
        var result = text
        var replacements: [(Range<String.Index>, String)] = []
        var index = 0

        while index < words.count {
            var matched = false
            for entry in entries {
                let count = entry.split(separator: " ").count
                guard index + count <= words.count else { continue }
                let window = words[index..<index + count]
                let candidate = String(text[window.first!.range.lowerBound..<window.last!.range.upperBound])
                // Words in the window separated by more than one space or a punctuation
                // mark are not one name.
                guard candidate.split(separator: " ").count == count,
                      !candidate.contains(where: \.isNumber),
                      !exact.contains(candidate.lowercased()),
                      candidate.lowercased() != entry.lowercased(),
                      distance(candidate.lowercased(), entry.lowercased()) <= allowed(for: entry)
                else { continue }
                replacements.append((window.first!.range.lowerBound..<window.last!.range.upperBound, entry))
                index += count
                matched = true
                break
            }
            if !matched { index += 1 }
        }

        for (range, entry) in replacements.reversed() {
            result.replaceSubrange(range, with: entry)
        }
        return result
    }

    /// One letter in six, rounded up, at most three: four to six letters allow
    /// one, seven to twelve two. «Osserud» reaches «Aaserud»; «Bergen» does not
    /// reach «Berg».
    private static func allowed(for entry: String) -> Int {
        min((entry.count + 5) / 6, 3)
    }

    /// Levenshtein distance, for words: both sides are short.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var current = [i + 1]
            for (j, cb) in b.enumerated() {
                current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (ca == cb ? 0 : 1)))
            }
            previous = current
        }
        return previous[b.count]
    }

    /// The list as the model gets it: one line, the entries separated by commas,
    /// whether the user wrote them with commas or on separate lines. Nil when
    /// there is nothing, so the decoder runs without a prompt at all.
    static func prompt(from text: String) -> String? {
        let entries = entries(in: text)
        return entries.isEmpty ? nil : entries.joined(separator: ", ")
    }
}
