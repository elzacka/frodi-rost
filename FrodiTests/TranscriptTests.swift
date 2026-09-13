import Foundation
import Testing
@testable import Frodi

/// The text format: paragraphs opened by the time they were said at. It is what
/// is stored, shown and exported, so composing and reading back must agree.
@Suite("Tekstformat")
struct TranscriptTests {
    private let paragraphs = [
        TranscriptParagraph(start: 0, end: 24.2, text: "Vi starter med å gå gjennom prosedyren."),
        TranscriptParagraph(start: 757.4, end: 780, text: "Hvem har ansvar for oppfølgingen?"),
        TranscriptParagraph(start: 3725.9, end: 3750, text: "Takk for samtalen.")
    ]

    @Test("Hvert avsnitt åpner med tidspunktet det ble sagt på")
    func paragraphsCarryMarks() {
        let text = Transcript.compose(paragraphs)
        #expect(text == """
        [0:00] Vi starter med å gå gjennom prosedyren.

        [12:37] Hvem har ansvar for oppfølgingen?

        [1:02:05] Takk for samtalen.
        """)
    }

    @Test("Teksten leses tilbake til de samme avsnittene")
    func roundTrip() {
        let parsed = Transcript.paragraphs(in: Transcript.compose(paragraphs))
        #expect(parsed.count == 3)
        #expect(parsed[0].mark == 0)
        #expect(parsed[1].mark == 757)
        #expect(parsed[2].mark == 3725)
        #expect(parsed[2].text == "Takk for samtalen.")
    }

    /// A short note, or a text from before the marks existed: one paragraph, no mark.
    @Test("Ett avsnitt får ingen tidsmerking")
    func singleParagraphHasNoMark() {
        let text = Transcript.compose([paragraphs[0]])
        #expect(text == "Vi starter med å gå gjennom prosedyren.")
        let parsed = Transcript.paragraphs(in: text)
        #expect(parsed.count == 1)
        #expect(parsed[0].mark == nil)
    }

    @Test("Tomme avsnitt faller bort")
    func emptyParagraphsAreDropped() {
        let text = Transcript.compose([paragraphs[0], TranscriptParagraph(start: 30, end: 40, text: ""), paragraphs[1]])
        #expect(Transcript.paragraphs(in: text).count == 2)
    }

    @Test("En hakeparentes i teksten er ikke en tidsmerking")
    func bracketInTextIsNotAMark() {
        let parsed = Transcript.paragraphs(in: "[uklart] sa hun")
        #expect(parsed[0].mark == nil)
        #expect(parsed[0].text == "[uklart] sa hun")
    }

    @Test("Fremdriften overlever en omstart, forseglet")
    func progressRoundTrip() {
        let fileName = UUID().uuidString + ".m4a.enc"
        defer { TranscriptProgress.clear(for: fileName) }

        #expect(!TranscriptProgress.exists(for: fileName))
        var progress = TranscriptProgress()
        progress.position = 180
        progress.paragraphs = [paragraphs[0]]
        progress.save(for: fileName)

        #expect(TranscriptProgress.exists(for: fileName))
        let loaded = TranscriptProgress.load(for: fileName)
        #expect(loaded?.position == 180)
        #expect(loaded?.paragraphs == [paragraphs[0]])

        // Sealed: the sentence is not in the file.
        let url = AudioStorage.directory.appendingPathComponent(TranscriptProgress.stem(of: fileName) + TranscriptProgress.suffix)
        let raw = try? Data(contentsOf: url)
        #expect(raw?.range(of: Data("prosedyren".utf8)) == nil)
    }

    @Test("Fremdriften følger opptaket gjennom forseglingen")
    func progressStemSurvivesSealing() {
        #expect(TranscriptProgress.stem(of: "abc.caf") == "abc")
        #expect(TranscriptProgress.stem(of: "abc.m4a.enc") == "abc")
    }

    /// The seam is cut at the quietest moment, not at the nominal boundary.
    @Test("Et stykke klippes der det er stillest")
    func seamFallsInSilence() {
        let rate = 16_000
        var audio = [Float](repeating: 0.5, count: 60 * rate)
        // A quiet second from 52 to 53 seconds in, inside the search window.
        for index in (52 * rate)..<(53 * rate) { audio[index] = 0 }

        let cut = WhisperTranscriber.seam(in: audio)!
        #expect(cut >= 52 * rate && cut < 53 * rate)
    }

    @Test("For kort til å lete gir ingen søm")
    func tooShortForSeam() {
        #expect(WhisperTranscriber.seam(in: [Float](repeating: 0, count: 16_000)) == nil)
    }
}
