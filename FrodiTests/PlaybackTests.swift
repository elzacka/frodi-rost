import AVFoundation
import Foundation
import Testing
@testable import Frodi

/// Serialisert fordi alle testene deler `AudioPlayer.shared`, som er delt av
/// samme grunn i appen: det finnes bare én lydøkt.
@Suite("Avspilling", .serialized)
@MainActor
struct PlaybackTests {
    /// Legger et ekte, forseglet opptak i opptaksmappen og rydder det bort etter.
    private func withSealedRecording(
        seconds: Double = 1,
        _ body: (Recording) async throws -> Void
    ) async throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        try writeSilence(to: source, seconds: seconds)
        defer { try? FileManager.default.removeItem(at: source) }

        let name = UUID().uuidString + ".m4a.enc"
        let target = AudioStorage.directory.appendingPathComponent(name)
        try RecordingVault.seal(fileAt: source).write(to: target)
        defer { AudioStorage.delete(fileName: name) }

        try await body(Recording(duration: seconds, fileName: name))
    }

    private func writeSilence(to url: URL, seconds: Double) throws {
        let rate = 44_100.0
        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: rate,
            AVNumberOfChannelsKey: 1
        ])
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let frames = AVAudioFrameCount(rate * seconds)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        try file.write(from: buffer)
    }

    @Test("Et forseglet opptak lastes og blir spillbart")
    func loadsSealedRecording() async throws {
        try await withSealedRecording { recording in
            let player = AudioPlayer.shared
            defer { player.stop() }

            await player.prepare(recording)

            #expect(player.isLoaded, "Uventet tilstand: \(player.state)")
            #expect(player.duration > 0.5)
            #expect(player.currentTime == 0)
        }
    }

    @Test("Spoling klippes til opptakets ender")
    func seekingIsClamped() async throws {
        try await withSealedRecording { recording in
            let player = AudioPlayer.shared
            defer { player.stop() }

            await player.prepare(recording)

            player.seek(to: -30)
            #expect(player.currentTime == 0)

            player.seek(to: player.duration + 30)
            #expect(player.currentTime == player.duration)

            player.skip(-5)
            #expect(player.currentTime == 0)
        }
    }

    /// Nøkkelen ligger i Secure Enclave på denne enheten. En kopi fra en annen
    /// enhet skal si fra, ikke krasje.
    @Test("Et opptak som ikke lar seg låse opp gir en beskjed")
    func unopenableRecordingFails() async throws {
        let name = UUID().uuidString + ".m4a.enc"
        let target = AudioStorage.directory.appendingPathComponent(name)
        try Data(repeating: 0x41, count: 512).write(to: target)
        defer { AudioStorage.delete(fileName: name) }

        let player = AudioPlayer.shared
        defer { player.stop() }

        await player.prepare(Recording(duration: 3, fileName: name))

        #expect(player.isLoaded == false)
        if case .failed = player.state {} else {
            Issue.record("Forventet .failed, fikk \(player.state)")
        }
    }

    @Test("Et opptak som mangler på disk gir en beskjed")
    func missingFileFails() async {
        let player = AudioPlayer.shared
        defer { player.stop() }

        await player.prepare(Recording(duration: 3, fileName: "finnes-ikke.m4a.enc"))

        #expect(player.isLoaded == false)
    }

    @Test("stop slipper opptaket")
    func stopReleasesRecording() async throws {
        try await withSealedRecording { recording in
            let player = AudioPlayer.shared
            await player.prepare(recording)
            player.stop()

            #expect(player.state == .idle)
            #expect(player.fileName == nil)
            #expect(player.duration == 0)
        }
    }
}
