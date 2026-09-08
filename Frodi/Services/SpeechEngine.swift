import Foundation
import Speech

/// Hvilken av modulene i Speech-rammeverket som brukes.
///
/// SpeechTranscriber er den lange transkriberingsmodellen, men den dekker bare
/// åtte språk og ingen nordiske. DictationTranscriber følger språkene i
/// tastaturdiktat, og der finnes norsk bokmål. Begge kjører på enheten, uten
/// serverfallback, så personvernet er det samme.
enum SpeechEngine: Equatable {
    case transcription
    case dictation

    var name: String {
        switch self {
        case .transcription: "transkribering"
        case .dictation: "diktat"
        }
    }

    /// Finner den beste modulen for bokmål.
    ///
    /// Vi leter gjennom `supportedLocales` selv i stedet for å bruke
    /// `supportedLocale(equivalentTo:)`. Apple advarer selv om at likhet mellom
    /// Locale-objekter avhenger av hvordan de ble laget, og hjelperen ga nil for
    /// nb-NO på enhet selv om nb-NO stod i listen. Ved å plukke objektet rett ut
    /// av rammeverkets egen liste slipper vi hele det problemet.
    static func resolve() async -> (engine: SpeechEngine, locale: Locale)? {
        if let match = bokmal(in: await SpeechTranscriber.supportedLocales) {
            return (.transcription, match)
        }
        if let match = bokmal(in: await DictationTranscriber.supportedLocales) {
            return (.dictation, match)
        }
        // Ingen match vi vil ha. Vi tar heller ingen tekst enn tekst på feil
        // språk – nynorsk eller et nabospråk ville vært verre enn ingenting.
        return nil
    }

    /// Plukker bokmål ut av en liste. Foretrekker nb-NO, godtar nb og no.
    /// Intern og ikke privat fordi den er testet – det var her feilen lå.
    static func bokmal(in locales: [Locale]) -> Locale? {
        let bokmalOnly = locales.filter(AppLocale.isBokmal)
        return bokmalOnly.first { $0.identifier(.bcp47).lowercased() == "nb-no" }
            ?? bokmalOnly.first
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
