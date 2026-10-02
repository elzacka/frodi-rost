import Foundation

/// Names and terms the model should know. Whisper takes a short text before listening and spells ambiguous sounds like
/// it; it adds nothing to the transcript. The app's one setting, sealed through the vault like the text: client names
/// are as exposing as anything said, and `UserDefaults` would put them in the iCloud backup in the clear.
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

    /// Corrects near-misses of listed names (the prompt is a bias). Whole words, small edit distance, multi-word
    /// entries whole. Skips words under four letters, over one letter in six off, case-only differences, other entries,
    /// and words beginning with an entry (Norwegian endings: «Tazks»). A wrong swap is invisible: worse than a miss.
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
                      !candidate.lowercased().hasPrefix(entry.lowercased()),
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
