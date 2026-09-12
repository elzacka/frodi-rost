import Foundation
import Testing
@testable import Frodi

@Suite("Språk")
struct LocaleTests {
    @Test("Appen bruker norsk bokmål")
    func usesNorwegianBokmal() {
        #expect(AppLocale.norwegian.identifier(.bcp47) == "nb-NO")
        #expect(AppLocale.isBokmal(AppLocale.norwegian))
    }

    /// The language must not follow the device setting. Set to English, Fróði must
    /// still produce Norwegian text.
    @Test("Språket følger ikke enhetens innstilling")
    func doesNotFollowSystemLocale() {
        #expect(AppLocale.norwegian != Locale.current || Locale.current.identifier(.bcp47) == "nb-NO")
        #expect(AppLocale.norwegian.identifier(.bcp47) == "nb-NO")
    }

    @Test("Nynorsk og nabospråk godtas ikke", arguments: [
        "nn-NO", "sv-SE", "da-DK", "en-US", "is-IS", "fi-FI"
    ])
    func rejectsOtherLanguages(identifier: String) {
        #expect(AppLocale.isBokmal(Locale(identifier: identifier)) == false)
    }

    @Test("Bokmål godtas i begge skrivemåter", arguments: ["nb-NO", "nb", "no-NO", "no"])
    func acceptsBokmalVariants(identifier: String) {
        #expect(AppLocale.isBokmal(Locale(identifier: identifier)))
    }
}

@Suite("Valg av språkmodell")
struct SpeechEngineTests {
    /// This is the real list from an iPhone 17 Pro on iOS 26.6.1, shortened.
    private let dictationLocales = ["ar-SA", "da-DK", "de-DE", "en-US", "fi-FI",
                                    "nb-NO", "nl-NL", "sv-SE", "zh-TW"]
        .map(Locale.init(identifier:))

    private let transcriberLocales = ["de-DE", "en-US", "es-ES", "fr-FR",
                                      "it-IT", "ja-JP", "ko-KR", "zh-TW"]
        .map(Locale.init(identifier:))

    @Test("Finner nb-NO i diktatlisten")
    func findsBokmalInDictationList() {
        let match = SpeechEngine.bokmal(in: dictationLocales)
        #expect(match?.identifier(.bcp47) == "nb-NO")
    }

    @Test("Finner ingenting i transkriberingslisten")
    func findsNothingInTranscriberList() {
        #expect(SpeechEngine.bokmal(in: transcriberLocales) == nil)
    }

    /// Swedish and Danish are similar but not Norwegian. Pick wrong here and the
    /// user gets text in the neighbouring language without being told.
    @Test("Plukker ikke svensk eller dansk")
    func doesNotPickNeighbourLanguages() {
        let nordicOnly = ["da-DK", "sv-SE", "fi-FI"].map(Locale.init(identifier:))
        #expect(SpeechEngine.bokmal(in: nordicOnly) == nil)
    }

    @Test("Foretrekker nb-NO framfor bart nb")
    func prefersFullIdentifier() {
        let both = ["nb", "nb-NO"].map(Locale.init(identifier:))
        #expect(SpeechEngine.bokmal(in: both)?.identifier(.bcp47) == "nb-NO")
    }

    @Test("Tar bart nb hvis nb-NO ikke finnes")
    func fallsBackToBareBokmal() {
        #expect(SpeechEngine.bokmal(in: [Locale(identifier: "nb")]) != nil)
    }

    @Test("Tom liste gir ingen match")
    func emptyListYieldsNothing() {
        #expect(SpeechEngine.bokmal(in: []) == nil)
    }
}
