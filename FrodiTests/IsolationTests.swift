import Foundation
import SwiftData
import Testing
@testable import Frodi

/// The app's promise is that nothing leaves the device. These tests guard that
/// promise in the code, not in the documentation.
@Suite("Isolasjon")
struct IsolationTests {
    /// No network keys in Info.plist means no ATS exceptions, and no background
    /// mode that could be used to fetch or send data.
    @Test("Ingen unntak fra transportsikkerhet")
    func noAppTransportSecurityExceptions() {
        let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity")
        #expect(ats == nil, "NSAppTransportSecurity er lagt inn – appen skal ikke snakke med nett i det hele tatt")
    }

    /// No networking API in the app's own sources, the widget extension's
    /// included. The plist tests above guard the configuration; this one guards
    /// the code. It reads the source tree from the path the test was compiled
    /// at, which is on the same Mac the simulator runs on.
    @Test("Ingen nettverkskode i appens kildekode")
    func noNetworkingInSources() throws {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let forbidden = ["URLSession", "URLRequest", "NWConnection", "import Network"]
        var checked = 0
        for folder in ["Frodi", "FrodiWidgets"] {
            let sources = root.appending(path: folder)
            let enumerator = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let code = try String(contentsOf: url, encoding: .utf8)
                for symbol in forbidden {
                    #expect(!code.contains(symbol), "\(url.lastPathComponent) bruker \(symbol)")
                }
                checked += 1
            }
        }
        #expect(checked > 10, "Fant bare \(checked) kildefiler; stien til kildekoden er feil")
    }

    /// The one extension is the widget one, for the control and the Live
    /// Activity. It runs in its own process, so it carries its own manifest:
    /// no collection, no accessed API, no ATS exception. Anything else next to
    /// it in PlugIns is a surface nobody reviewed.
    @Test("Den ene utvidelsen er widget-utvidelsen, og den samler ingenting")
    func theOnlyExtensionIsTheWidget() throws {
        let plugIns = try #require(Bundle.main.builtInPlugInsURL)
        // The test bundle itself is placed here while the tests run.
        let extensions = try FileManager.default.contentsOfDirectory(at: plugIns, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .filter { $0.hasSuffix(".appex") }
        #expect(extensions == ["FrodiWidgets.appex"])

        let widget = try #require(Bundle(url: plugIns.appending(path: "FrodiWidgets.appex")))
        let extensionPoint = (widget.object(forInfoDictionaryKey: "NSExtension") as? [String: Any])?["NSExtensionPointIdentifier"] as? String
        #expect(extensionPoint == "com.apple.widgetkit-extension")
        #expect(widget.object(forInfoDictionaryKey: "NSAppTransportSecurity") == nil)

        let url = try #require(widget.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: try Data(contentsOf: url), format: nil) as? [String: Any]
        )
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        #expect((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        #expect((plist["NSPrivacyAccessedAPITypes"] as? [Any])?.isEmpty == true)
    }

    /// The transcript reaches the pasteboard from one button, and that button keeps
    /// it on this device with an expiry. Text selection is what would bring the
    /// system copy menu back, and with it Universal Clipboard.
    @Test("Teksten kopieres bare lokalt, og kan ikke markeres")
    func transcriptCopiesLocallyOnly() throws {
        let views = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Frodi/Views")
        let detail = try String(contentsOf: views.appending(path: "RecordingDetailView.swift"), encoding: .utf8)
        #expect(!detail.contains("textSelection"), "Markering gir systemets kopimeny, som ikke kan holdes lokal")
        #expect(detail.contains(".localOnly: true"))
        #expect(detail.contains(".expirationDate:"))

        let enumerator = try #require(FileManager.default.enumerator(at: views, includingPropertiesForKeys: nil))
        for case let url as URL in enumerator where url.pathExtension == "swift" && url.lastPathComponent != "RecordingDetailView.swift" {
            let code = try String(contentsOf: url, encoding: .utf8)
            #expect(!code.contains("UIPasteboard"), "\(url.lastPathComponent) skriver til utklippstavlen utenom kopiknappen")
        }
    }

    /// `audio` is the only background mode the app should have: a recording
    /// goes on after the screen locks, and nothing else runs without the app in
    /// front. Any other mode would open the door to work that can reach the
    /// network, and a background task would need the key on a locked device.
    @Test("Bare lyd kjører i bakgrunnen")
    func onlyAudioRunsInBackground() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        #expect(modes == ["audio"], "Uventede bakgrunnsmoduser: \(modes)")
        #expect(Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") == nil)
    }

    /// The privacy manifest must say the app collects nothing and does not track.
    @Test("Personvernmanifestet erklærer ingen innsamling")
    func privacyManifestDeclaresNothing() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        #expect((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        #expect((plist["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
    }

    /// The required-reason APIs the app uses, and no others. Apple rejects an
    /// upload that uses one without declaring it, and nothing before the upload
    /// says so. File timestamps for `AudioStorage.creationDate`, user defaults
    /// for the export format and the word list field's height.
    @Test("Personvernmanifestet erklærer akkurat de API-ene appen bruker")
    func privacyManifestDeclaresTheAccessedAPIs() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let accessed = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let declared = Dictionary(uniqueKeysWithValues: accessed.map {
            ($0["NSPrivacyAccessedAPIType"] as? String ?? "", $0["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? [])
        })
        #expect(declared == [
            "NSPrivacyAccessedAPICategoryFileTimestamp": ["C617.1"],
            "NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1"]
        ])
    }

    /// The recordings folder must not end up in the iCloud backup.
    @Test("Opptaksmappen er holdt utenfor sikkerhetskopi")
    func recordingsAreExcludedFromBackup() throws {
        let dir = AudioStorage.directory
        let values = try dir.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    /// Nor must the database. Its content is sealed, but dates and lengths are not.
    @Test("Databasen er holdt utenfor sikkerhetskopi")
    func storeIsExcludedFromBackup() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".store")
        let container = try ModelContainer(for: Recording.self, configurations: ModelConfiguration(url: url))
        defer { try? FileManager.default.removeItem(at: url) }

        AudioStorage.excludeFromBackup(store: container)

        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }
}
