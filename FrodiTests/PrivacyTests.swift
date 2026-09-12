import Foundation
import Testing
@testable import Frodi

@Suite("Personvern")
struct PrivacyTests {
    /// SFSpeechRecognizer forces a dialog in which Apple's own text says speech data
    /// is sent to them. It contradicts the whole point of the app. If this key comes
    /// back, someone is on their way back to the old framework.
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

    /// Recording must survive the screen locking, or it stops in the car.
    @Test("Bakgrunnslyd er slått på")
    func backgroundAudioEnabled() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        #expect(modes?.contains("audio") == true)
    }
}
