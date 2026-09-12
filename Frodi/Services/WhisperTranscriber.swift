import Foundation
import WhisperKit

/// WhisperKit 0.18 is not annotated for Swift 6, so the compiler has to be told
/// that the type can cross an isolation boundary.
///
/// This is an assertion on our part, not something the compiler can prove. The
/// basis: WhisperKit manages its own concurrency internally, and in this app
/// every call arrives from the main actor via `Transcription`, one recording at
/// a time. Remove this line as soon as WhisperKit annotates its own type.
extension WhisperKit: @retroactive @unchecked Sendable {}

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

    /// Loads the model if it is not already loaded.
    ///
    /// It deliberately returns nothing: `WhisperKit` is not `Sendable`, and handing
    /// it out of an isolated method is exactly what Swift 6 stops. So it stays
    /// here, and all the work happens in this class.
    private func load() async throws {
        guard whisper == nil else { return }

        guard let model = Self.modelFolder, let tokenizer = Self.tokenizerFolder else {
            throw TranscriptionError.modelMissing
        }

        let config = WhisperKitConfig(
            modelFolder: model.path,
            tokenizerFolder: tokenizer,
            // No download, no outgoing request. If something is missing, it must fail.
            download: false
        )
        whisper = try await WhisperKit(config)
    }

    func transcribe(fileURL: URL) async throws -> String {
        try await load()
        guard let whisper else { throw TranscriptionError.modelMissing }

        do {
            let results = try await whisper.transcribe(
                audioPath: fileURL.path,
                decodeOptions: Self.options(chunked: true)
            )

            // The audio samples are fetched only if a piece actually came back empty.
            // They cost memory, and on an ordinary recording they are never needed.
            var audio: [Float]?
            var pieces: [String] = []

            for result in results {
                let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

                guard text.isEmpty,
                      let start = result.segments.first?.start,
                      let end = result.segments.last?.end,
                      Double(end - start) >= Self.shortestRetry
                else {
                    pieces.append(text)
                    continue
                }

                if audio == nil { audio = try? await Self.samples(at: fileURL.path) }
                guard let audio else { continue }
                pieces.append(await retry(in: audio, from: Double(start), to: Double(end)))
            }

            let text = pieces
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { throw TranscriptionError.empty }
            return text
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.underlying(error.localizedDescription)
        }
    }

    /// Retries a piece by splitting it in two.
    ///
    /// The model sometimes answers a window full of speech with only the end marker.
    /// The piece then comes back empty, and the text used to get a hole nobody could
    /// see: the recording was as long as before, but the last thing said was gone.
    /// No decoder setting fixes it: measured on 10 September 2026, higher
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
                decodeOptions: Self.options(chunked: false)
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

    /// Reads the audio file as samples, off the main thread.
    ///
    /// `@concurrent` for the same reason as in `AudioStorage`: a `nonisolated async`
    /// function inherits the caller's actor, and here that is the main actor. An
    /// hour of audio is about 57 MB as `Float`, and that work does not belong on
    /// the main thread.
    @concurrent
    private nonisolated static func samples(at path: String) async throws -> [Float] {
        try AudioProcessor.loadAudioAsFloatArray(fromPath: path)
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
            // out. Measured 9 September 2026 on a recording of 3 minutes 3 seconds: 86 of
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
        modelFolder != nil && tokenizerFolder != nil
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
