import XCTest

final class FrodiUITests: XCTestCase {
    /// Smoke test. Checks what is always there, whether or not the app already has
    /// recordings. The previous version looked for the empty state and failed as
    /// soon as the simulator had a recording left over from an earlier run.
    @MainActor
    func test_launch_showsHeaderAndRecordButton() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Fróði røst"].waitForExistence(timeout: 5),
            "Logohodet mangler"
        )
        XCTAssertTrue(
            app.buttons["Start opptak"].waitForExistence(timeout: 5),
            "Opptaksknappen mangler"
        )
    }

    /// Innstillinger is the app's only place for privacy, permissions and
    /// attribution. Apache 2.0 requires the licence list to actually be in the app.
    @MainActor
    func test_about_opensAndReachesLicenses() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Innstillinger"].waitForExistence(timeout: 5), "Knappen i logohodet mangler")
        app.buttons["Innstillinger"].tap()

        XCTAssertTrue(app.buttons["Lisenser"].waitForExistence(timeout: 5), "Innstillinger åpnet ikke")
        app.buttons["Lisenser"].tap()

        XCTAssertTrue(app.staticTexts["argmax-oss-swift"].waitForExistence(timeout: 5), "Lisenslisten mangler")
    }

    /// A swipe to the left shows what can be done with a recording, and «Slett»
    /// asks in the row before anything goes. «Nei» keeps the recording. Uses a
    /// recording the simulator already has, or makes a short one.
    @MainActor
    func test_swipeLeft_asksBeforeDeleting() {
        let app = XCUIApplication()
        app.launch()

        var row = app.scrollViews.otherElements.buttons.firstMatch
        if !row.waitForExistence(timeout: 3) {
            app.buttons["Start opptak"].tap()
            Thread.sleep(forTimeInterval: 2)
            app.buttons["Stopp opptak"].tap()
            row = app.scrollViews.otherElements.buttons.firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10), "Ingen rad å sveipe")
        }
        let label = row.label

        row.swipeLeft()
        let delete = app.buttons["Slett"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "Sveipet viste ikke «Slett»")
        delete.tap()

        XCTAssertTrue(app.staticTexts["Sikker på at du vil slette?"].waitForExistence(timeout: 5), "Raden spurte ikke")
        app.buttons["Nei"].tap()

        XCTAssertTrue(app.staticTexts["Sikker på at du vil slette?"].waitForNonExistence(timeout: 5), "Spørsmålet ble stående")
        XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 5), "Opptaket forsvant etter «Nei»")
    }

    /// The back button is the app's own, and UIKit switches the swipe from the
    /// left edge off for a screen that hides the system's. `PopGestureKeeper`
    /// switches it back on; this is what tells if an iOS release breaks that.
    /// Lisenser is the screen used because it needs no recording to reach.
    @MainActor
    func test_swipeFromLeftEdge_popsTheScreen() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Innstillinger"].tap()
        XCTAssertTrue(app.buttons["Lisenser"].waitForExistence(timeout: 5), "Innstillinger åpnet ikke")
        app.buttons["Lisenser"].tap()
        XCTAssertTrue(app.buttons["Tilbake"].waitForExistence(timeout: 5), "Tilbakeknappen mangler")

        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
        let inward = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: inward, withVelocity: .slow, thenHoldForDuration: 0.2)

        XCTAssertTrue(app.buttons["Lisenser"].waitForExistence(timeout: 5), "Sveip fra venstre kant gikk ikke tilbake")
    }
}
