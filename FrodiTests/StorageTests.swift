import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import Frodi

/// The recording on disk is the recording. These tests cover the moments where
/// the file and the list can come apart, and the seal that turns PCM into AAC.
@Suite("Lagring", .serialized)
struct StorageTests {
    /// Writes a second of PCM in a CAF, the way the recorder does, into the
    /// recordings folder.
    private func writeRecording(seconds: Double = 1) throws -> String {
        let name = UUID().uuidString + AudioStorage.pendingSuffix
        let url = AudioStorage.directory.appendingPathComponent(name)
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: AudioRecorder.sampleRate, channels: 1, interleaved: true)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatInt16, interleaved: true)
        let frames = AVAudioFrameCount(seconds * AudioRecorder.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        try file.write(from: buffer)
        return name
    }

    private func remove(_ names: String...) {
        for name in names { AudioStorage.delete(fileName: name) }
    }

    @Test("Et forseglet navn er alltid .m4a.enc, uansett hva klarteksten het")
    func sealedNameIsAlwaysM4A() {
        #expect(AudioStorage.sealedName(for: "abc.caf") == "abc.m4a.enc")
        #expect(AudioStorage.sealedName(for: "abc.m4a") == "abc.m4a.enc")
    }

    @Test("Lengden leses fra filen")
    func durationComesFromFile() throws {
        let name = try writeRecording(seconds: 2.5)
        defer { remove(name) }
        let duration = try #require(AudioStorage.duration(fileName: name))
        #expect(abs(duration - 2.5) < 0.01)
    }

    @Test("Forseglingen gjør PCM om til AAC som kan åpnes")
    func sealEncodesToAAC() async throws {
        let name = try writeRecording()
        let sealed = try await AudioStorage.seal(fileName: name)
        defer { remove(name, sealed) }

        #expect(sealed.hasSuffix(".m4a.enc"))
        #expect(!FileManager.default.fileExists(atPath: AudioStorage.directory.appendingPathComponent(name).path))

        let plaintext = try AudioStorage.plaintext(fileName: sealed)
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try plaintext.write(to: scratch)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let file = try AVAudioFile(forReading: scratch)
        #expect(file.fileFormat.formatDescription.audioStreamBasicDescription?.mFormatID == kAudioFormatMPEG4AAC)
        #expect(abs(Double(file.length) / file.fileFormat.sampleRate - 1) < 0.2)
    }

    /// A crash between writing the sealed copy and removing the plaintext, or
    /// between removing it and saving the new name, lands here on the next pass.
    @Test("En forsegling som allerede finnes brukes som den er")
    func sealIsIdempotent() async throws {
        let name = try writeRecording()
        let sealed = try await AudioStorage.seal(fileName: name)
        defer { remove(name, sealed) }

        let before = try Data(contentsOf: AudioStorage.directory.appendingPathComponent(sealed))
        let again = try await AudioStorage.seal(fileName: name)
        let after = try Data(contentsOf: AudioStorage.directory.appendingPathComponent(sealed))

        #expect(again == sealed)
        #expect(before == after)
    }

    /// The container must outlive the context: `mainContext` does not retain it,
    /// and an insert on a context whose container is gone traps inside SwiftData.
    @MainActor
    private func memoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Recording.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    @Test("En fil uten rad får en rad, med lengde og dato fra filen")
    func orphanGetsARow() throws {
        let name = try writeRecording(seconds: 3)
        defer { remove(name) }
        let container = try memoryContainer()
        let context = container.mainContext

        RecordingController.shared.reconcile(context)

        let rows = try context.fetch(FetchDescriptor<Recording>())
        let row = try #require(rows.first { $0.fileName == name })
        #expect(abs(row.duration - 3) < 0.01)
        #expect(abs(row.createdAt.timeIntervalSinceNow) < 60)
    }

    @MainActor
    @Test("En rad som peker på klartekst som er forseglet får det nye navnet")
    func rowFollowsTheSeal() async throws {
        let name = try writeRecording()
        let container = try memoryContainer()
        let context = container.mainContext
        let row = Recording(duration: 1, fileName: name)
        context.insert(row)
        try context.save()

        let sealed = try await AudioStorage.seal(fileName: name)
        defer { remove(name, sealed) }

        RecordingController.shared.reconcile(context)

        #expect(row.fileName == sealed)
        let rows = try context.fetch(FetchDescriptor<Recording>())
        #expect(rows.filter { $0.fileName == sealed }.count == 1)
    }
}
