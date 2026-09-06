import Foundation
import Testing
@testable import Frodi

@Suite("Personvern")
struct PrivacyTests {
    /// SFSpeechRecognizer tvinger fram en dialog der Apples egen tekst sier at
    /// taledata sendes til dem. Den motsier hele poenget med appen. Kommer denne
    /// nøkkelen tilbake, er noen på vei tilbake til det gamle rammeverket.
    @Test("Appen ber ikke om tilgang til talegjenkjenning")
    func doesNotRequestSpeechRecognition() {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription")
        #expect(value == nil, "NSSpeechRecognitionUsageDescription er tilbake i Info.plist")
    }

    @Test("Appen ber om mikrofon, og forklarer hvorfor")
    func explainsMicrophoneUse() {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String
        #expect(value?.isEmpty == false)
    }

    /// Opptak må overleve at skjermen låses, ellers stopper diktafonen i bilen.
    @Test("Bakgrunnslyd er slått på")
    func backgroundAudioEnabled() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        #expect(modes?.contains("audio") == true)
    }
}
