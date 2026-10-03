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

    /// The import button opens the system's file picker. What happens to a
    /// picked file is `ImportTests`; the picker itself is the system's.
    @MainActor
    func test_importButton_opensFilePicker() {
        let app = XCUIApplication()
        app.launch()

        let button = app.buttons["Importer lydfil"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Importknappen i logohodet mangler")
        button.tap()

        // The picker speaks the simulator's language, not the app's. It is a remote view: the app's tree shows an empty overlay until its
        // controls arrive, 10 to 14 s after the tap on the iOS 27 simulator, so the wait is long. It still fails if the picker never opens.
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Avbryt", "Cancel"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 30), "Filvelgeren åpnet ikke")
        cancel.tap()
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Filvelgeren lukket seg ikke")
    }

    /// A drag up that starts on a row scrolls the list. The row's own swipe is sideways only; a gesture taking every drag would leave
    /// the list unscrollable under a finger on a row. Makes short recordings until the list is taller than the screen.
    @MainActor
    func test_dragOnRows_scrollsTheList() {
        let app = XCUIApplication()
        app.launch()

        let list = app.scrollViews.firstMatch
        let rows = list.buttons
        let screen = app.windows.firstMatch.frame
        var made = 0
        while (rows.count == 0 || rows.element(boundBy: rows.count - 1).frame.maxY < screen.maxY) && made < 12 {
            app.buttons["Start opptak"].tap()
            XCTAssertTrue(app.buttons["Stopp opptak"].waitForExistence(timeout: 5), "Opptaket startet ikke")
            sleep(1)
            app.buttons["Stopp opptak"].tap()
            XCTAssertTrue(app.buttons["Start opptak"].waitForExistence(timeout: 5))
            made += 1
        }

        let first = rows.element(boundBy: 0)
        let before = first.frame.minY
        list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            .press(forDuration: 0.05, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        XCTAssertLessThan(first.frame.minY, before - 50, "Listen rullet ikke")
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
    /// asks in the row before anything goes. «Behold» keeps the recording. Uses a
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
        app.buttons["Behold"].tap()

        XCTAssertTrue(app.staticTexts["Sikker på at du vil slette?"].waitForNonExistence(timeout: 5), "Spørsmålet ble stående")
        XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 5), "Opptaket forsvant etter «Behold»")
    }

    /// A name makes a row taller; the actions behind it keep the height of a one-line row (device, 2026-10-03).
    @MainActor
    func test_swipeActions_keepTheirHeightOnANamedRow() {
        let app = XCUIApplication()
        app.launch()

        for _ in 0..<2 {
            app.buttons["Start opptak"].tap()
            Thread.sleep(forTimeInterval: 2)
            app.buttons["Stopp opptak"].tap()
            Thread.sleep(forTimeInterval: 1)
        }
        let rows = app.scrollViews.otherElements.buttons
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 10), "To rader mangler")

        let name = "Intervju med kommunedirektøren om budsjettet for neste år"
        rows.element(boundBy: 0).tap()
        let title = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", " | ")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Tittelmenyen mangler")
        title.tap()
        let rename = app.buttons["Endre navn"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5), "«Endre navn» mangler")
        rename.tap()
        app.textFields.firstMatch.typeText(name)
        app.buttons["Lagre"].tap()
        app.navigationBars.buttons["Tilbake"].tap()

        let named = rows.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(named.waitForExistence(timeout: 5), "Raden med navn mangler")
        let plain = rows.element(boundBy: 1)
        XCTAssertGreaterThan(named.frame.height, plain.frame.height, "Navnet gjorde ikke raden høyere")

        func deleteHeight(behind row: XCUIElement) -> CGFloat {
            row.swipeLeft()
            let delete = app.buttons["Slett"].firstMatch
            XCTAssertTrue(delete.waitForExistence(timeout: 5), "Sveipet viste ikke «Slett»")
            let height = delete.frame.height
            delete.tap()
            app.buttons["Slett"].firstMatch.tap()
            Thread.sleep(forTimeInterval: 1)
            return height
        }
        let onNamed = deleteHeight(behind: named)
        let onPlain = deleteHeight(behind: rows.element(boundBy: 0))
        XCTAssertEqual(onNamed, onPlain, accuracy: 0.5, "«Slett» fulgte radens høyde")
        XCTAssertGreaterThanOrEqual(onPlain, 44, "«Slett» er lavere enn 44 pt")
    }

    /// The back button is the app's own, and UIKit switches off the left-edge swipe for a screen that hides the system's.
    /// `PopGestureKeeper` switches it back on; this tells if an iOS release breaks that. Lisenser is used: no recording needed to reach it.
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
