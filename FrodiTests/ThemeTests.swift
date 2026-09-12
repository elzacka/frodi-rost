import Foundation
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

    /// `Font.custom(_:size:)` without `relativeTo:` freezes the text at one size and
    /// ignores Dynamic Type. Every custom font in the app must scale.
    @Test("Ingen skrift er frosset utenfor Dynamic Type")
    func fontsScaleWithDynamicType() throws {
        let sources = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Frodi")
        let enumerator = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))

        var found = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let code = try String(contentsOf: url, encoding: .utf8)
            for line in code.split(separator: "\n") {
                let statement = line.trimmingCharacters(in: .whitespaces)
                guard !statement.hasPrefix("//"), statement.contains("custom("), statement.contains("size:") else { continue }
                #expect(statement.contains("relativeTo:"), "\(url.lastPathComponent): \(statement)")
                found += 1
            }
        }
        #expect(found >= 8, "Fant bare \(found) skriftstiler; stien til kildekoden er feil")
    }

    /// accent-knowledge is reserved for the knowledge feature and must not be in use yet.
    @Test("Reservert aksentfarge er ikke tatt i bruk")
    func reservedAccentIsAbsent() {
        #expect(UIColor(named: "AccentKnowledge") == nil)
    }
}
