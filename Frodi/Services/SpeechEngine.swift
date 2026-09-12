import Foundation
import Speech

/// Which of the modules in the Speech framework is used.
///
/// SpeechTranscriber is the long-form transcription model, but it covers only
/// eight languages and no Nordic ones. DictationTranscriber follows the languages
/// of keyboard dictation, and Norwegian Bokmål is there. Both run on the device
/// with no server fallback, so the privacy position is the same.
enum SpeechEngine: Equatable {
    case transcription
    case dictation

    var name: String {
        switch self {
        case .transcription: "transkribering"
        case .dictation: "diktat"
        }
    }

    /// Finds the best module for Bokmål.
    ///
    /// We scan `supportedLocales` ourselves instead of using
    /// `supportedLocale(equivalentTo:)`. Apple itself warns that equality between
    /// Locale objects depends on how they were made, and the helper returned nil for
    /// nb-NO on a device even though nb-NO was in the list. Picking the object
    /// straight out of the framework's own list sidesteps the whole problem.
    static func resolve() async -> (engine: SpeechEngine, locale: Locale)? {
        if let match = bokmal(in: await SpeechTranscriber.supportedLocales) {
            return (.transcription, match)
        }
        if let match = bokmal(in: await DictationTranscriber.supportedLocales) {
            return (.dictation, match)
        }
        // No match we want. We would rather have no text than text in the wrong
        // language: Nynorsk or a neighbouring language would be worse than nothing.
        return nil
    }

    /// Picks Bokmål out of a list. Prefers nb-NO, accepts nb and no.
    /// Internal rather than private because it is tested; this is where the bug was.
    static func bokmal(in locales: [Locale]) -> Locale? {
        let bokmalOnly = locales.filter(AppLocale.isBokmal)
        return bokmalOnly.first { $0.identifier(.bcp47).lowercased() == "nb-no" }
            ?? bokmalOnly.first
    }

    /// Builds the module. `longDictation` is chosen for dictation because a recording
    /// here is several sentences, not a short command.
    func module(locale: Locale) -> any SpeechModule {
        switch self {
        case .transcription:
            SpeechTranscriber(locale: locale, preset: .transcription)
        case .dictation:
            DictationTranscriber(locale: locale, preset: .longDictation)
        }
    }
}
