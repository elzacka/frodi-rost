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

        do {
            let results = try await whisper.transcribe(
                audioPath: fileURL.path,
                decodeOptions: Self.options(chunked: true)
            )

            // Lydsamplene hentes bare hvis et stykke faktisk kom tomt tilbake.
            // De koster minne, og på et vanlig opptak trengs de aldri.
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

    /// Prøver et stykke på nytt ved å dele det i to.
    ///
    /// Modellen svarer av og til med bare sluttmerket på et vindu som er fullt
    /// av tale. Da kommer stykket tomt tilbake, og teksten fikk før et hull
    /// ingen kunne se – opptaket var like langt, men det siste som ble sagt var
    /// borte. Ingen innstilling på dekoderen retter det: målt 10. september 2026
    /// ga både høyere temperatur, `usePrefillPrompt: false` og `suppressBlank`
    /// nøyaktig samme tomme svar på de samme 15 sekundene.
    ///
    /// To halvdeler er noe annet enn ett helt vindu, og det er nok: den samme
    /// lyden ga full tekst da den ble delt. Vi deler videre så lenge en halvdel
    /// fortsatt er stum og lang nok til at det kan være tale i den.
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

    /// Kortere enn dette deler vi ikke opp. Et stykke som er stumt og kort er
    /// stillhet, ikke tale vi har mistet.
    private static let shortestRetry: Double = 4

    /// Leser lydfilen som samples, unna hovedtråden.
    ///
    /// `@concurrent` av samme grunn som i `AudioStorage`: en `nonisolated async`
    /// funksjon arver aktøren til den som kaller, og her er det hovedaktøren.
    /// En time med lyd er rundt 57 MB som `Float`, og det arbeidet hører ikke
    /// hjemme på hovedtråden.
    @concurrent
    private nonisolated static func samples(at path: String) async throws -> [Float] {
        try AudioProcessor.loadAudioAsFloatArray(fromPath: path)
    }

    private static func options(chunked: Bool) -> DecodingOptions {
        DecodingOptions(
            // Bokmål, alltid. Aldri utledet fra lyden eller fra enheten.
            language: "no",
            temperature: 0,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            // Uten denne blir bare det første halvminuttet med.
            //
            // Whisper hører 30 sekunder om gangen. Uten oppdeling kjører
            // WhisperKit alle vinduene gjennom den samme dekoderen, og fra og
            // med vindu nummer to kommer det ingen ting ut. Målt 9. september
            // 2026 på et opptak på 3 minutter og 3 sekunder: 86 av 516 ord.
            // Med .vad blir hvert stykke sin egen kjøring, og da kom 512 ord.
            //
            // Oppdelingen leter etter en pause å klippe på. Finner den ingen –
            // motorstøy i bil, for eksempel – klipper den på 30 sekunder i
            // stedet. Det er nettopp det som gjør at teksten blir komplett, så
            // et opptak uten pauser i taper ingen ting på det.
            //
            // Et stykke som prøves på nytt er alt delt opp, og skal ikke deles
            // en gang til.
            chunkingStrategy: chunked ? .vad : nil
        )
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
