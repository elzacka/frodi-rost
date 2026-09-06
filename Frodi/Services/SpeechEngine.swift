import Foundation
import Speech

/// Hvilken av modulene i Speech-rammeverket som brukes for et språk.
///
/// SpeechTranscriber er den lange transkriberingsmodellen, men den dekker bare
/// åtte språk og ingen nordiske. DictationTranscriber følger språkene i
/// tastaturdiktat, og der finnes norsk. Begge kjører på enheten, uten
/// serverfallback, så personvernet er det samme.
enum SpeechEngine: Equatable {
    case transcription
    case dictation

    /// Finner den beste modulen for språket. Foretrekker transkribering, som er
    /// laget for lange opptak, og faller tilbake til diktat der språket mangler.
    static func resolve(for locale: Locale) async -> (engine: SpeechEngine, locale: Locale)? {
        if let match = await SpeechTranscriber.supportedLocale(equivalentTo: locale),
           AppLocale.isBokmal(match) {
            return (.transcription, match)
        }
        // Diktatmodulen dekker flere språk, og der finnes norsk bokmål.
        if let match = await DictationTranscriber.supportedLocale(equivalentTo: locale),
           AppLocale.isBokmal(match) {
            return (.dictation, match)
        }
        // Ingen match vi vil ha. Vi tar heller ingen tekst enn tekst på feil
        // språk — nynorsk eller et nabospråk ville vært verre enn ingenting.
        return nil
    }

    /// Bygger modulen. `longDictation` er valgt for diktat fordi et opptak her
    /// er flere setninger, ikke en kort kommando.
    func module(locale: Locale) -> any SpeechModule {
        switch self {
        case .transcription:
            SpeechTranscriber(locale: locale, preset: .transcription)
        case .dictation:
            DictationTranscriber(locale: locale, preset: .longDictation)
        }
    }
}
