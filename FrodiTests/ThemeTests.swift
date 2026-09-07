import Testing
import UIKit
@testable import Frodi

@Suite("Designsystem")
struct ThemeTests {
    /// En font som ikke blir registrert faller stille tilbake til systemfonten.
    /// Da ser appen nesten riktig ut, og feilen oppdages aldri.
    @Test("Alle bundlede fonter lar seg laste", arguments: [
        "Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Skranji", "Skranji-Bold"
    ])
    func fontsAreRegistered(name: String) {
        #expect(UIFont(name: name, size: 12) != nil, "Fant ikke fonten \(name)")
    }

    @Test("Fargene i designsystemet finnes i asset-katalogen", arguments: [
        "Background", "Surface", "TextPrimary", "TextSecondary",
        "BorderNeutral", "AccentRecord", "AccentRecordOn", "RecordingActive"
    ])
    func colorsExist(name: String) {
        #expect(UIColor(named: name) != nil, "Fant ikke fargen \(name)")
    }

    /// accent-knowledge er reservert til kunnskapsdelen og skal ikke være i bruk ennå.
    @Test("Reservert aksentfarge er ikke tatt i bruk")
    func reservedAccentIsAbsent() {
        #expect(UIColor(named: "AccentKnowledge") == nil)
    }
}
