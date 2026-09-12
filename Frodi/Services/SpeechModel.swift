import Foundation
import Observation
import Speech

/// Fróði transcribes Norwegian Bokmål and nothing else.
///
/// The language is deliberately hardcoded, not taken from `Locale.current`. If the
/// device is set to English, the app must still produce Norwegian Bokmål.
///
/// `nb` is Bokmål. `nn` is Nynorsk and must never be used here.
enum AppLocale {
    static let norwegian = Locale(identifier: "nb-NO")

    /// Is this Bokmål? `nb` and the older `no` are accepted, `nn` never.
    static func isBokmal(_ locale: Locale) -> Bool {
        guard let code = locale.language.languageCode?.identifier.lowercased() else { return false }
        return code == "nb" || code == "no"
    }
}

/// Keeps track of the speech-to-text language model.
///
/// The model is owned by the system and downloaded once. That is the only time
/// anything here needs the network, and it is the system that fetches it, not the
/// app. Your recordings are never sent anywhere.
@MainActor
@Observable
final class SpeechModel {
    enum State: Equatable {
        case unknown
        /// iOS has no Norwegian model in either module.
        case unsupported
        /// Supported, but not downloaded.
        case needsDownload
        case downloading
        case ready
        case failed(String)
    }

    private(set) var state: State = .unknown
    private(set) var engine: SpeechEngine?

    let locale = AppLocale.norwegian

    var isReady: Bool { state == .ready }

    /// Checks what the system has. Safe to call repeatedly.
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

    /// Downloads the Norwegian language model. Needs the network, but only this once.
    func download() async {
        guard let resolved = await SpeechEngine.resolve() else {
            engine = nil
            state = .unsupported
            return
        }

        state = .downloading
        let module = resolved.engine.module(locale: resolved.locale)

        do {
            // A reservation keeps the model installed. Without it the system can reclaim it
            // when it needs space, and the app is left without text.
            _ = try? await AssetInventory.reserve(locale: resolved.locale)

            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                try await request.downloadAndInstall()
            }
            await refresh()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// For debugging on a device: what do the two modules in the framework support?
    func diagnostics() async -> (transcriber: [String], dictation: [String]) {
        let transcriber = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }.sorted()
        let dictation = await DictationTranscriber.supportedLocales.map { $0.identifier(.bcp47) }.sorted()
        return (transcriber, dictation)
    }
}
