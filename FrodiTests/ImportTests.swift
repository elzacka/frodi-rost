import AVFoundation
import Foundation
import Testing
@testable import Frodi

/// An imported file becomes what the recorder writes, whatever it came in as.
/// Fixtures (ffmpeg): `right-channel.mp3` 2 s tone 44,1 kHz, left silent; `dated-stereo.m4a` 1,5 s AAC 48 kHz stereo with creation date;
/// `located.m4a` (via `AVAssetExportSession`) 1 s AAC with title and location as ISO user data (`loci`).
@Suite("Import", .serialized)
struct ImportTests {
    private static let fixtures = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "Fixtures")

    private func removing<T>(_ converted: AudioImport.Converted, _ body: (AudioImport.Converted) throws -> T) rethrows -> T {
        defer { try? FileManager.default.removeItem(at: converted.url) }
        return try body(converted)
    }

    @Test("En mp3-fil blir PCM i 16 kHz og mono, som et opptak")
    func mp3BecomesRecorderFormat() async throws {
        let converted = try await AudioImport.convert(Self.fixtures.appending(path: "right-channel.mp3"))
        try removing(converted) { converted in
            let file = try AVAudioFile(forReading: converted.url)
            let description = file.fileFormat.streamDescription.pointee
            #expect(description.mFormatID == kAudioFormatLinearPCM)
            #expect(description.mBitsPerChannel == 16)
            #expect(file.fileFormat.sampleRate == AudioRecorder.sampleRate)
            #expect(file.fileFormat.channelCount == 1)
            #expect(converted.url.pathExtension == "caf")
            #expect(abs(converted.duration - 2) < 0.05)
            #expect(abs(Double(file.length) / file.fileFormat.sampleRate - converted.duration) < 0.001)
        }
    }

    /// Without the mix, the converter keeps the left channel and drops the
    /// other; a speaker on the right would be lost.
    @Test("Lyd som bare ligger på høyre kanal, blir med")
    func rightChannelSurvives() async throws {
        let converted = try await AudioImport.convert(Self.fixtures.appending(path: "right-channel.mp3"))
        try removing(converted) { converted in
            let file = try AVAudioFile(forReading: converted.url)
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
            try file.read(into: buffer)
            let samples = UnsafeBufferPointer(start: buffer.floatChannelData?[0], count: Int(buffer.frameLength))
            let peak = samples.map(abs).max() ?? 0
            #expect(peak > 0.03)
        }
    }

    @Test("En m4a i stereo blir importert, med datoen fra filen")
    func stereoM4AKeepsItsDate() async throws {
        let converted = try await AudioImport.convert(Self.fixtures.appending(path: "dated-stereo.m4a"))
        try removing(converted) { converted in
            let file = try AVAudioFile(forReading: converted.url)
            #expect(file.fileFormat.sampleRate == AudioRecorder.sampleRate)
            #expect(file.fileFormat.channelCount == 1)
            #expect(abs(converted.duration - 1.5) < 0.05)
            #expect(converted.original.createdAt == ISO8601DateFormatter().date(from: "2026-09-01T10:15:00Z"))
        }
    }

    @Test("Stedet som står i filen, blir ikke lagret")
    func locationIsLeftOut() async throws {
        let converted = try await AudioImport.convert(Self.fixtures.appending(path: "located.m4a"))
        removing(converted) { converted in
            let tags = converted.original.tags
            #expect(tags["title"] == "Testopptak")
            #expect(tags[AVMetadataKey.commonKeyLocation.rawValue] == nil)
            #expect(!tags.values.contains { $0.contains("59.9139") })
        }
    }

    @Test("En fil som ikke er lyd, blir avvist og etterlater ingenting")
    func notAudioIsRejected() async throws {
        let bogus = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".mp3")
        try Data("Dette er ikke lyd.".utf8).write(to: bogus)
        defer { try? FileManager.default.removeItem(at: bogus) }
        let before = try FileManager.default.contentsOfDirectory(atPath: AudioStorage.scratchDirectory.path)

        await #expect(throws: AudioImport.Failure.self) {
            try await AudioImport.convert(bogus)
        }
        let after = try FileManager.default.contentsOfDirectory(atPath: AudioStorage.scratchDirectory.path)
        #expect(Set(after) == Set(before))
    }

    /// The imported file takes the same road as a recording from here: sealed
    /// into AAC, and readable again through the vault.
    @Test("En importert fil lar seg forsegle som et opptak")
    func importedFileSeals() async throws {
        let converted = try await AudioImport.convert(Self.fixtures.appending(path: "dated-stereo.m4a"))
        let name = converted.url.lastPathComponent
        try FileManager.default.moveItem(at: converted.url, to: AudioStorage.directory.appending(path: name))
        let sealed = try await AudioStorage.seal(fileName: name).name
        defer { AudioStorage.delete(fileName: sealed) }

        #expect(sealed == AudioStorage.sealedName(for: name))
        let audio = try await AudioStorage.withDecrypted(fileName: sealed) { url in
            try AVAudioFile(forReading: url).length
        }
        #expect(audio > 0)
    }
}
