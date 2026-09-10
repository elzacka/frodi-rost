import Testing
import UIKit
@testable import Frodi

/// Et ikon som mangler i asset-katalogen tegner ingen ting. Knappen blir da
/// stående tom, og den feilen ser ingen før den står i en app-butikk.
@Suite("Ikoner")
struct IconTests {
    @Test("Alle ikoner finnes i asset-katalogen", arguments: Icon.allCases)
    func iconsExist(icon: Icon) {
        #expect(UIImage(named: icon.rawValue) != nil, "Fant ikke ikonet \(icon.rawValue)")
    }
}
