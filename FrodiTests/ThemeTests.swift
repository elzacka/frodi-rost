import Testing
import UIKit
@testable import Frodi

@Suite("Designsystem")
struct ThemeTests {
    /// A font that is not registered silently falls back to the system font. The
    /// app then looks almost right, and the fault is never noticed.
    @Test("Alle bundlede fonter lar seg laste", arguments: [
        "Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Skranji-Bold"
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

    /// accent-knowledge is reserved for the knowledge feature and must not be in use yet.
    @Test("Reservert aksentfarge er ikke tatt i bruk")
    func reservedAccentIsAbsent() {
        #expect(UIColor(named: "AccentKnowledge") == nil)
    }
}
