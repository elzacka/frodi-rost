import AVFoundation
import Foundation

/// Brings an audio file from outside the app in as a recording.
///
/// The file is converted to what the recorder itself writes: linear PCM at
/// 16 kHz, mono, in a CAF, see `AudioRecorder.fileSettings`. From there it is a
/// recording like any other: `AudioStorage.seal` encodes and encrypts it, and
/// `Transcription.run` makes the text. One format on disk means one path
/// through the seal, playback, export and the length rule, and an hour takes
/// the same room and memory whatever it came in as. The original is left where
/// it was, untouched.
///
/// Anything Core Audio reads comes in: m4a, mp3, wav, aiff, caf. Stereo is mixed
/// down, not cut to the left channel: an interview recorded with one microphone
/// per speaker has one speaker per channel. Measured on 2026-09-27: a voice on
/// the right channel alone came out silent without the mix.
enum AudioImport {
    struct Converted: Sendable {
        /// The converted file, in the scratch folder until the caller moves it in.
        let url: URL
        let duration: TimeInterval
        /// When the recording was made, from the file's own metadata. An m4a from
        /// most recorders carries it; an mp3 rarely does.
        let createdAt: Date?
    }

    enum Failure: Error {
        case unreadable
        case empty
    }

    /// Frames read from the source at a time. The conversion streams from disk
    /// to disk, so an hour never sits in memory: measured on the Mac, an hour of
    /// mp3 took 2,6 seconds and 17 MB.
    private static let chunk: AVAudioFrameCount = 65_536

    /// Converts the file the user picked into the scratch folder.
    ///
    /// The URL comes from the file picker and is security-scoped. The read is
    /// coordinated, which is what makes a file provider hand over a file it
    /// holds only in the cloud: iCloud Drive downloads it first.
    @concurrent
    static func convert(_ source: URL) async throws -> Converted {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let target = AudioStorage.scratchDirectory
            .appendingPathComponent(UUID().uuidString + AudioStorage.pendingSuffix)
        var result: Result<TimeInterval, Error> = .failure(Failure.unreadable)
        var coordination: NSError?
        NSFileCoordinator().coordinate(readingItemAt: source, options: .withoutChanges, error: &coordination) { url in
            result = Result { try convert(url, to: target) }
        }
        do {
            if let coordination { throw coordination }
            let duration = try result.get()
            return Converted(url: target, duration: duration, createdAt: await creationDate(of: source))
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
    }

    /// Reads the source a chunk at a time and writes it resampled and mixed down.
    /// The length is counted from the frames written: `AVAudioFile.length` lags
    /// behind the writes until the file is closed.
    private static func convert(_ source: URL, to target: URL) throws -> TimeInterval {
        guard let input = try? AVAudioFile(forReading: source) else { throw Failure.unreadable }
        guard input.length > 0 else { throw Failure.empty }

        let output = try AVAudioFile(forWriting: target, settings: AudioRecorder.fileSettings)
        defer { output.close() }
        AudioStorage.protectWhileRecording(target)

        let ratio = output.processingFormat.sampleRate / input.processingFormat.sampleRate
        guard let converter = AVAudioConverter(from: input.processingFormat, to: output.processingFormat),
              let inBuffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: chunk),
              let outBuffer = AVAudioPCMBuffer(
                pcmFormat: output.processingFormat,
                frameCapacity: AVAudioFrameCount(Double(chunk) * ratio) + 1_024
              )
        else { throw Failure.unreadable }
        converter.downmix = true

        var written: AVAudioFramePosition = 0
        var readError: Error?
        var exhausted = false
        while true {
            outBuffer.frameLength = 0
            var conversionError: NSError?
            let status = converter.convert(to: outBuffer, error: &conversionError) { _, inputStatus in
                if !exhausted {
                    do {
                        try input.read(into: inBuffer, frameCount: chunk)
                    } catch let error as NSError where error.code == Int(kAudioFileEndOfFileError) {
                        // The end, as the file reports it. Reading at the last frame
                        // throws rather than returning nothing.
                        inBuffer.frameLength = 0
                    } catch {
                        readError = error
                        inBuffer.frameLength = 0
                    }
                    exhausted = inBuffer.frameLength == 0
                }
                inputStatus.pointee = exhausted ? .endOfStream : .haveData
                return exhausted ? nil : inBuffer
            }
            if let readError { throw readError }
            if let conversionError { throw conversionError }
            if outBuffer.frameLength > 0 {
                try output.write(from: outBuffer)
                written += AVAudioFramePosition(outBuffer.frameLength)
            }
            if status == .endOfStream || status == .error { break }
        }

        guard written > 0 else { throw Failure.empty }
        return Double(written) / AudioRecorder.sampleRate
    }

    private static func creationDate(of url: URL) async -> Date? {
        guard let item = try? await AVURLAsset(url: url).load(.creationDate) else { return nil }
        return try? await item.load(.dateValue)
    }
}
