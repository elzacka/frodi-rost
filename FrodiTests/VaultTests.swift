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

    /// The sealed content must not contain the plaintext.
    @Test("Klarteksten finnes ikke i det forseglede")
    func plaintextIsNotPresent() throws {
        let secret = Data("hemmelig setning som ikke skal lekke".utf8)
        let url = try temporaryFile(secret)
        defer { try? FileManager.default.removeItem(at: url) }

        let sealed = try RecordingVault.seal(fileAt: url)
        #expect(sealed.range(of: secret) == nil)
        #expect(sealed.count > secret.count)
    }

    /// Every recording gets its own data key, so two identical files must not give
    /// identical ciphertext. Otherwise we leak that the content is the same.
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

/// A recording is plaintext from the moment it is stopped until it is sealed.
/// Sealing renames it, removes the plaintext and leaves a file that can only be
/// read through the vault. Nothing here may delete a recording: if sealing
/// fails, the plaintext stays and is retried.
@Suite("Forsegling av opptak")
struct FileSealingTests {
    private func plaintextRecording(_ contents: Data) throws -> String {
        let name = "\(UUID().uuidString).m4a"
        try contents.write(to: AudioStorage.directory.appendingPathComponent(name))
        return name
    }

    @Test("Filnavnet forteller om opptaket er forseglet")
    func suffixTellsSealedFromPending() {
        #expect(AudioStorage.isSealed("a.m4a.enc"))
        #expect(!AudioStorage.isSealed("a.m4a"))
    }

    @Test("Forsegling bytter navn, fjerner klarteksten og kan åpnes igjen")
    func sealingReplacesPlaintext() async throws {
        let original = Data("et opptak som venter på forsegling".utf8)
        let name = try plaintextRecording(original)

        let sealed = try await AudioStorage.seal(fileName: name)
        defer { AudioStorage.delete(fileName: sealed) }

        #expect(sealed == name + ".enc")
        #expect(AudioStorage.isSealed(sealed))
        #expect(!FileManager.default.fileExists(atPath: AudioStorage.directory.appendingPathComponent(name).path))

        let stored = try Data(contentsOf: AudioStorage.directory.appendingPathComponent(sealed))
        #expect(stored.range(of: original) == nil)
        #expect(try AudioStorage.plaintext(fileName: sealed) == original)
    }

    /// The finished file is class A: unreadable while the device is locked.
    ///
    /// Device only. The simulator has no data protection and answers `nil` for the
    /// attribute, so there the test would fail without meaning anything.
    @Test("Et forseglet opptak kan leses etter første opplåsing, ikke før", .enabled(if: !isSimulator))
    func sealedFileIsCompletelyProtected() async throws {
        let name = try plaintextRecording(Data("innhold".utf8))
        let sealed = try await AudioStorage.seal(fileName: name)
        defer { AudioStorage.delete(fileName: sealed) }

        let attributes = try FileManager.default.attributesOfItem(
            atPath: AudioStorage.directory.appendingPathComponent(sealed).path
        )
        #expect(attributes[.protectionKey] as? FileProtectionType == .completeUntilFirstUserAuthentication)
    }

    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    /// A recording that is not sealed yet is read as it is, so the list can play
    /// and export it in the short window before the seal.
    @Test("Et uforseglet opptak leses som det er")
    func pendingRecordingIsReadable() throws {
        let original = Data("ikke forseglet ennå".utf8)
        let name = try plaintextRecording(original)
        defer { AudioStorage.delete(fileName: name) }

        #expect(try AudioStorage.plaintext(fileName: name) == original)
    }

    /// A missing plaintext fails instead of producing an empty sealed file.
    @Test("Forsegling av en fil som mangler feiler")
    func sealingMissingFileThrows() async {
        await #expect(throws: (any Error).self) {
            try await AudioStorage.seal(fileName: "finnes-ikke.m4a")
        }
    }
}

/// Temporary plaintext lives in one folder so that a crash cannot leave any of
/// it behind for longer than until the next launch.
@Suite("Midlertidig klartekst", .serialized)
struct ScratchTests {
    @Test("Mappen tømmes ved oppstart")
    func clearRemovesLeftovers() throws {
        let leftover = AudioStorage.scratchDirectory.appendingPathComponent("etterlatt.m4a")
        try Data("klartekst".utf8).write(to: leftover)
        #expect(FileManager.default.fileExists(atPath: leftover.path))

        AudioStorage.clearScratch()
        #expect(!FileManager.default.fileExists(atPath: leftover.path))

        // And the folder comes back on demand.
        #expect(FileManager.default.fileExists(atPath: AudioStorage.scratchDirectory.path))
    }

    @Test("Eksporten skriver til klartekstmappen")
    func exportWritesIntoScratch() async throws {
        let name = "\(UUID().uuidString).m4a.enc"
        try RecordingVault.seal(Data("lyd".utf8)).write(to: AudioStorage.directory.appendingPathComponent(name))
        defer { AudioStorage.delete(fileName: name) }

        let recording = Recording(duration: 1, fileName: name)
        let urls = try await RecordingExport.prepare(recording)
        defer { RecordingExport.cleanUp(urls) }

        let scratch = AudioStorage.scratchDirectory.standardizedFileURL.path
        for url in urls {
            #expect(url.standardizedFileURL.path.hasPrefix(scratch), "\(url.path) ligger utenfor \(scratch)")
        }
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

    /// Æ, ø and å must survive the trip through UTF-8 and AES-GCM.
    @Test("Norske tegn overlever forseglingen")
    func norwegianCharactersSurvive() throws {
        let text = "Ærlig talt: øvingen på Sørlandet gikk rått. Fróði skrev ð og ó."
        let sealed = try RecordingVault.seal(text)
        #expect(try RecordingVault.openText(sealed) == text)
    }

    /// The point of the whole exercise: the text must not be readable out of storage.
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
        // And what actually sits on disk must not be readable.
        let stored = try #require(recording.sealedTranscript)
        #expect(stored.range(of: Data("Opptaket".utf8)) == nil)
    }
}

@Suite("Eksport")
struct ExportEncodingTests {
    /// Without a BOM many readers guess that a .txt is Latin-1, and «så» becomes «sÃ¥».
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

    /// The reported bug: the text read as Latin-1 gives «sÃ¥».
    /// Read as UTF-8, that must not happen.
    @Test("Teksten er ikke Latin-1")
    func isNotLatin1() throws {
        let data = RecordingExport.utf8WithBOM("Så")
        let asLatin1 = try #require(String(data: data.dropFirst(3), encoding: .isoLatin1))
        #expect(asLatin1 == "SÃ¥", "bekrefter at feiltolkning gir mojibake")

        let asUTF8 = try #require(String(data: data.dropFirst(3), encoding: .utf8))
        #expect(asUTF8 == "Så")
    }
}

/// A long recording goes through the same steps as a short one, but at numbers
/// large enough that a truncation would show: the audio file is read whole,
/// decrypted whole and written whole, and the same goes for the text.
@Suite("Uttrekk av lange opptak", .serialized)
struct LongExportTests {
    /// 30 MB of sealed audio corresponds to about an hour of recording, which sits
    /// at roughly 64 kbit/s.
    private static let audioBytes = 30 * 1024 * 1024

    private func sealedRecording(audio: Data, transcript: String) throws -> Recording {
        let name = "\(UUID().uuidString).m4a.enc"
        try RecordingVault.seal(audio).write(to: AudioStorage.directory.appendingPathComponent(name))

        let recording = Recording(duration: 3600, fileName: name)
        try recording.setTranscript(transcript)
        return recording
    }

    @Test("Hele lydfilen og hele teksten kommer med")
    func longRecordingSurvivesExport() async throws {
        // A pattern, not zeros: a truncated or shifted file must not be able to look
        // right by chance.
        let block = Data((0..<4096).map { UInt8($0 % 251) })
        var audio = Data(capacity: Self.audioBytes)
        while audio.count < Self.audioBytes { audio.append(block) }

        // Around 20 000 words, which is more than an hour of speech.
        let transcript = Array(repeating: "Så kjørte vi videre mot Kristiansand i øsende regn.", count: 2_000)
            .joined(separator: " ")

        let recording = try sealedRecording(audio: audio, transcript: transcript)
        defer { AudioStorage.delete(fileName: recording.fileName) }

        let urls = try await RecordingExport.prepare(recording, content: .both, format: .txt)
        defer { RecordingExport.cleanUp(urls) }

        #expect(urls.count == 2)

        let exportedAudio = try Data(contentsOf: try #require(urls.first { $0.pathExtension == "m4a" }))
        #expect(exportedAudio == audio)

        let exportedText = try Data(contentsOf: try #require(urls.first { $0.pathExtension == "txt" }))
        #expect(exportedText == RecordingExport.utf8WithBOM(transcript))
        #expect(String(data: exportedText.dropFirst(3), encoding: .utf8) == transcript)
    }
}
