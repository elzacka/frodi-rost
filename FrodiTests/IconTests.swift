import Testing
import UIKit
@testable import Frodi

/// An icon missing from the asset catalogue draws nothing. The button is then
/// left empty, and nobody sees that fault before it is in an app store.
@Suite("Ikoner")
struct IconTests {
    @Test("Alle ikoner finnes i asset-katalogen", arguments: Icon.allCases)
    func iconsExist(icon: Icon) {
        #expect(UIImage(named: icon.rawValue) != nil, "Fant ikke ikonet \(icon.rawValue)")
    }
}
