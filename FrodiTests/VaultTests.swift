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
