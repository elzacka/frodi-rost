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

    /// No networking API in the app's own sources. The plist tests above guard
    /// the configuration; this one guards the code. It reads the source tree from
    /// the path the test was compiled at, which is on the same Mac the simulator
    /// runs on.
    @Test("Ingen nettverkskode i appens kildekode")
    func noNetworkingInSources() throws {
        let sources = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Frodi")
        let enumerator = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))

        let forbidden = ["URLSession", "URLRequest", "NWConnection", "import Network"]
        var checked = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let code = try String(contentsOf: url, encoding: .utf8)
            for symbol in forbidden {
                #expect(!code.contains(symbol), "\(url.lastPathComponent) bruker \(symbol)")
            }
            checked += 1
        }
        #expect(checked > 10, "Fant bare \(checked) kildefiler; stien til kildekoden er feil")
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

    /// `audio` and `processing` are the only background modes the app should
    /// have. `processing` runs the `BGProcessingTask` that resumes
    /// transcription while charging and locked; anything else would open the
    /// door to work that can reach the network.
    @Test("Bare lyd og transkribering kjører i bakgrunnen")
    func onlyAudioAndProcessingRunInBackground() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        #expect(modes == ["audio", "processing"], "Uventede bakgrunnsmoduser: \(modes)")
        let identifiers = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? []
        #expect(identifiers == [BackgroundTranscription.identifier])
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
