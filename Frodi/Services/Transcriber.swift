import AVFoundation
import Foundation
import Speech

/// Porten mot tale til tekst. Alt som gjør om lyd til tekst går gjennom denne,
/// slik at nb-whisper kan erstatte Apples motor uten at resten av appen merker det.
protocol Transcriber: Sendable {
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
}

/// Apples SpeechAnalyzer, innført i iOS 26.
///
/// Hele analysen skjer på enheten. Lyden forlater aldri telefonen, og
/// rammeverket krever ingen tillatelse til talegjenkjenning for filanalyse.
/// Det er grunnen til at appen ikke lenger viser Apples dialog om at taledata
/// sendes til deres servere — den dialogen hørte til det gamle SFSpeechRecognizer.
///
/// Språkmodellen eies av systemet, ikke av appen. Den teller ikke mot
/// appstørrelsen og ligger utenfor appens minne.
struct SystemTranscriber: Transcriber {
    let locale: Locale

    func transcribe(fileURL: URL) async throws -> String {
        guard let normalized = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw TranscriptionError.localeUnsupported
        }

        let transcriber = SpeechTranscriber(locale: normalized, preset: .transcription)

        guard await AssetInventory.status(forModules: [transcriber]) == .installed else {
            throw TranscriptionError.modelMissing
        }

        do {
            let file = try AVAudioFile(forReading: fileURL)
            let analyzer = SpeechAnalyzer(modules: [transcriber])

            // Leseren må startes før analysen, ellers går de første resultatene tapt.
            async let collected = transcriber.results.reduce(into: "") { text, result in
                text += String(result.text.characters)
            }

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
