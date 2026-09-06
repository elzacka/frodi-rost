import Foundation
import Observation
import Speech

/// Holder styr på språkmodellen for tale til tekst.
///
/// Modellen eies av systemet og lastes ned én gang. Det er den eneste gangen
/// noe her trenger nett, og det er systemet som henter den — ikke appen.
/// Opptakene dine sendes aldri noe sted.
@MainActor
@Observable
final class SpeechModel {
    enum State: Equatable {
        case unknown
        /// iOS har ingen modell for dette språket på denne enheten.
        case unsupported
        /// Støttet, men ikke lastet ned.
        case needsDownload
        case downloading
        case ready
        case failed(String)
    }

    private(set) var state: State = .unknown

    let locale = Locale(identifier: "nb-NO")

    var isReady: Bool { state == .ready }

    /// Sjekker hva systemet har. Trygg å kalle flere ganger.
    func refresh() async {
        guard let transcriber = await makeTranscriber() else {
            state = .unsupported
            return
        }

        switch await AssetInventory.status(forModules: [transcriber]) {
        case .installed: state = .ready
        case .downloading: state = .downloading
        case .supported: state = .needsDownload
        case .unsupported: state = .unsupported
        @unknown default: state = .unsupported
        }
    }

    /// Laster ned språkmodellen. Krever nett, men bare denne ene gangen.
    func download() async {
        guard let transcriber = await makeTranscriber() else {
            state = .unsupported
            return
        }

        state = .downloading
        do {
            // Reservasjon holder modellen installert. Uten den kan systemet
            // frigi den igjen når det trenger plass, og appen står uten tekst.
            if let normalized = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
                _ = try? await AssetInventory.reserve(locale: normalized)
            }

            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
            await refresh()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func makeTranscriber() async -> SpeechTranscriber? {
        guard let normalized = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            return nil
        }
        return SpeechTranscriber(locale: normalized, preset: .transcription)
    }

    /// Til feilsøking på enhet: hva støtter de to modulene i rammeverket?
    ///
    /// SpeechTranscriber er den lange transkriberingsmodellen. DictationTranscriber
    /// er diktatmodellen, som følger språkene i tastaturdiktat og derfor kan ha
    /// andre språk. Begge kjører på enheten.
    func diagnostics() async -> (transcriber: [String], dictation: [String]) {
        let transcriber = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }.sorted()
        let dictation = await DictationTranscriber.supportedLocales.map { $0.identifier(.bcp47) }.sorted()
        return (transcriber, dictation)
    }
}
