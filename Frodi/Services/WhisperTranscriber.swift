import AVFoundation
import Foundation
import WhisperKit

/// nb-whisper from the National Library, run inside the app, not in Apple's system process outside the container.
/// Model and tokenizer are bundled, both paths explicit: otherwise `WhisperKit` fetches them from Hugging Face (network).
/// Main actor because `WhisperKit` is not `Sendable`; it works on its own threads, so the interface is not blocked.
@MainActor
final class WhisperTranscriber: Transcriber {
    private var whisper: WhisperKit?

    /// The word list as tokens, for the transcription running right now.
    private var promptTokens: [Int]?

    /// Loads the model if it is not already loaded. Returns nothing: `WhisperKit` is not `Sendable`, and Swift 6
    /// stops handing it out of an isolated method, so it stays in this class.
    private func load() async throws {
        guard whisper == nil else { return }

        guard let model = Self.modelFolder, let tokenizer = Self.tokenizerFolder, Self.tokenizerIsComplete else {
            throw TranscriptionError.modelMissing
        }

        let config = WhisperKitConfig(
            modelFolder: model.path,
            tokenizerFolder: tokenizer,
            // WhisperKit writes to the unified log as public text: time windows,
            // segment counts, timings, and at debug level the text itself. Nothing
            // about a recording belongs there, so all of it is off.
            verbose: false,
            logLevel: .none,
            // No download, no outgoing request. If something is missing, it must fail.
            // The flag covers the model only; the tokenizer is covered by the guard
            // above, see `tokenizerIsComplete`.
            download: false
        )
        whisper = try await WhisperKit(config)
    }

    /// How much audio goes through the model in one call: three minutes.
    /// Memory grows about 60 MB a minute on the simulator on top of the model; ten minutes was the longest that survived there.
    /// The piece is also the unit of progress: what is saved, and the most lost, when the app is suspended.
    nonisolated static let pieceLength: TimeInterval = 3 * 60

    /// A piece is not cut at exactly `pieceLength` but at the quietest moment in the
    /// last stretch before it, so the seam falls between words rather than inside
    /// one. This is how far back the search goes, and how long a quiet moment is.
    nonisolated static let seamSearch: TimeInterval = 15
    nonisolated static let seamWindow: TimeInterval = 0.3

    func transcribe(
        fileURL: URL,
        from start: TimeInterval,
        piece: ([TranscriptParagraph], TimeInterval) async -> Bool
    ) async throws {
        try await load()
        guard let whisper else { throw TranscriptionError.modelMissing }

        // Opened once and kept open across the pieces: one handle however long the run takes. See
        // `AudioStorage.decryptToTemporary` for the file class that lets the open succeed on a locked device.
        let file = try AudioPieces(url: fileURL)
        let duration = file.duration
        var position = start
        promptTokens = WordList.prompt(from: WordList.load()).flatMap { promptTokens(for: $0, whisper: whisper) }
        defer { promptTokens = nil }

        // The last fraction of a second is never a piece on its own.
        while position < duration - 0.1 {
            let nominalEnd = min(position + Self.pieceLength, duration)
            var audio = try await file.samples(from: position, to: nominalEnd)

            let end: TimeInterval
            if nominalEnd < duration, let cut = Self.seam(in: audio) {
                audio.removeSubrange(cut...)
                end = position + Double(cut) / Double(WhisperKit.sampleRate)
            } else {
                end = nominalEnd
            }

            let paragraphs = try await transcribePiece(audio, offset: position, whisper: whisper)
            guard await piece(paragraphs, end) else { return }
            position = end
        }
    }

    /// One call to the model, chunked by voice activity inside the piece, with the
    /// refused-window repair from `retry`. Times come back relative to the piece
    /// and are moved to the recording's own clock here.
    private func transcribePiece(
        _ audio: [Float],
        offset: TimeInterval,
        whisper: WhisperKit
    ) async throws -> [TranscriptParagraph] {
        do {
            let results = try await whisper.transcribe(
                audioArray: audio,
                decodeOptions: options(chunked: true)
            )

            var paragraphs: [TranscriptParagraph] = []
            for result in results {
                guard let first = result.segments.first?.start, let last = result.segments.last?.end else { continue }
                let start = Double(first), end = Double(last)
                var text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

                // The audio is at hand already, so a refused window costs no second read.
                if text.isEmpty, end - start >= Self.shortestRetry {
                    text = await retry(in: audio, from: start, to: end)
                }
                guard !text.isEmpty else { continue }
                paragraphs.append(TranscriptParagraph(start: offset + start, end: offset + end, text: text))
            }
            return paragraphs
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.underlying(error.localizedDescription)
        }
    }

    /// The sample index to cut a piece at: the start of the quietest `seamWindow`
    /// in the last `seamSearch` seconds. Nil when the piece is too short to search.
    nonisolated static func seam(in audio: [Float]) -> Int? {
        let rate = WhisperKit.sampleRate
        let window = Int(seamWindow * Double(rate))
        let searchStart = audio.count - Int(seamSearch * Double(rate))
        guard searchStart > window, audio.count - searchStart > window else { return nil }

        var quietest = searchStart
        var lowest = Float.greatestFiniteMagnitude
        for index in stride(from: searchStart, to: audio.count - window, by: window / 3) {
            let energy = AudioProcessor.calculateAverageEnergy(of: Array(audio[index..<index + window]))
            if energy < lowest {
                lowest = energy
                quietest = index
            }
        }
        return quietest
    }

    /// Retries an empty piece by splitting it in two; halves are a different input than one window.
    /// The model sometimes answers speech with only the end marker. No decoder setting fixes it (2026-09-10): a higher temperature,
    /// `usePrefillPrompt: false`, `suppressBlank` all failed alike. Split again while a half is silent and long enough for speech.
    private func retry(in audio: [Float], from start: Double, to end: Double) async -> String {
        guard let whisper, end - start >= Self.shortestRetry else { return "" }

        let middle = (start + end) / 2
        var pieces: [String] = []

        for (from, to) in [(start, middle), (middle, end)] {
            let first = max(Int(from * Double(WhisperKit.sampleRate)), 0)
            let last = min(Int(to * Double(WhisperKit.sampleRate)), audio.count)
            guard first < last else { continue }

            let part = Array(audio[first..<last])
            let results = try? await whisper.transcribe(
                audioArray: part,
                decodeOptions: options(chunked: false)
            )
            let text = (results ?? [])
                .map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            pieces.append(text.isEmpty ? await retry(in: audio, from: from, to: to) : text)
        }

        return pieces.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Shorter than this we do not split. A piece that is silent and short is
    /// silence, not speech we have lost.
    private static let shortestRetry: Double = 4

    nonisolated static func duration(of url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.fileFormat.sampleRate
    }

    /// The word list encoded the way WhisperKit's own command line does it: a
    /// leading space, and no special tokens. The decoder puts it after
    /// `<|startofprev|>`, as text that was just said.
    private func promptTokens(for prompt: String, whisper: WhisperKit) -> [Int]? {
        guard let tokenizer = whisper.tokenizer else { return nil }
        let tokens = tokenizer.encode(text: " " + prompt).filter { $0 < tokenizer.specialTokens.specialTokenBegin }
        return tokens.isEmpty ? nil : tokens
    }

    private func options(chunked: Bool) -> DecodingOptions {
        var options = Self.options(chunked: chunked)
        options.promptTokens = promptTokens
        return options
    }

    private static func options(chunked: Bool) -> DecodingOptions {
        DecodingOptions(
            // Bokmål, always. Never derived from the audio or from the device.
            language: "no",
            temperature: 0,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            // Without this only the first half minute comes through: without chunking every window after the first yields nothing
            // (2026-09-09, 3 min 3 s: 86 of 516 words; with .vad 512). It cuts at a pause, else at 30 s, so pause-free audio loses nothing.
            // Not for a piece being retried: it is already split.
            chunkingStrategy: chunked ? .vad : nil
        )
    }

    /// Is the model actually in this build?
    nonisolated static var isBundled: Bool {
        modelFolder != nil && tokenizerIsComplete
    }

    /// The two files WhisperKit reads a tokenizer from, on the path it expects.
    nonisolated static let tokenizerFiles = ["tokenizer.json", "tokenizer_config.json"]

    /// Whether both tokenizer files are in the bundle.
    /// `download: false` covers the model folder only; WhisperKit 1.1.0 (`ModelUtilities.loadTokenizer`) fetches an unreadable
    /// tokenizer from Hugging Face regardless. So check before creating it: a missing file reports the model missing, no network.
    nonisolated static var tokenizerIsComplete: Bool {
        guard let folder = tokenizerFolder?.appendingPathComponent("models/openai/whisper-small") else {
            return false
        }
        return tokenizerFiles.allSatisfy {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
        }
    }

    /// The model sits in a folder reference, not flat in the bundle, so the
    /// subdirectory must be given.
    nonisolated static var modelFolder: URL? {
        Bundle.main.url(forResource: "nb-whisper-small", withExtension: nil, subdirectory: "Model")
    }

    nonisolated static var tokenizerFolder: URL? {
        Bundle.main.url(forResource: "tokenizer", withExtension: nil, subdirectory: "Model")
    }
}

/// An audio file held open for a transcription, read a piece at a time.
/// `@unchecked Sendable` because `AVAudioFile` is not marked; reads must be off the main actor (3 minutes is about 11 MB as `Float`)
/// and sequential from one caller, which is what makes the assertion hold.
final class AudioPieces: @unchecked Sendable {
    private let file: AVAudioFile
    let duration: TimeInterval

    init(url: URL) throws {
        file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        duration = Double(file.length) / file.fileFormat.sampleRate
    }

    /// One piece as 16 kHz samples. `@concurrent` for the same reason as in
    /// `AudioStorage`: a `nonisolated async` function inherits the caller's actor.
    @concurrent
    func samples(from start: TimeInterval, to end: TimeInterval) async throws -> [Float] {
        let buffer = try AudioProcessor.loadAudio(fromFile: file, startTime: start, endTime: end)
        return AudioProcessor.convertBufferToArray(buffer: buffer)
    }
}
