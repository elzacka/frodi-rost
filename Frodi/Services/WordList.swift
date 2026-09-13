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
        // Readable after the first unlock, so a transcription on the charger can
        // use it. The content is ciphertext either way.
        try? sealed.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }

    /// The list as the model gets it: one line, the entries separated by commas,
    /// whether the user wrote them with commas or on separate lines. Nil when
    /// there is nothing, so the decoder runs without a prompt at all.
    static func prompt(from text: String) -> String? {
        let entries = text
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return entries.isEmpty ? nil : entries.joined(separator: ", ")
    }
}
