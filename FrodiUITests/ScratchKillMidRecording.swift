import XCTest

/// Experiment, not a test: starts a recording and kills the app three seconds in.
/// Whether the file left behind can be opened is checked from outside:
///
/// ```bash
/// TEST_RUNNER_FRODI_KILL=1 xcodebuild -project Frodi.xcodeproj -scheme Frodi \
///   -destination 'platform=iOS Simulator,name=Frodi-Test' \
///   -only-testing:FrodiUITests/ScratchKillMidRecording test
/// afinfo "$(xcrun simctl get_app_container booted com.Tazk.Frodi data)"/Documents/Opptak/*.caf
/// ```
///
/// Measured on 14 September 2026: an `.m4a` left this way cannot be opened, a
/// CAF with AAC opens with zero packets, and PCM in a CAF plays every frame.
/// That is why the recorder writes PCM. Skipped unless `FRODI_KILL` is set,
/// since it leaves an orphan behind on purpose.
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
