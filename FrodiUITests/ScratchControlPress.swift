import XCTest

/// A tool, not a test. It adds the app's control to Kontrollsenter on the
/// simulator if it is not there, presses it, and leaves the log to say which
/// process performed the intent. Gated like the screenshot tools:
///
/// ```bash
/// TEST_RUNNER_FRODI_SHOTS=1 xcodebuild -project Frodi.xcodeproj -scheme Frodi \
/// -destination 'platform=iOS Simulator,name=Frodi-Test' \
/// -collect-test-diagnostics never \
/// -only-testing:FrodiUITests/ScratchControlPress test
/// xcrun simctl spawn Frodi-Test log show --last 3m \
///   --predicate 'subsystem == "com.Tazk.Frodi" OR (process == "chronod" AND eventMessage CONTAINS "control action")'
/// ```
///
/// Measured on 2026-09-22: the press ran `ToggleRecordingIntent.perform()`
/// in the app's process and started a recording.
final class ScratchControlPress: XCTestCase {
    @MainActor
    func test_press() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FRODI_SHOTS"] != nil,
            "Verktøy. Sett FRODI_SHOTS=1 for å kjøre det."
        )
        XCUIApplication().launch()
        Thread.sleep(forTimeInterval: 2)
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

    private func control(in springboard: XCUIApplication) -> XCUIElement {
        springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'Start eller stopp' OR label CONTAINS[c] 'Opptak'"))
            .firstMatch
    }

    private func openControlCenter(_ springboard: XCUIApplication) {
        let start = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.005))
        let end = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.7))
        start.press(forDuration: 0.1, thenDragTo: end)
        Thread.sleep(forTimeInterval: 2)
    }

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
