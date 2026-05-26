import XCTest

@MainActor
final class WaterPanelTest: XCTestCase {

    func testOpenWaterPanel() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
        sleep(5)

        // Dismiss any alerts
        if app.alerts.firstMatch.waitForExistence(timeout: 3) {
            app.alerts.firstMatch.buttons["Cancel"].tap()
            sleep(1)
        }

        // Tap water level button
        let waterBtn = app.buttons["water_level"]
        XCTAssertTrue(waterBtn.waitForExistence(timeout: 10), "Water level button not found")
        waterBtn.tap()
        sleep(4)

        snapshot("waterstand_paneel")
    }
}
