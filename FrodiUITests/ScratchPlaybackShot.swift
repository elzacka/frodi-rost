import XCTest

/// Verktøy, ikke test. Den tar et skjermbilde av detaljskjermen og sjekker
/// ingenting, men kostet likevel 13 sekunder i hver eneste testkjøring.
///
/// Den kjører nå bare når du ber om det. Prefikset `TEST_RUNNER_` er det
/// xcodebuild krever for å sende en variabel videre til testprosessen; appen
/// ser den som `FRODI_SHOTS`:
///
/// ```bash
/// TEST_RUNNER_FRODI_SHOTS=1 xcodebuild -project Frodi.xcodeproj -scheme Frodi \
///   -destination 'platform=iOS Simulator,name=Frodi-Test' \
///   -only-testing:FrodiUITests/ScratchPlaybackShot test
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
