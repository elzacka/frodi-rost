import XCTest

final class ScratchPlaybackShot: XCTestCase {
    @MainActor
    func test_shot() {
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
