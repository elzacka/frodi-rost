import XCTest

/// A tool, not a test. It takes a screenshot of the detail screen and checks
/// nothing, yet cost 13 seconds in every single test run.
///
/// It now runs only when asked. The `TEST_RUNNER_` prefix is what xcodebuild
/// requires to pass a variable on to the test process; the app sees it as
/// `FRODI_SHOTS`:
///
/// ```bash
/// TEST_RUNNER_FRODI_SHOTS=1 xcodebuild -project Frodi.xcodeproj -scheme Frodi \
/// -destination 'platform=iOS Simulator,name=Frodi-Test' \
/// -only-testing:FrodiUITests/ScratchPlaybackShot test
/// ```
final class ScratchPlaybackShot: XCTestCase {
    @MainActor
    func test_shot() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FRODI_SHOTS"] != nil,
            "Skjermbildeverktøy. Sett FRODI_SHOTS=1 for å kjøre det."
        )

        let app = XCUIApplication()
        app.launch()

        app.buttons["Start opptak"].tap()
        Thread.sleep(forTimeInterval: 2)
        app.buttons["Stopp opptak"].tap()
        Thread.sleep(forTimeInterval: 2)

        let row = app.scrollViews.otherElements.buttons.firstMatch
        if row.waitForExistence(timeout: 5) { row.tap() } else { app.buttons.element(boundBy: 1).tap() }
        Thread.sleep(forTimeInterval: 3)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways
        shot.name = "detalj"
        add(shot)
    }
}
