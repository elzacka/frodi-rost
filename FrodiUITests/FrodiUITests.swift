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

    /// The Info page is the app's only place for privacy, permissions and
    /// attribution. Apache 2.0 requires the licence list to actually be in the app.
    @MainActor
    func test_about_opensAndReachesLicenses() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Info om appen"].waitForExistence(timeout: 5), "Knappen i logohodet mangler")
        app.buttons["Info om appen"].tap()

        XCTAssertTrue(app.buttons["Lisenser"].waitForExistence(timeout: 5), "Info-siden åpnet ikke")
        app.buttons["Lisenser"].tap()

        XCTAssertTrue(app.staticTexts["WhisperKit"].waitForExistence(timeout: 5), "Lisenslisten mangler")
    }
}
