import XCTest

/// Tool, not a test: adds and presses the app's Kontrollsenter control on the simulator (`FRODI_SHOTS`); the log
/// shows which process ran the intent. Green proves routing only: the simulator allows a non-mixable background
/// session a device refuses ('!int'). Run command and log query: README, *Verktøy og målinger*.
final class ScratchControlPress: XCTestCase {
    @MainActor
    func test_press() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FRODI_SHOTS"] != nil,
            "Verktøy. Sett FRODI_SHOTS=1 for å kjøre det."
        )
        XCUIApplication().launch()
        Thread.sleep(forTimeInterval: 2)
        pressFromHomeScreen()
    }

    /// The order from the report: a recording made and stopped in the app,
    /// then Home, then the control.
    @MainActor
    func test_pressAfterRecording() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FRODI_SHOTS"] != nil,
            "Verktøy. Sett FRODI_SHOTS=1 for å kjøre det."
        )
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Start opptak"].waitForExistence(timeout: 5))
        app.buttons["Start opptak"].tap()
        Thread.sleep(forTimeInterval: 4)
        app.buttons["Stopp opptak"].tap()
        Thread.sleep(forTimeInterval: 2)
        pressFromHomeScreen()
    }

    @MainActor
    private func pressFromHomeScreen() {
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        openControlCenter(springboard)
        if !control(in: springboard).exists {
            addControl(springboard)
            XCUIDevice.shared.press(.home)
            Thread.sleep(forTimeInterval: 1)
            openControlCenter(springboard)
        }
        let ours = control(in: springboard)
        XCTAssertTrue(ours.waitForExistence(timeout: 3), "Ingen kontroll i Kontrollsenter")
        ours.tap()
        Thread.sleep(forTimeInterval: 4)
        XCUIDevice.shared.press(.home)
    }

    @MainActor
    private func control(in springboard: XCUIApplication) -> XCUIElement {
        springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'Start eller stopp' OR label CONTAINS[c] 'Opptak'"))
            .firstMatch
    }

    @MainActor
    private func openControlCenter(_ springboard: XCUIApplication) {
        let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.005))
        let end = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.7))
        start.press(forDuration: 0.1, thenDragTo: end)
        Thread.sleep(forTimeInterval: 2)
    }

    @MainActor
    private func addControl(_ springboard: XCUIApplication) {
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).press(forDuration: 1.5)
        let add = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Legg til'")).firstMatch
        if add.waitForExistence(timeout: 3) { add.tap() }
        let field = springboard.searchFields.firstMatch
        if field.waitForExistence(timeout: 3) { field.tap(); field.typeText("opptak") }
        let ours = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'Start eller stopp'")).firstMatch
        if ours.waitForExistence(timeout: 3) { ours.tap() }
        Thread.sleep(forTimeInterval: 1)
    }
}
