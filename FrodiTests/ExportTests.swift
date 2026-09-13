import Foundation
import Testing
@testable import Frodi

/// The document the auditor sends on. It has to open as a document, with the
/// paragraphs and marks intact, in Bokmål whatever the device is set to.
@Suite("Uthenting")
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
