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

    /// Språket skal ikke følge telefonens innstilling. Står den på engelsk,
    /// skal Fróði fortsatt lage norsk tekst.
    @Test("Språket følger ikke telefonens innstilling")
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
    /// Dette er den ekte listen fra en iPhone 17 Pro på iOS 26.6.1, forkortet.
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

    /// Svensk og dansk ligner, men er ikke norsk. Velger vi feil her, får
    /// brukeren tekst på nabospråket uten å bli fortalt det.
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
