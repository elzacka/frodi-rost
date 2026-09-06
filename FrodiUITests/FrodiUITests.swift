import XCTest

final class FrodiUITests: XCTestCase {
    @MainActor
    func test_launch_showsEmptyState() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Ingen opptak ennå"].waitForExistence(timeout: 5))
    }
}
