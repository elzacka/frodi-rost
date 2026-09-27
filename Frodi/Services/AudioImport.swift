import AVFoundation
import CryptoKit
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
        /// The file as it was picked, for the recording's origin.
        let original: RecordingOrigin.OriginalFile
    }

    enum Failure: Error {
        case unreadable
        case empty
    }

    /// Frames read from the source at a time. The conversion streams from disk
    /// to disk, so an hour never sits in memory: measured on the Mac, an hour of
    /// mp3 took 2,6 seconds and 17 MB.
    private static let chunk: AVAudioFrameCount = 65_536

    /// Converts the file the user picked into the scratch folder, and reads what
    /// it was before the conversion: its name, size, checksum, format and
    /// metadata.
    ///
    /// The URL comes from the file picker and is security-scoped. The read is
    /// coordinated, which is what makes a file provider hand over a file it
    /// holds only in the cloud: iCloud Drive downloads it first. Nothing is
    /// written to the original.
    @concurrent
    static func convert(_ source: URL) async throws -> Converted {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let target = AudioStorage.scratchDirectory
            .appendingPathComponent(UUID().uuidString + AudioStorage.pendingSuffix)
        var result: Result<(duration: TimeInterval, file: FileFacts), Error> = .failure(Failure.unreadable)
        var coordination: NSError?
        NSFileCoordinator().coordinate(readingItemAt: source, options: .withoutChanges, error: &coordination) { url in
            result = Result {
                let facts = try FileFacts(of: url)
                return (try convert(url, to: target), facts)
            }
        }
        do {
            if let coordination { throw coordination }
            let (duration, facts) = try result.get()
            let stated = await metadata(of: source)
            let original = RecordingOrigin.OriginalFile(
                name: source.lastPathComponent,
                byteCount: facts.byteCount,
                sha256: facts.sha256,
                format: facts.format,
                sampleRate: facts.sampleRate,
                channels: facts.channels,
                createdAt: stated.createdAt,
                tags: stated.tags
            )
            return Converted(url: target, duration: duration, original: original)
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
    }

    /// What the bytes of the original say, read before the conversion.
    private struct FileFacts {
        let byteCount: Int
        let sha256: String
        let format: String
        let sampleRate: Double
        let channels: Int

        init(of url: URL) throws {
            guard let file = try? AVAudioFile(forReading: url) else { throw Failure.unreadable }
            let description = file.fileFormat.streamDescription.pointee
            format = AudioImport.name(of: description.mFormatID)
            sampleRate = description.mSampleRate
            channels = Int(description.mChannelsPerFrame)

            // A megabyte at a time, so an hour of audio is never whole in memory.
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hasher = SHA256()
            var count = 0
            while let block = try handle.read(upToCount: 1 << 20), !block.isEmpty {
                hasher.update(data: block)
                count += block.count
            }
            byteCount = count
            sha256 = hasher.finalize().hex
        }
    }

    /// The date to file an import under, if the file's own is believable: from
    /// 2000 up to a day ahead of now, for a clock in another time zone. Some
    /// recorders write zero, which reads as 1904 or 1970. The origin keeps the
    /// date the file stated either way.
    static func plausibleDate(_ date: Date?, now: Date) -> Date? {
        guard let date, date >= earliest, date <= now.addingTimeInterval(24 * 60 * 60) else { return nil }
        return date
    }

    private static let earliest = Date(timeIntervalSince1970: 946_684_800)

    /// The codec as a reader knows it.
    private static func name(of format: AudioFormatID) -> String {
        switch format {
        case kAudioFormatMPEGLayer3: "MP3"
        case kAudioFormatMPEG4AAC, kAudioFormatMPEG4AAC_HE, kAudioFormatMPEG4AAC_HE_V2: "AAC"
        case kAudioFormatLinearPCM: "PCM"
        case kAudioFormatAppleLossless: "ALAC"
        case kAudioFormatFLAC: "FLAC"
        case kAudioFormatOpus: "Opus"
        default:
            // The four characters Core Audio uses, such as «ulaw».
            String(bytes: withUnsafeBytes(of: format.bigEndian) { Array($0) }, encoding: .ascii)?
                .trimmingCharacters(in: .whitespaces) ?? "\(format)"
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

    /// The creation date and the common metadata, as the file states them. An
    /// m4a from most recorders carries a date; an mp3 rarely does. Artwork and
    /// other binary values are left out, and so is the date among the tags,
    /// since it has a field of its own.
    private static func metadata(of url: URL) async -> (createdAt: Date?, tags: [String: String]) {
        let asset = AVURLAsset(url: url)
        var createdAt: Date?
        if let item = try? await asset.load(.creationDate) {
            createdAt = try? await item.load(.dateValue)
        }
        var tags: [String: String] = [:]
        for item in (try? await asset.load(.commonMetadata)) ?? [] {
            guard let key = item.commonKey, key != .commonKeyCreationDate, key != .commonKeyArtwork,
                  let value = try? await item.load(.stringValue), !value.isEmpty
            else { continue }
            tags[key.rawValue] = value
        }
        return (createdAt, tags)
    }
}
