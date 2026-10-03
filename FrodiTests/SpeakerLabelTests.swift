import Foundation
import Testing
@testable import Frodi

/// Avansert: words matched to the voices SpeakerKit found, and the labels in the stored text.
@Suite("Hvem sa hva")
struct SpeakerLabelTests {
    private func word(_ start: TimeInterval, _ end: TimeInterval, _ text: String) -> TimedWord {
        TimedWord(start: start, end: end, text: text)
    }

    /// «Velkommen. Tusen takk.» from the podcast: the host, then a guest, in one paragraph.
    private var exchange: TranscriptParagraph {
        TranscriptParagraph(start: 30, end: 37, text: "Velkommen. Tusen takk.", words: [
            word(30, 31, " Velkommen."), word(35.6, 35.8, " Tusen"), word(35.8, 36, " takk.")
        ])
    }

    @Test("Et avsnitt deles der stemmen skifter")
    func splitsAtTheChange() {
        let turns = [Speakers.Turn(start: 0, end: 35.5, speaker: 0), Speakers.Turn(start: 35.5, end: 37, speaker: 1)]
        let labelled = Speakers.label([exchange], turns: turns) { $0 }
        #expect(labelled.map(\.text) == ["Velkommen.", "Tusen takk."])
        #expect(labelled.map(\.speaker) == [1, 2])
        #expect(labelled[1].start == 35.6)
        #expect(labelled.allSatisfy { $0.words == nil })
    }

    @Test("Stemmene får nummer i den rekkefølgen de høres")
    func numbersByFirstHeard() {
        let turns = [Speakers.Turn(start: 0, end: 35.5, speaker: 7), Speakers.Turn(start: 35.5, end: 37, speaker: 3)]
        #expect(Speakers.label([exchange], turns: turns) { $0 }.map(\.speaker) == [1, 2])
    }

    @Test("Én stemme gir ingen merking, og teksten er uendret")
    func oneVoiceNoLabels() {
        let turns = [Speakers.Turn(start: 0, end: 40, speaker: 0)]
        let labelled = Speakers.label([exchange], turns: turns) { $0 + " (rettet)" }
        #expect(labelled == [TranscriptParagraph(start: 30, end: 37, text: "Velkommen. Tusen takk.")])
    }

    @Test("Uten talere er teksten uendret")
    func noTurnsNoLabels() {
        #expect(Speakers.label([exchange], turns: []) { $0 }.map(\.speaker) == [nil])
    }

    @Test("Et ord mellom to taler går til den nærmeste")
    func gapGoesToNearest() {
        let turns = [Speakers.Turn(start: 0, end: 31, speaker: 0), Speakers.Turn(start: 36.5, end: 40, speaker: 1)]
        // «Tusen» (35.6–35.8) lies in the gap, nearer the second voice.
        #expect(Speakers.label([exchange], turns: turns) { $0 }.map(\.text) == ["Velkommen.", "Tusen takk."])
    }

    @Test("Et avsnitt uten ordtider får stemmen som dekker det")
    func paragraphWithoutWords() {
        let paragraphs = [
            TranscriptParagraph(start: 0, end: 10, text: "Første."),
            TranscriptParagraph(start: 10, end: 20, text: "Andre.")
        ]
        let turns = [Speakers.Turn(start: 0, end: 9, speaker: 0), Speakers.Turn(start: 11, end: 20, speaker: 1)]
        #expect(Speakers.label(paragraphs, turns: turns) { $0 }.map(\.speaker) == [1, 2])
    }

    @Test("Ordlisten rettes også i tekst som bygges av ord")
    func wordListOnSplitText() {
        let turns = [Speakers.Turn(start: 0, end: 35.5, speaker: 0), Speakers.Turn(start: 35.5, end: 37, speaker: 1)]
        let labelled = Speakers.label([exchange], turns: turns) { $0.replacingOccurrences(of: "Tusen", with: "Tusind") }
        #expect(labelled.map(\.text) == ["Velkommen.", "Tusind takk."])
    }

    @Test("Teksten får «Person 1:» etter tidsmerket")
    func composedWithLabels() {
        let text = Transcript.compose([
            TranscriptParagraph(start: 30, end: 31, text: "Velkommen.", speaker: 1),
            TranscriptParagraph(start: 35.6, end: 36, text: "Tusen takk.", speaker: 2)
        ])
        #expect(text == "[0:30] Person 1: Velkommen.\n\n[0:35] Person 2: Tusen takk.")
    }

    @Test("Fremdrift lagret før Tekstmodus fantes, leses som Enkel")
    func oldProgressIsEnkel() throws {
        let json = #"{"position":180,"paragraphs":[{"start":0,"end":24.2,"text":"Vi starter."}]}"#
        let progress = try JSONDecoder().decode(TranscriptProgress.self, from: Data(json.utf8))
        #expect(progress.speakers == nil)
        #expect(progress.paragraphs[0].words == nil)
    }
}
