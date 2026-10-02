import Foundation
import Testing
@testable import Frodi

/// The one setting: names and terms the model should spell right. A class, for the `deinit`: the tests run inside the
/// app, in its container, and write the real list, so each puts back what it found.
@Suite("Ordliste", .serialized)
final class WordListTests {
    private let saved = WordList.load()

    deinit { WordList.save(saved) }

    @Test("Listen lagres forseglet og leses tilbake")
    func roundTripIsSealed() throws {
        WordList.save("Nordkvist AS\nHMS, Kari Berg")
        #expect(WordList.load() == "Nordkvist AS\nHMS, Kari Berg")

        let raw = try Data(contentsOf: WordList.url)
        #expect(raw.range(of: Data("Nordkvist".utf8)) == nil)
        #expect(try WordList.url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test("En tom liste fjerner filen")
    func emptyListRemovesTheFile() {
        WordList.save("Noe")
        WordList.save("  \n")
        #expect(WordList.load() == "")
        #expect(!FileManager.default.fileExists(atPath: WordList.url.path))
    }

    @Test("Linjer og kommaer blir én linje med komma")
    func promptJoinsEntries() {
        #expect(WordList.prompt(from: "Nordkvist AS\nHMS, Kari Berg\n\n") == "Nordkvist AS, HMS, Kari Berg")
        #expect(WordList.prompt(from: " , \n") == nil)
        #expect(WordList.prompt(from: "") == nil)
    }
}

/// The correction pass: listed names, spelled as listed, where the model nearly did.
@Suite("Retting mot ordlisten")
struct WordListCorrectionTests {
    private let entries = ["Nordkvist Maskin", "Tazk", "Sigrid Aaserud", "Berg", "HMS"]

    @Test("En bokstav feil blir rettet, også i et navn på to ord")
    func nearMissesAreCorrected() {
        #expect(WordList.correct("Vi er hos Norgkvist Maskin i dag.", entries: entries) == "Vi er hos Nordkvist Maskin i dag.")
        #expect(WordList.correct("Avvik meldes i TASK Systemet.", entries: entries) == "Avvik meldes i Tazk Systemet.")
        #expect(WordList.correct("har Sigrid Osserud.", entries: entries) == "har Sigrid Aaserud.")
    }

    @Test("Et ord som bare skiller seg i store bokstaver, røres ikke")
    func caseOnlyIsLeftAlone() {
        #expect(WordList.correct("et berg av papir", entries: entries) == "et berg av papir")
        #expect(WordList.correct("hms er viktig", entries: entries) == "hms er viktig")
    }

    @Test("Et vanlig ord som ligner, røres ikke")
    func ordinaryWordsAreLeftAlone() {
        // «maskinen» is one letter from «Maskin», but the entry is two words.
        #expect(WordList.correct("maskinen står der", entries: entries) == "maskinen står der")
        // «Bergen» is two letters from «Berg», and «Berg» allows one.
        #expect(WordList.correct("Vi drar til Bergen", entries: entries) == "Vi drar til Bergen")
        // «tank» is one letter from «Tazk»; that is the accepted risk for a four-letter entry.
        #expect(WordList.correct("en full tank", entries: entries) == "en full Tazk")
    }

    @Test("Tall røres ikke, og korte oppføringer brukes ikke")
    func numbersAndShortEntriesAreSkipped() {
        #expect(WordList.correct("ISO 1900 og 11", entries: ["ISO 19011", "AS"]) == "ISO 1900 og 11")
        #expect(WordList.correct("as det", entries: ["AS"]) == "as det")
    }

    @Test("Tegnsetting rundt ordet beholdes")
    func punctuationSurvives() {
        #expect(WordList.correct("takker Sigrid Osserud, og går.", entries: entries) == "takker Sigrid Aaserud, og går.")
    }

    /// The ending is Norwegian grammar, not a misspelling: the word already
    /// holds the entry as listed.
    @Test("En bøyd form av oppføringen røres ikke")
    func inflectedFormsAreLeftAlone() {
        #expect(WordList.correct("avvikene og internkontrollen", entries: ["internkontroll"]) == "avvikene og internkontrollen")
        #expect(WordList.correct("Tazks rutiner", entries: entries) == "Tazks rutiner")
        #expect(WordList.correct("Sigrid Aaseruds plan", entries: entries) == "Sigrid Aaseruds plan")
    }
}
