import XCTest

/// Experiment, not a test: kills the app 3 s into a recording; skipped unless `FRODI_KILL` (leaves an orphan).
/// Measured 2026-09-14: a killed .m4a is unopenable, CAF-AAC has 0 packets, PCM in CAF plays every frame: why PCM.
/// Run command: README, *Verktøy og målinger*.
final class ScratchKillMidRecording: XCTestCase {
    @MainActor
    func test_killMidRecording() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FRODI_KILL"] != nil,
            "Eksperiment, kjøres bare med FRODI_KILL=1"
        )
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Start opptak"].waitForExistence(timeout: 5))
        app.buttons["Start opptak"].tap()
        XCTAssertTrue(app.buttons["Stopp opptak"].waitForExistence(timeout: 5))
        sleep(3)
        app.terminate()
    }
}
