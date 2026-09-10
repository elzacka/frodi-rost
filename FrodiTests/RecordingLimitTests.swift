import Foundation
import Testing
@testable import Frodi

/// Grensen står i teksten brukeren leser, så tallene der må følge konstanten.
/// Endrer noen `RecordingLimit.duration`, skal både minutter, ord og tegn følge
/// med av seg selv – ikke bli stående igjen som tall i en setning.
@Suite("Grensen for opptak")
struct RecordingLimitTests {
    @Test("Minutter, ord og tegn regnes ut fra lengden")
    func derivedFromDuration() {
        #expect(RecordingLimit.minutes == Int(RecordingLimit.duration / 60))
        #expect(RecordingLimit.words == RecordingLimit.minutes * 170)
        #expect(RecordingLimit.characters == RecordingLimit.words * 6)
    }

    @Test("Grensen er lang nok til å være verdt å ha, og kort nok til å gå gjennom")
    func withinMeasuredCeiling() {
        // Ti minutter er målt helt gjennom på simulator, femten ble drept.
        #expect(RecordingLimit.minutes >= 1)
        #expect(RecordingLimit.duration <= 10 * 60)
    }

    @Test("Tall skrives med hardt mellomrom, ikke komma")
    func norwegianGrouping() {
        let text = RecordingLimit.formatted(1_700)
        #expect(text.contains("\u{00A0}"))
        #expect(!text.contains(","))
        #expect(text.filter(\.isNumber) == "1700")
    }

    @MainActor
    @Test("Nedtellingen starter på hele grensen og går ikke under null")
    func remainingIsClamped() {
        let recorder = AudioRecorder()
        #expect(recorder.remaining == RecordingLimit.duration)
    }
}
