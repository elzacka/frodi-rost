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
