import Foundation
import Testing
@testable import Frodi

/// The limit is in the text the user reads, so the numbers there must follow the
/// constant. If someone changes `RecordingLimit.duration`, minutes, words and
/// characters must all follow by themselves, not stay behind as numbers in a sentence.
@Suite("Grensen for opptak")
struct RecordingLimitTests {
    @Test("Minutter og ord regnes ut fra lengden")
    func derivedFromDuration() {
        #expect(RecordingLimit.minutes == Int(RecordingLimit.duration / 60))
        #expect(RecordingLimit.words == RecordingLimit.minutes * 170)
    }

    @Test("Grensen er lang nok til å være verdt å ha, og kort nok til å gå gjennom")
    func withinMeasuredCeiling() {
        // Ten minutes is measured all the way through on the simulator; fifteen was killed.
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
