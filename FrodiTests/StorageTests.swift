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
    @discardableResult
    private func writeRecording(seconds: Double = 1, name: String = UUID().uuidString + AudioStorage.pendingSuffix) throws -> String {
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

    /// A file the recorder cannot read back is not an empty file. On a locked
    /// device a closed `.completeUnlessOpen` file cannot be reopened, and treating
    /// that as empty deleted the recording; see `AudioRecorder.savedDuration`.
    @Test("Bare en fil som lot seg åpne og er tom, slettes")
    func onlyAnOpenedEmptyFileIsDeleted() {
        #expect(AudioRecorder.savedDuration(measured: 12.5, counted: 12.0) == 12.5)
        #expect(AudioRecorder.savedDuration(measured: nil, counted: 1_140) == 1_140)
        #expect(AudioRecorder.savedDuration(measured: nil, counted: 0) == 0)
        #expect(AudioRecorder.savedDuration(measured: 0, counted: 12.0) == nil)
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

    /// A call splits a recording into files, see `AudioStorage.continuationName`.
    /// Everything that reads the recording by its first name must see all of them.
    @Test("Fortsettelsene etter et anrop hører til opptaket")
    func continuationsBelongToTheRecording() throws {
        let name = try writeRecording(seconds: 1)
        let first = AudioStorage.continuationName(for: name, index: 1)
        let second = AudioStorage.continuationName(for: name, index: 2)
        try writeRecording(seconds: 2, name: first)
        try writeRecording(seconds: 0.5, name: second)
        defer { remove(name) }

        #expect(first.hasSuffix(".1.caf"))
        #expect(AudioStorage.isContinuation(first))
        #expect(!AudioStorage.isContinuation(name))
        #expect(AudioStorage.segmentNames(of: name) == [name, first, second])
        #expect(AudioStorage.sealedName(for: name) == AudioStorage.sealedName(for: first).replacingOccurrences(of: ".1.m4a", with: ".m4a"))

        let stored = AudioStorage.storedFileNames()
        #expect(stored.contains(name))
        #expect(!stored.contains(first))
        #expect(!stored.contains(second))

        let duration = try #require(AudioStorage.duration(fileName: name))
        #expect(abs(duration - 3.5) < 0.01)

        AudioStorage.delete(fileName: name)
        for segment in [name, first, second] {
            #expect(!FileManager.default.fileExists(atPath: AudioStorage.directory.appendingPathComponent(segment).path))
        }
    }

    @Test("Forseglingen setter fortsettelsene sammen til ett opptak")
    func sealJoinsTheContinuations() async throws {
        let name = try writeRecording(seconds: 1)
        try writeRecording(seconds: 2, name: AudioStorage.continuationName(for: name, index: 1))
        let sealed = try await AudioStorage.seal(fileName: name)
        defer { remove(name, sealed) }

        #expect(AudioStorage.segmentNames(of: name) == [name])
        #expect(!FileManager.default.fileExists(atPath: AudioStorage.directory.appendingPathComponent(name).path))

        let plaintext = try AudioStorage.plaintext(fileName: sealed)
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try plaintext.write(to: scratch)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let file = try AVAudioFile(forReading: scratch)
        #expect(abs(Double(file.length) / file.fileFormat.sampleRate - 3) < 0.2)
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

    /// Killed after the call and before the stop: two files, no row.
    @MainActor
    @Test("Et avbrutt opptak uten rad får én rad, med hele lengden")
    func interruptedOrphanGetsOneRow() throws {
        let name = try writeRecording(seconds: 1)
        try writeRecording(seconds: 2, name: AudioStorage.continuationName(for: name, index: 1))
        defer { remove(name) }
        let container = try memoryContainer()
        let context = container.mainContext

        RecordingController.shared.reconcile(context)

        let rows = try context.fetch(FetchDescriptor<Recording>()).filter { $0.fileName.hasPrefix((name as NSString).deletingPathExtension) }
        #expect(rows.count == 1)
        #expect(abs((rows.first?.duration ?? 0) - 3) < 0.01)
    }

    @MainActor
    @Test("En tom klartekstfil er ikke et opptak: ingen rad, og filen fjernes")
    func emptyFileGetsNoRow() throws {
        let name = try writeRecording(seconds: 0)
        defer { remove(name) }
        let container = try memoryContainer()
        let context = container.mainContext
        let row = Recording(duration: 0, fileName: name)
        context.insert(row)
        try context.save()

        RecordingController.shared.reconcile(context)

        let rows = try context.fetch(FetchDescriptor<Recording>())
        #expect(!rows.contains { $0.fileName == name })
        #expect(!AudioStorage.storedFileNames().contains(name))
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
