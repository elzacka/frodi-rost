import CryptoKit
import Foundation
import Testing
@testable import Frodi

@Suite("Kryptering")
struct VaultTests {
    private func temporaryFile(_ contents: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bin")
        try contents.write(to: url)
        return url
    }

    @Test("Forseglet innhold kan åpnes igjen")
    func roundTrip() throws {
        let original = Data("Dette er en test så får vi se om det virker".utf8)
        let url = try temporaryFile(original)
        defer { try? FileManager.default.removeItem(at: url) }

        let sealed = try RecordingVault.seal(fileAt: url)
        let opened = try RecordingVault.open(sealed)
        #expect(opened == original)
    }

    /// Det forseglede innholdet skal ikke inneholde klarteksten.
    @Test("Klarteksten finnes ikke i det forseglede")
    func plaintextIsNotPresent() throws {
        let secret = Data("hemmelig setning som ikke skal lekke".utf8)
        let url = try temporaryFile(secret)
        defer { try? FileManager.default.removeItem(at: url) }

        let sealed = try RecordingVault.seal(fileAt: url)
        #expect(sealed.range(of: secret) == nil)
        #expect(sealed.count > secret.count)
    }

    /// Hvert opptak får sin egen datanøkkel, så to like filer skal ikke gi
    /// like chiffer. Ellers lekker vi at innholdet er identisk.
    @Test("Lik inndata gir ulikt chiffer")
    func sealingIsNotDeterministic() throws {
        let payload = Data("samme innhold".utf8)
        let a = try temporaryFile(payload), b = try temporaryFile(payload)
        defer { try? FileManager.default.removeItem(at: a); try? FileManager.default.removeItem(at: b) }

        #expect(try RecordingVault.seal(fileAt: a) != RecordingVault.seal(fileAt: b))
    }

    @Test("Tuklet innhold blir avvist")
    func tamperingIsRejected() throws {
        let url = try temporaryFile(Data("noe innhold her".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        var sealed = try RecordingVault.seal(fileAt: url)
        sealed[sealed.count - 1] ^= 0xFF

        #expect(throws: (any Error).self) { try RecordingVault.open(sealed) }
    }

    @Test("Søppel blir avvist i stedet for å krasje")
    func garbageIsRejected() {
        #expect(throws: (any Error).self) { try RecordingVault.open(Data([0x00])) }
        #expect(throws: (any Error).self) { try RecordingVault.open(Data()) }
    }
}

@Suite("Forsegling av tekst")
struct TranscriptSealingTests {
    @Test("Tekst kan forsegles og åpnes igjen")
    func textRoundTrip() throws {
        let text = "Dette er en ny test. Jeg lurer på om den tar med tegnsetting."
        let sealed = try RecordingVault.seal(text)
        #expect(try RecordingVault.openText(sealed) == text)
    }

    /// Æ, ø og å må overleve turen gjennom UTF-8 og AES-GCM.
    @Test("Norske tegn overlever forseglingen")
    func norwegianCharactersSurvive() throws {
        let text = "Ærlig talt: øvingen på Sørlandet gikk rått. Fróði skrev ð og ó."
        let sealed = try RecordingVault.seal(text)
        #expect(try RecordingVault.openText(sealed) == text)
    }

    /// Poenget med hele øvelsen: teksten skal ikke kunne leses ut av lagringen.
    @Test("Teksten finnes ikke i klartekst i det forseglede")
    func textIsNotReadable() throws {
        let secret = "hemmelig setning som ikke skal kunne leses"
        let sealed = try RecordingVault.seal(secret)
        #expect(sealed.range(of: Data(secret.utf8)) == nil)
    }

    @Test("Et opptak uten tekst sier at det ikke har noen")
    func recordingWithoutTranscript() throws {
        let recording = Recording(duration: 5, fileName: "a.m4a.enc")
        #expect(recording.hasTranscript == false)
        #expect(try recording.transcript() == nil)
    }

    @Test("Et opptak med tekst gir den tilbake uendret")
    func recordingWithTranscript() throws {
        let recording = Recording(duration: 5, fileName: "a.m4a.enc")
        try recording.setTranscript("Opptaket ble lagret lokalt.")

        #expect(recording.hasTranscript)
        #expect(try recording.transcript() == "Opptaket ble lagret lokalt.")
        // Og det som faktisk ligger på disk skal ikke være lesbart.
        let stored = try #require(recording.sealedTranscript)
        #expect(stored.range(of: Data("Opptaket".utf8)) == nil)
    }
}

@Suite("Eksport")
struct ExportEncodingTests {
    /// Uten BOM gjetter mange lesere at en .txt er Latin-1, og «så» blir «sÃ¥».
    @Test("Tekstfilen starter med UTF-8 BOM")
    func textFileHasByteOrderMark() {
        let data = RecordingExport.utf8WithBOM("Så starter vi et opptak til.")
        #expect(data.prefix(3) == Data([0xEF, 0xBB, 0xBF]))
    }

    @Test("Norske tegn overlever, og kan leses tilbake")
    func norwegianCharactersSurvive() throws {
        let text = "Så, æ, ø og å. Fróði skriver ð og ó."
        let data = RecordingExport.utf8WithBOM(text)

        let decoded = try #require(String(data: data.dropFirst(3), encoding: .utf8))
        #expect(decoded == text)
    }

    /// Feilen som ble meldt: teksten lest som Latin-1 gir «sÃ¥».
    /// Blir den lest som UTF-8, skal det ikke skje.
    @Test("Teksten er ikke Latin-1")
    func isNotLatin1() throws {
        let data = RecordingExport.utf8WithBOM("Så")
        let asLatin1 = try #require(String(data: data.dropFirst(3), encoding: .isoLatin1))
        #expect(asLatin1 == "SÃ¥", "bekrefter at feiltolkning gir mojibake")

        let asUTF8 = try #require(String(data: data.dropFirst(3), encoding: .utf8))
        #expect(asUTF8 == "Så")
    }
}
