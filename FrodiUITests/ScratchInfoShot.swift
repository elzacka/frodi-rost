import XCTest

/// A tool, not a test, like `ScratchPlaybackShot`. It opens the Info page and
/// attaches a screenshot of the first card, so the footnote can be checked at a
/// Dynamic Type size without a device. Set the size on the simulator first:
///
/// ```bash
/// xcrun simctl ui Frodi-Test content_size extra-small
/// TEST_RUNNER_FRODI_SHOTS=1 xcodebuild -project Frodi.xcodeproj -scheme Frodi \
/// -destination 'platform=iOS Simulator,name=Frodi-Test' \
/// -only-testing:FrodiUITests/ScratchInfoShot test
/// ```
final class ScratchInfoShot: XCTestCase {
    @MainActor
    func test_shot() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FRODI_SHOTS"] != nil,
            "Skjermbildeverktøy. Sett FRODI_SHOTS=1 for å kjøre det."
        )

        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Info om appen"].waitForExistence(timeout: 5))
        app.buttons["Info om appen"].tap()
        Thread.sleep(forTimeInterval: 2)

        // At accessibility sizes the footnote is below the fold; bring it up.
        let footnote = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Fotnote.'")).firstMatch
        var swipes = 0
        while !(footnote.exists && footnote.isHittable) && swipes < 12 {
            app.swipeUp()
            swipes += 1
        }
        Thread.sleep(forTimeInterval: 1)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways
        shot.name = "info"
        add(shot)
    }
}
