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
}
