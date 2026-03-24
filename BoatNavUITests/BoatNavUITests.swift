import XCTest

final class BoatNavUITests: XCTestCase {

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify tab bar exists with expected tabs
        XCTAssertTrue(app.tabBars.buttons["Kaart"].exists)
        XCTAssertTrue(app.tabBars.buttons["Snelheid"].exists)
        XCTAssertTrue(app.tabBars.buttons["Navigatie"].exists)
        XCTAssertTrue(app.tabBars.buttons["Instellingen"].exists)
    }
}
