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

    private func sealedRecording(transcript: String?, createdAt: Date = Date()) throws -> Recording {
        let name = "\(UUID().uuidString).m4a.enc"
        try RecordingVault.seal(Data("lyd".utf8)).write(to: AudioStorage.directory.appendingPathComponent(name))
        let recording = Recording(createdAt: createdAt, duration: 1, fileName: name)
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

        #expect(text.hasPrefix("Opptak 14.09.26"))
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

    /// Everything in one zip, two recordings from the same minute under two
    /// names, and a recording whose file is gone named rather than blocking the rest.
    @Test("Alle opptak i én zip-fil")
    func exportAllZipsEveryRecording() async throws {
        let first = try sealedRecording(transcript: transcript, createdAt: date)
        let second = try sealedRecording(transcript: nil, createdAt: date)
        let missing = Recording(createdAt: date, duration: 1, fileName: "\(UUID().uuidString).m4a.enc")
        defer { [first, second].forEach { AudioStorage.delete(fileName: $0.fileName) } }

        let result = try await RecordingExport.prepareAll([first, second, missing], format: .rtf)
        defer { RecordingExport.cleanUp([result.zip]) }

        let data = try Data(contentsOf: result.zip)
        let names = String(decoding: data, as: UTF8.self)
        #expect(data.prefix(4) == Data([0x50, 0x4B, 0x03, 0x04]))
        #expect(names.contains("frodi-2026-09-14-1030.m4a"))
        #expect(names.contains("frodi-2026-09-14-1030.rtf"))
        #expect(names.contains("frodi-2026-09-14-1030-2.m4a"))
        #expect(!names.contains("frodi-2026-09-14-1030-3"))
        #expect(result.skipped.map(\.fileName) == [missing.fileName])
        // Only the zip is left: the plaintext it was made from is gone.
        let left = try FileManager.default.contentsOfDirectory(atPath: result.zip.deletingLastPathComponent().path)
        #expect(left == [result.zip.lastPathComponent])
    }

    /// When nothing opens, there is no zip to share, and the reason is the error.
    @Test("Ingen zip når ingen opptak åpner")
    func exportAllFailsWhenNothingOpens() async throws {
        let missing = Recording(duration: 1, fileName: "\(UUID().uuidString).m4a.enc")
        await #expect(throws: (any Error).self) {
            try await RecordingExport.prepareAll([missing])
        }
    }
}
