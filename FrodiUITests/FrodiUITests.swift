import XCTest

final class FrodiUITests: XCTestCase {
    /// Røyktest. Sjekker det som alltid er der, uansett om appen har opptak
    /// fra før. Den forrige versjonen så etter tomtilstanden og feilet så snart
    /// simulatoren hadde et opptak liggende fra en tidligere kjøring.
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

    /// Om-arket er appens eneste sted for personvern, tillatelser og
    /// attribusjon. Apache 2.0 krever at lisenslisten faktisk er å finne i appen.
    @MainActor
    func test_about_opensAndReachesLicenses() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Om appen"].waitForExistence(timeout: 5), "Knappen i logohodet mangler")
        app.buttons["Om appen"].tap()

        XCTAssertTrue(app.buttons["Lisenser"].waitForExistence(timeout: 5), "Om-arket åpnet ikke")
        app.buttons["Lisenser"].tap()

        XCTAssertTrue(app.staticTexts["WhisperKit"].waitForExistence(timeout: 5), "Lisenslisten mangler")
    }
}
