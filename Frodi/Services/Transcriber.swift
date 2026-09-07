import AVFoundation
import Foundation
import Speech

/// Porten mot tale til tekst. Alt som gjør om lyd til tekst går gjennom denne,
/// slik at motoren kan byttes uten at resten av appen merker det.
///
/// Bundet til hovedaktøren fordi WhisperKit ikke er `Sendable` og derfor ikke
/// kan krysse en aktørgrense. Selve arbeidet gjør motorene på egne tråder.
@MainActor
protocol Transcriber {
    func transcribe(fileURL: URL) async throws -> String
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

    /// Lagres på opptaket slik at listen og detaljene kan si den ekte årsaken.
    var code: String {
        switch self {
        case .localeUnsupported: "localeUnsupported"
        case .modelMissing: "modelMissing"
        case .empty: "empty"
        case .underlying: "other"
        }
    }

    /// Kort tekst til listeraden.
    static func shortText(for code: String?) -> String {
        switch code {
        case "localeUnsupported": String(localized: "norsk mangler i iOS")
        case "modelMissing": String(localized: "språkmodell mangler")
        case "empty": String(localized: "ingen tale")
        case "other": String(localized: "teksten feilet")
        default: String(localized: "ingen tekst")
        }
    }

    /// Lengre forklaring til detaljskjermen.
    static func explanation(for code: String?) -> String {
        switch code {
        case "localeUnsupported":
            String(localized: "iOS har ingen norsk språkmodell for tale til tekst på denne enheten, så opptaket kan ikke gjøres om til tekst ennå.")
        case "modelMissing":
            String(localized: "Språkmodellen er ikke lastet ned. Last den ned på forsiden, så prøver Fróði på nytt.")
        case "empty":
            String(localized: "Fant ingen tale i dette opptaket.")
        case "other":
            String(localized: "Teksten kunne ikke lages denne gangen.")
        default:
            String(localized: "Venter på transkribering.")
        }
    }
}

/// Apples SpeechAnalyzer, innført i iOS 26.
///
/// Hele analysen skjer på enheten, uten serverfallback. Lyden forlater aldri
/// telefonen, og rammeverket krever ingen tillatelse til talegjenkjenning for
/// filanalyse. Det er derfor appen slipper Apples dialog om at taledata sendes
/// til dem — den hørte til det gamle SFSpeechRecognizer.
///
/// Språkmodellen eies av systemet, ikke av appen. Den teller ikke mot
/// appstørrelsen og ligger utenfor appens minne.
struct SystemTranscriber: Transcriber {
    let locale: Locale

    func transcribe(fileURL: URL) async throws -> String {
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

            // Leseren må startes før analysen, ellers går de første resultatene
            // tapt. De to modulene har hver sin resultattype, derfor to grener.
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
