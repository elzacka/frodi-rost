import AVFoundation
import Foundation
import WhisperKit

/// nb-whisper from the National Library, run inside the app.
///
/// The difference from Apple's engine is not whether the audio leaves the device,
/// which it does in neither case, but where it is processed. Apple's model runs
/// in a system process outside the app's container. This one runs inside it.
///
/// The model and the tokenizer live in the app bundle. `WhisperKit` would
/// otherwise fetch them from Hugging Face on first run, and the app would have
/// had network access. Both paths are therefore given explicitly.
/// Bound to the main actor because `WhisperKit` is not `Sendable`. It therefore
/// cannot cross an actor boundary without Swift 6 flagging it. WhisperKit does
/// the actual work on its own threads, so this does not block the interface.
@MainActor
final class WhisperTranscriber: Transcriber {
    private var whisper: WhisperKit?

    /// The word list as tokens, for the transcription running right now.
    private var promptTokens: [Int]?

    /// Loads the model if it is not already loaded.
    ///
    /// It deliberately returns nothing: `WhisperKit` is not `Sendable`, and handing
    /// it out of an isolated method is exactly what Swift 6 stops. So it stays
    /// here, and all the work happens in this class.
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

    /// How much audio goes through the model in one call.
    ///
    /// Memory grows with the length of a single call, about 60 MB a minute on the
    /// simulator on top of the model itself, and a ten minute call was the longest
    /// that survived there. Three minutes keeps a call well inside that, and makes
    /// the piece the unit of progress: what is saved when the app is suspended,
    /// and what is lost at most when it is.
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

        // Opened once and kept open. The plaintext copy is `.completeUnlessOpen`: a
        // handle taken while it could be opened keeps working after the screen
        // locks, but a fresh open would fail. On the charger every piece after the
        // first would otherwise fail.
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

    /// Retries a piece by splitting it in two.
    ///
    /// The model sometimes answers a window full of speech with only the end marker.
    /// The piece then comes back empty, and the text used to get a hole nobody could
    /// see: the recording was as long as before, but the last thing said was gone.
    /// No decoder setting fixes it: measured on 2026-09-10, higher
    /// temperature, `usePrefillPrompt: false` and `suppressBlank` all gave exactly
    /// the same empty answer on the same 15 seconds.
    ///
    /// Two halves are a different input than one whole window, and that is enough:
    /// the same audio gave full text once it was split. We keep splitting as long as
    /// a half is still silent and long enough for there to be speech in it.
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
            // Without this only the first half minute comes through.
            //
            // Whisper hears 30 seconds at a time. Without chunking, WhisperKit runs every
            // window through the same decoder, and from window two onward nothing comes
            // out. Measured 2026-09-09 on a recording of 3 minutes 3 seconds: 86 of
            // 516 words. With .vad every chunk is its own run, and 512 words came out.
            //
            // The chunker looks for a pause to cut on. If it finds none, engine noise in
            // a car for instance, it cuts at 30 seconds instead. That is exactly what makes
            // the text complete, so a recording without pauses loses nothing by it.
            //
            // A piece being retried is already split, and must not be split again.
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
    ///
    /// `download: false` governs the model folder only. When the tokenizer cannot
    /// be read locally, WhisperKit falls back to fetching it from Hugging Face
    /// without consulting that flag; `ModelUtilities.loadTokenizer` in 1.1.0. So the app checks for the files itself,
    /// before WhisperKit is ever created, and a build missing one of them reports
    /// the model as missing rather than reach for the network.
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

/// An audio file held open for the length of a transcription, read a piece at a time.
///
/// `@unchecked Sendable` because `AVAudioFile` is not marked, and the reads have
/// to happen off the main actor: three minutes of audio is about 11 MB as `Float`
/// and does not belong there. The reads are sequential, one piece after the
/// other from one caller, which is what makes the assertion hold.
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
