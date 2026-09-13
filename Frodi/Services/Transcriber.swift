import AVFoundation
import Foundation
import Speech

/// The gateway to speech to text. Everything that turns audio into text goes
/// through this, so the engine can be swapped without the rest of the app noticing.
///
/// Bound to the main actor because WhisperKit is not `Sendable` and therefore
/// cannot cross an actor boundary. The engines do the actual work on their own threads.
@MainActor
protocol Transcriber {
    /// Turns the audio from `start` to the end into paragraphs, a piece at a time.
    ///
    /// After each piece the paragraphs found in it and the position reached are
    /// handed to `piece`. Returning false stops the transcription there; what has
    /// been handed over is kept, and a later call from that position goes on.
    func transcribe(
        fileURL: URL,
        from start: TimeInterval,
        piece: ([TranscriptParagraph], TimeInterval) async -> Bool
    ) async throws
}

enum TranscriptionError: LocalizedError {
    case localeUnsupported
    case modelMissing
    case empty
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .localeUnsupported:
            String(localized: "iOS har ingen norsk språkmodell for tale til tekst på denne enheten.")
        case .modelMissing:
            String(localized: "Språkmodellen er ikke lastet ned ennå.")
        case .empty:
            String(localized: "Fant ingen tale i opptaket.")
        case .underlying(let message):
            message
        }
    }

    /// Stored on the recording so the list and the detail view can state the real cause.
    var code: String {
        switch self {
        case .localeUnsupported: "localeUnsupported"
        case .modelMissing: "modelMissing"
        case .empty: "empty"
        case .underlying: "other"
        }
    }

    /// Short text for the list row.
    static func shortText(for code: String?) -> String {
        switch code {
        case "localeUnsupported": String(localized: "norsk mangler i iOS")
        case "modelMissing": String(localized: "språkmodell mangler")
        case "empty": String(localized: "ingen tale")
        case "other": String(localized: "noe gikk galt")
        default: String(localized: "ingen tekst")
        }
    }

    /// Longer explanation for the detail screen.
    static func explanation(for code: String?) -> String {
        switch code {
        case "localeUnsupported":
            String(localized: "iOS har ingen norsk språkmodell for tale til tekst på denne enheten, så opptaket kan ikke gjøres om til tekst ennå.")
        case "modelMissing":
            String(localized: "Språkmodellen er ikke lastet ned. Last den ned i listen over opptak, så prøver Fróði på nytt.")
        case "empty":
            String(localized: "Fant ingen tale i dette opptaket.")
        case "other":
            String(localized: "Fróði fikk ikke laget teksten denne gangen.")
        default:
            String(localized: "Venter på teksten.")
        }
    }
}

/// Apple's SpeechAnalyzer, introduced in iOS 26.
///
/// The whole analysis happens on the device, with no server fallback. The audio
/// never leaves the device, and the framework needs no speech-recognition
/// authorization for file analysis. That is why the app is spared Apple's dialog
/// saying speech data is sent to them; it belonged to the old SFSpeechRecognizer.
///
/// The language model is owned by the system, not the app. It does not count
/// toward the app size and lives outside the app's memory.
struct SystemTranscriber: Transcriber {
    let locale: Locale

    /// One piece for the whole file. The system engine streams the audio itself
    /// and has no memory ceiling to work around, so there is nothing to resume.
    func transcribe(
        fileURL: URL,
        from start: TimeInterval,
        piece: ([TranscriptParagraph], TimeInterval) async -> Bool
    ) async throws {
        let text = try await transcribe(fileURL: fileURL)
        let file = try AVAudioFile(forReading: fileURL)
        let duration = Double(file.length) / file.fileFormat.sampleRate
        _ = await piece([TranscriptParagraph(start: 0, end: duration, text: text)], duration)
    }

    private func transcribe(fileURL: URL) async throws -> String {
        guard let resolved = await SpeechEngine.resolve() else {
            throw TranscriptionError.localeUnsupported
        }

        let module = resolved.engine.module(locale: resolved.locale)

        guard await AssetInventory.status(forModules: [module]) == .installed else {
            throw TranscriptionError.modelMissing
        }

        do {
            let file = try AVAudioFile(forReading: fileURL)
            let analyzer = SpeechAnalyzer(modules: [module])

            // The reader must be started before the analysis, or the first results are
            // lost. The two modules have different result types, hence two branches.
            async let collected: String = {
                switch module {
                case let transcriber as SpeechTranscriber:
                    return try await transcriber.results
                        .reduce(into: "") { $0 += String($1.text.characters) }
                case let dictation as DictationTranscriber:
                    return try await dictation.results
                        .reduce(into: "") { $0 += String($1.text.characters) }
                default:
                    return ""
                }
            }()

            if let last = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }

            let whitespace = CharacterSet.whitespacesAndNewlines
            let text = try await collected.trimmingCharacters(in: whitespace)
            guard !text.isEmpty else { throw TranscriptionError.empty }
            return text
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.underlying(error.localizedDescription)
        }
    }
}
