import Foundation
import Observation
import Speech

/// Fróði transkriberer norsk bokmål og ingenting annet.
///
/// Språket er bevisst hardkodet, ikke hentet fra `Locale.current`. Står
/// enheten på engelsk, skal appen fortsatt lage norsk bokmål.
///
/// `nb` er bokmål. `nn` er nynorsk og skal aldri brukes her.
enum AppLocale {
    static let norwegian = Locale(identifier: "nb-NO")

    /// Er dette bokmål? `nb` og det eldre `no` godtas, `nn` aldri.
    static func isBokmal(_ locale: Locale) -> Bool {
        guard let code = locale.language.languageCode?.identifier.lowercased() else { return false }
        return code == "nb" || code == "no"
    }
}

/// Holder styr på språkmodellen for tale til tekst.
///
/// Modellen eies av systemet og lastes ned én gang. Det er den eneste gangen
/// noe her trenger nett, og det er systemet som henter den – ikke appen.
/// Opptakene dine sendes aldri noe sted.
@MainActor
@Observable
final class SpeechModel {
    enum State: Equatable {
        case unknown
        /// iOS har ingen norsk modell i noen av modulene.
        case unsupported
        /// Støttet, men ikke lastet ned.
        case needsDownload
        case downloading
        case ready
        case failed(String)
    }

    private(set) var state: State = .unknown
    private(set) var engine: SpeechEngine?

    let locale = AppLocale.norwegian

    var isReady: Bool { state == .ready }

    /// Sjekker hva systemet har. Trygg å kalle flere ganger.
    func refresh() async {
        guard let resolved = await SpeechEngine.resolve() else {
            engine = nil
            state = .unsupported
            return
        }

        engine = resolved.engine
        let module = resolved.engine.module(locale: resolved.locale)

        switch await AssetInventory.status(forModules: [module]) {
        case .installed: state = .ready
        case .downloading: state = .downloading
        case .supported: state = .needsDownload
        case .unsupported: state = .unsupported
        @unknown default: state = .unsupported
        }
    }

    /// Laster ned den norske språkmodellen. Krever nett, men bare denne ene gangen.
    func download() async {
        guard let resolved = await SpeechEngine.resolve() else {
            engine = nil
            state = .unsupported
            return
        }

        state = .downloading
        let module = resolved.engine.module(locale: resolved.locale)

        do {
            // Reservasjon holder modellen installert. Uten den kan systemet
            // frigi den igjen når det trenger plass, og appen står uten tekst.
            _ = try? await AssetInventory.reserve(locale: resolved.locale)

            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                try await request.downloadAndInstall()
            }
            await refresh()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Til feilsøking på enhet: hva støtter de to modulene i rammeverket?
    func diagnostics() async -> (transcriber: [String], dictation: [String]) {
        let transcriber = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }.sorted()
        let dictation = await DictationTranscriber.supportedLocales.map { $0.identifier(.bcp47) }.sorted()
        return (transcriber, dictation)
    }
}
