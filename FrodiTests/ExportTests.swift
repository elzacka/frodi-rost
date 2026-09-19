import Foundation
import Testing
@testable import Frodi

/// The document the auditor sends on. It has to open as a document, with the
/// paragraphs and marks intact, in Bokmål whatever the device is set to.
@Suite("Eksportvalg")
struct ExportTests {
    private let transcript = """
    [0:00] Vi starter med å gå gjennom prosedyren.

    [12:37] Hvem har ansvar for oppfølgingen?
    """

    private var date: Date {
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 14
        components.hour = 10; components.minute = 30
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func sealedRecording(transcript: String?) throws -> Recording {
        let name = "\(UUID().uuidString).m4a.enc"
        try RecordingVault.seal(Data("lyd".utf8)).write(to: AudioStorage.directory.appendingPathComponent(name))
        let recording = Recording(duration: 1, fileName: name)
        if let transcript { try recording.setTranscript(transcript) }
        return recording
    }

    /// The share sheet gets what was asked for and nothing else: the audio alone,
    /// the text alone in the chosen format, or both.
    @Test("Eksporten gir det som ble valgt", arguments: [
        (RecordingExport.Content.both, RecordingExport.TextFormat.rtf, ["m4a", "rtf"]),
        (.both, .txt, ["m4a", "txt"]),
        (.audio, .rtf, ["m4a"]),
        (.text, .rtf, ["rtf"]),
        (.text, .txt, ["txt"])
    ])
    func exportCarriesTheChoice(content: RecordingExport.Content, format: RecordingExport.TextFormat, extensions: [String]) async throws {
        let recording = try sealedRecording(transcript: transcript)
        defer { AudioStorage.delete(fileName: recording.fileName) }

        let urls = try await RecordingExport.prepare(recording, content: content, format: format)
        defer { RecordingExport.cleanUp(urls) }

        #expect(urls.map(\.pathExtension) == extensions)
    }

    /// A recording without text has only the audio to give, whatever was asked.
    @Test("Uten tekst kommer bare lyden")
    func exportWithoutTranscriptIsAudioOnly() async throws {
        let recording = try sealedRecording(transcript: nil)
        defer { AudioStorage.delete(fileName: recording.fileName) }

        let urls = try await RecordingExport.prepare(recording, content: .both, format: .txt)
        defer { RecordingExport.cleanUp(urls) }

        #expect(urls.map(\.pathExtension) == ["m4a"])
    }

    /// The format chosen in Innstillinger is what the export reads, and `.rtf`
    /// is what it reads before anything is chosen.
    @Test("Formatet velges i Innstillinger")
    func chosenFormatIsReadFromDefaults() {
        let key = RecordingExport.TextFormat.key
        let before = UserDefaults.standard.string(forKey: key)
        defer { UserDefaults.standard.set(before, forKey: key) }

        UserDefaults.standard.removeObject(forKey: key)
        #expect(RecordingExport.TextFormat.chosen == .rtf)

        UserDefaults.standard.set("txt", forKey: key)
        #expect(RecordingExport.TextFormat.chosen == .txt)

        UserDefaults.standard.set("docx", forKey: key)
        #expect(RecordingExport.TextFormat.chosen == .rtf)
    }

    @Test("RTF-en åpner som tekst med overskrift, avsnitt og tidspunkt")
    func rtfCarriesTheStructure() throws {
        let data = try RecordingExport.rtf(transcript, createdAt: date, duration: 3492)
        let opened = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        let text = opened.string

        #expect(text.hasPrefix("Opptak 14. september 2026"))
        #expect(text.contains("Lengde 58 min, 12 sek"))
        #expect(text.contains("[12:37] Hvem har ansvar for oppfølgingen?"))
        #expect(text.contains("prosedyren.\n"))
    }

    @Test("Norske tegn overlever RTF")
    func norwegianLettersSurvive() throws {
        let data = try RecordingExport.rtf("Blåbær og søt frø", createdAt: date, duration: 5)
        let opened = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        #expect(opened.string.contains("Blåbær og søt frø"))
    }
}
