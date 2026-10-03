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

    private let labelled = "[0:30] Person 1: Velkommen.\n\n[0:35] Person 2: Tusen takk.\n\n[0:40] Person 1: Hvordan var turen?"

    @Test("Navnene leses tilbake, og teksten står uten navn")
    func readsSpeakersBack() {
        let parsed = Transcript.paragraphs(in: labelled)
        #expect(parsed.map(\.speaker) == ["Person 1", "Person 2", "Person 1"])
        #expect(parsed.map(\.text) == ["Velkommen.", "Tusen takk.", "Hvordan var turen?"])
        #expect(Transcript.speakers(in: labelled) == ["Person 1", "Person 2"])
    }

    @Test("Et kolon i vanlig tekst er ikke et navn")
    func colonInEnkelIsText() {
        let enkel = "[0:00] Merk: Dette er viktig.\n\n[0:10] Det andre avsnittet."
        #expect(Transcript.paragraphs(in: enkel).allSatisfy { $0.speaker == nil })
        // Every paragraph opening alike is still one name, not a conversation.
        let same = "[0:00] Merk: Én.\n\n[0:10] Merk: To."
        #expect(Transcript.paragraphs(in: same).allSatisfy { $0.speaker == nil })
    }

    @Test("Et nytt navn gjelder i hele teksten")
    func renamesEverywhere() {
        let renamed = Transcript.renaming("Person 1", to: "Halvard", in: labelled)
        #expect(renamed == "[0:30] Halvard: Velkommen.\n\n[0:35] Person 2: Tusen takk.\n\n[0:40] Halvard: Hvordan var turen?")
    }

    @Test("To personer med samme navn blir én")
    func sameNameMerges() {
        let threeVoices = labelled + "\n\n[0:50] Person 3: Bra."
        let merged = Transcript.renaming("Person 3", to: "Person 1", in: threeVoices)
        #expect(Transcript.speakers(in: merged) == ["Person 1", "Person 2"])
        #expect(merged.hasSuffix("[0:50] Person 1: Bra."))
        // One name left is one voice: no labels, as when the diarization finds one.
        #expect(Transcript.renaming("Person 2", to: "Person 1", in: labelled)
            == "[0:30] Velkommen.\n\n[0:35] Tusen takk.\n\n[0:40] Hvordan var turen?")
    }

    @Test("Kolon, linjeskift og tomme navn slipper ikke inn")
    func cleansNames() {
        #expect(Transcript.renaming("Person 1", to: "  Kari:\nNord  ", in: labelled).hasPrefix("[0:30] Kari Nord: "))
        #expect(Transcript.renaming("Person 1", to: " : ", in: labelled) == labelled)
        let long = String(repeating: "a", count: 60)
        #expect(Transcript.speakers(in: Transcript.renaming("Person 1", to: long, in: labelled)).first?.count == Transcript.longestName)
    }

    @Test("Tekstmodus er Enkel til du velger noe annet")
    func modeDefaultsToEnkel() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: TextMode.key)
        defer { defaults.set(saved, forKey: TextMode.key) }

        defaults.removeObject(forKey: TextMode.key)
        #expect(TextMode.current == .enkel)
        #expect(TranscriptProgress().speakers == false)
        defaults.set(TextMode.avansert.rawValue, forKey: TextMode.key)
        #expect(TextMode.current == .avansert)
        #expect(TranscriptProgress().speakers == true)
    }

    @Test("RTF-en har navnet foran avsnittet")
    func rtfCarriesSpeakers() throws {
        let data = try RecordingExport.rtf(labelled, createdAt: .now, duration: 45)
        let text = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string
        #expect(text.contains("[0:35] Person 2: Tusen takk."))
    }

    @Test("Bare navn brukeren har gitt, regnes som gitt")
    func givenNames() {
        #expect(!Transcript.hasGivenNames(in: labelled))
        #expect(Transcript.hasGivenNames(in: Transcript.renaming("Person 2", to: "Julia", in: labelled)))
        #expect(!Transcript.hasGivenNames(in: "[0:00] Merk: Én.\n\n[0:10] To."))
        // A merge that breaks the numbering is a change too. Merging the last voice leaves numbers the diarization
        // could have written, and that cannot be told from the text.
        let threeVoices = labelled + "\n\n[0:50] Person 3: Bra."
        #expect(Transcript.hasGivenNames(in: Transcript.renaming("Person 2", to: "Person 1", in: threeVoices)))
    }

    /// 1.0 (9) kept a place from an imported file, and origins are never rewritten.
    @Test("Et sted fra en eldre import vises som «Sted»")
    func oldLocationTag() {
        #expect(RecordingDetailView.tagLabel("location") == "Sted")
    }

    private func words(_ texts: [String]) -> [TimedWord] {
        texts.enumerated().map { TimedWord(start: Double($0.offset) * 0.3, end: Double($0.offset) * 0.3 + 0.25, text: " " + $0.element) }
    }

    /// From the press interview: the change landed after «er», inside the interviewer's question.
    @Test("Et skifte midt i en setning flyttes til setningens slutt")
    func changeMovesToSentenceEnd() {
        let text = ["ser", "at", "det", "er", "7000", "nordmenn", "igjen...", "Det", "er", "stort."]
        let voices = [0, 0, 0, 0, 1, 1, 1, 1, 1, 1]
        #expect(Speakers.smoothed(voices, words: words(text)) == [0, 0, 0, 0, 0, 0, 0, 1, 1, 1])
    }

    @Test("Et ord eller to mellom to biter av samme stemme blir hos den")
    func scrapJoinsItsNeighbours() {
        let text = ["Det", "er", "fantastisk.", "Støtte", "i", "dag", "er", "kjekt."]
        let voices = [0, 0, 0, 0, 1, 0, 0, 0]
        #expect(Speakers.smoothed(voices, words: words(text)) == [0, 0, 0, 0, 0, 0, 0, 0])
    }

    @Test("Et skifte ved setningsslutt står der det står")
    func changeAtSentenceEndStays() {
        let text = ["Velkommen.", "Tusen", "takk."]
        #expect(Speakers.smoothed([0, 1, 1], words: words(text)) == [0, 1, 1])
    }
}
