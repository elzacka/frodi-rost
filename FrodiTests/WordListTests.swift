import Foundation
import Testing
@testable import Frodi

/// The one setting: names and terms the model should spell right.
@Suite("Ordliste", .serialized)
struct WordListTests {
    @Test("Listen lagres forseglet og leses tilbake")
    func roundTripIsSealed() throws {
        defer { WordList.save("") }
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
