import CryptoKit
import Foundation
import Testing
@testable import Frodi

/// A recording's name can change; what it was when it came in cannot, and a
/// change made outside the app shows.
@Suite("Opprinnelse og navn")
struct OriginTests {
    private static let fixtures = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "Fixtures")

    /// Whole seconds: the origin stores dates as ISO 8601.
    private let date = Date(timeIntervalSince1970: 1_789_000_000)

    private func origin(for fileName: String, duration: TimeInterval = 42) -> RecordingOrigin {
        RecordingOrigin(
            recordingID: RecordingOrigin.recordingID(for: fileName),
            source: .recorded,
            createdAt: date,
            duration: duration,
            importedAt: nil,
            original: nil
        )
    }

    @Test("Id-en er filnavnet uten endelser, forseglet eller ikke")
    func idIsTheStem() {
        #expect(RecordingOrigin.recordingID(for: "ABC.caf") == "ABC")
        #expect(RecordingOrigin.recordingID(for: "ABC.m4a.enc") == "ABC")
    }

    @Test("Opprinnelsen åpnes og stemmer etter forseglingen har gitt filen nytt navn")
    func originSurvivesTheSeal() throws {
        let recording = Recording(createdAt: date, duration: 42, fileName: "ABC.caf")
        let written = origin(for: "ABC.caf")
        try recording.recordOrigin(written)
        recording.fileName = "ABC.m4a.enc"
        #expect(recording.origin() == .verified(written))
    }

    @Test("Opprinnelsen skrives bare én gang")
    func originIsWrittenOnce() throws {
        let recording = Recording(createdAt: date, duration: 42, fileName: "ABC.m4a.enc")
        let first = origin(for: "ABC.m4a.enc")
        try recording.recordOrigin(first)
        try recording.recordOrigin(origin(for: "ABC.m4a.enc", duration: 9_999))
        #expect(recording.origin() == .verified(first))
    }

    @Test("En endret byte gjør opprinnelsen ubekreftet")
    func tamperingShows() throws {
        var sealed = try RecordingVault.seal(try origin(for: "ABC.m4a.enc").encoded())
        sealed[sealed.count - 1] ^= 0x01
        #expect(RecordingOrigin.verify(sealed, fileName: "ABC.m4a.enc") == .unverifiable)
    }

    @Test("En opprinnelse flyttet til et annet opptak blir ubekreftet")
    func movedOriginShows() throws {
        let sealed = try RecordingVault.seal(try origin(for: "ABC.m4a.enc").encoded())
        #expect(RecordingOrigin.verify(sealed, fileName: "ABC.m4a.enc") == .verified(origin(for: "ABC.m4a.enc")))
        #expect(RecordingOrigin.verify(sealed, fileName: "XYZ.m4a.enc") == .unverifiable)
    }

    @Test("Et opptak uten opprinnelse har ingen")
    func oldRecordingHasNone() {
        #expect(Recording(duration: 1, fileName: "old.m4a.enc").origin() == .none)
    }

    @Test("Navnet er én linje, uten mellomrom i endene, og tomt betyr ingen")
    func titleIsOneTrimmedLine() throws {
        let recording = Recording(duration: 1, fileName: "a.m4a.enc")
        #expect(recording.title() == nil)

        try recording.setTitle("  Intervju\nAall  ")
        #expect(recording.title() == "Intervju Aall")
        #expect(recording.sealedTitle.map { !String(decoding: $0, as: UTF8.self).contains("Aall") } == true)

        try recording.setTitle(String(repeating: "x", count: 300))
        #expect(recording.title()?.count == Recording.titleLimit)

        try recording.setTitle("   ")
        #expect(recording.title() == nil)
        #expect(recording.sealedTitle == nil)
    }

    @Test("Et nytt navn rører ikke opprinnelsen")
    func renamingLeavesTheOrigin() throws {
        let recording = Recording(createdAt: date, duration: 42, fileName: "ABC.m4a.enc")
        let written = origin(for: "ABC.m4a.enc")
        try recording.recordOrigin(written)
        try recording.setTitle("Intervju")
        #expect(recording.origin() == .verified(written))
    }

    @Test("Importen tar vare på originalens navn, størrelse, sjekksum og format")
    func importKeepsTheOriginal() async throws {
        let url = Self.fixtures.appending(path: "right-channel.mp3")
        let converted = try await AudioImport.convert(url)
        defer { try? FileManager.default.removeItem(at: converted.url) }

        let bytes = try Data(contentsOf: url)
        let original = converted.original
        #expect(original.name == "right-channel.mp3")
        #expect(original.byteCount == bytes.count)
        #expect(original.sha256 == RecordingExport.sha256(bytes))
        #expect(original.format == "MP3")
        #expect(original.sampleRate == 44_100)
        #expect(original.channels == 2)
        #expect(RecordingDetailView.format(of: original) == "MP3, 44,1 kHz, stereo")
    }

    @Test("Datoen i filens metadata blir med, og står ikke to ganger")
    func importKeepsTheStatedDate() async throws {
        let converted = try await AudioImport.convert(Self.fixtures.appending(path: "dated-stereo.m4a"))
        defer { try? FileManager.default.removeItem(at: converted.url) }

        #expect(converted.original.createdAt == ISO8601DateFormatter().date(from: "2026-09-01T10:15:00Z"))
        #expect(converted.original.format == "AAC")
        #expect(converted.original.tags["creationDate"] == nil)
    }

    @Test("RTF-en har navnet, opprinnelsen og sjekksummen for lydfilen")
    func rtfCarriesNameAndChecksums() throws {
        let original = RecordingOrigin.OriginalFile(
            name: "Intervju.mp3", byteCount: 10, sha256: String(repeating: "a", count: 64),
            format: "MP3", sampleRate: 44_100, channels: 2, createdAt: nil, tags: [:]
        )
        let origin = RecordingOrigin(
            recordingID: "ABC", source: .imported, createdAt: date, duration: 5,
            importedAt: date, original: original
        )
        let audio = Data("lyd".utf8)
        let data = try RecordingExport.rtf(
            "Teksten.", createdAt: date, duration: 5, title: "Intervju Aall",
            origin: origin, audio: (name: "frodi-x.m4a", sha256: RecordingExport.sha256(audio))
        )
        let text = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ).string

        #expect(text.hasPrefix("Intervju Aall\n"))
        #expect(text.contains("Opptak \(date.recordingStamp)."))
        #expect(text.contains("fra Intervju.mp3. Sjekksum for originalen (SHA-256): \(original.sha256)"))
        #expect(text.contains("Sjekksum for frodi-x.m4a (SHA-256): \(SHA256.hash(data: audio).map { String(format: "%02x", $0) }.joined())"))
    }
}
