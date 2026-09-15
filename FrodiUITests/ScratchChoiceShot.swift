import XCTest

/// A tool, not a test, like `ScratchPlaybackShot`: pictures of the delete
/// sheet, the export sheet and the Eksport card on the Info page. Runs only
/// with `TEST_RUNNER_FRODI_SHOTS=1`.
///
/// The export sheet only comes up for a recording with text, and a silent
/// simulator recording has none. To picture it, force the question in
/// `RecordingDetailView` for the run, and put it back.
final class ScratchChoiceShot: XCTestCase {
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
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 1)
        app.buttons["Slett"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)
        attach("slett")

        app.buttons["Avbryt"].tap()
        Thread.sleep(forTimeInterval: 1)

        row.tap()
        Thread.sleep(forTimeInterval: 1)
        app.buttons["Eksporter opptaket"].tap()
        Thread.sleep(forTimeInterval: 1)
        attach("eksport")
        if app.buttons["Avbryt"].exists {
            app.buttons["Avbryt"].tap()
            Thread.sleep(forTimeInterval: 1)
        }
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["Info om appen"].tap()
        Thread.sleep(forTimeInterval: 1)
        app.swipeUp()
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1)
        attach("info")
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways
        shot.name = name
        add(shot)
    }
}
