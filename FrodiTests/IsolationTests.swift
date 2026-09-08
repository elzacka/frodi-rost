import Foundation
import Testing
@testable import Frodi

/// Appens løfte er at ingenting forlater telefonen. Disse testene vokter det
/// løftet i koden, ikke i dokumentasjonen.
@Suite("Isolasjon")
struct IsolationTests {
    /// Ingen nettverksnøkler i Info.plist betyr ingen unntak fra ATS, og
    /// ingen bakgrunnsmodus som kan brukes til å hente eller sende data.
    @Test("Ingen unntak fra transportsikkerhet")
    func noAppTransportSecurityExceptions() {
        let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity")
        #expect(ats == nil, "NSAppTransportSecurity er lagt inn – appen skal ikke snakke med nett i det hele tatt")
    }

    /// `audio` er den eneste bakgrunnsmodusen appen skal ha. `fetch` eller
    /// `processing` ville åpnet for arbeid som kan nå nettet.
    @Test("Bare lyd kjører i bakgrunnen")
    func onlyAudioRunsInBackground() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        #expect(modes == ["audio"], "Uventede bakgrunnsmoduser: \(modes)")
    }

    /// Personvernmanifestet skal si at appen ikke samler inn noe og ikke sporer.
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

    /// Opptaksmappen skal ikke havne i iCloud-sikkerhetskopien.
    @Test("Opptaksmappen er holdt utenfor sikkerhetskopi")
    func recordingsAreExcludedFromBackup() throws {
        let dir = AudioStorage.directory
        let values = try dir.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }
}
