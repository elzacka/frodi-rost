import Foundation
import WhisperKit

/// WhisperKit 0.18 er ikke merket for Swift 6, så kompilatoren må få vite at
/// typen kan krysse en isolasjonsgrense.
///
/// Dette er en påstand fra oss, ikke noe kompilatoren kan bevise. Grunnlaget:
/// WhisperKit styrer sin egen samtidighet internt, og i denne appen kommer alle
/// kall fra hovedaktøren via `Transcription`, ett opptak om gangen. Fjern denne
/// linjen så snart WhisperKit annoterer typen sin selv.
extension WhisperKit: @retroactive @unchecked Sendable {}

/// nb-whisper fra Nasjonalbiblioteket, kjørt inne i appen.
///
/// Forskjellen fra Apples motor er ikke om lyden forlater enheten – det gjør
/// den ikke i noen av tilfellene – men hvor den behandles. Apples modell kjører
/// i en systemprosess utenfor appens container. Denne kjører inne i den.
///
/// Modellen og tokenizeren ligger i app-pakken. `WhisperKit` ville ellers hentet
/// dem fra Hugging Face ved første kjøring, og da hadde appen hatt nettverk.
/// Begge stiene oppgis derfor eksplisitt.
/// Låst til hovedaktøren fordi `WhisperKit` ikke er `Sendable`. Den kan derfor
/// ikke krysse en aktørgrense uten at Swift 6 flagger det. Selve arbeidet gjør
/// WhisperKit på egne tråder, så dette blokkerer ikke grensesnittet.
@MainActor
final class WhisperTranscriber: Transcriber {
    private var whisper: WhisperKit?

    /// Laster modellen hvis den ikke alt er lastet.
    ///
    /// Den returnerer ingenting med vilje: `WhisperKit` er ikke `Sendable`, og
    /// å gi den ut av en isolert metode er nettopp det Swift 6 stopper. Den blir
    /// derfor liggende her, og alt arbeid skjer i denne klassen.
    private func load() async throws {
        guard whisper == nil else { return }

        guard let model = Self.modelFolder, let tokenizer = Self.tokenizerFolder else {
            throw TranscriptionError.modelMissing
        }

        let config = WhisperKitConfig(
            modelFolder: model.path,
            tokenizerFolder: tokenizer,
            // Ingen nedlasting, ingen forespørsel ut. Mangler noe, skal det feile.
            download: false
        )
        whisper = try await WhisperKit(config)
    }

    func transcribe(fileURL: URL) async throws -> String {
        try await load()
        guard let whisper else { throw TranscriptionError.modelMissing }

        let options = DecodingOptions(
            // Bokmål, alltid. Aldri utledet fra lyden eller fra enheten.
            language: "no",
            temperature: 0,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )

        do {
            let results = try await whisper.transcribe(audioPath: fileURL.path, decodeOptions: options)
            let text = results
                .map(\.text)
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

    /// Er modellen faktisk med i denne bygget?
    nonisolated static var isBundled: Bool {
        modelFolder != nil && tokenizerFolder != nil
    }

    /// Modellen ligger i en mappereferanse, ikke flatt i pakken, så
    /// underkatalogen må oppgis.
    nonisolated static var modelFolder: URL? {
        Bundle.main.url(forResource: "nb-whisper-small", withExtension: nil, subdirectory: "Model")
    }

    nonisolated static var tokenizerFolder: URL? {
        Bundle.main.url(forResource: "tokenizer", withExtension: nil, subdirectory: "Model")
    }
}
