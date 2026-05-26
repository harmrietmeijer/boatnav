import XCTest

@MainActor
final class BoatNavUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        setupSnapshot(app)
        app.launch()
    }

    // MARK: - iPad Screenshots

    func testScreenshots() throws {
        // 1. Kaart — default map view
        sleep(3)
        snapshot("01_iPad_Pro_129_kaart")

        // 2. Navigatie — route panel
        let routeButton = app.buttons["dashboard_route"]
        if routeButton.waitForExistence(timeout: 5) {
            routeButton.tap()
            sleep(1)
            snapshot("02_iPad_Pro_129_navigatie")
            // Close panel
            app.buttons.matching(identifier: "xmark").firstMatch.tap()
            sleep(1)
        }

        // 3. Snelheid — dashboard with speed visible
        snapshot("03_iPad_Pro_129_snelheid")

        // 4. Instellingen — settings panel
        let settingsButton = app.buttons["dashboard_meer"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(1)
            snapshot("04_iPad_Pro_129_instellingen")
            app.buttons.matching(identifier: "xmark").firstMatch.tap()
            sleep(1)
        }

        // 5. Meldingen — hazard report dialog
        let hazardButton = app.buttons["hazard_report_button"]
        if hazardButton.waitForExistence(timeout: 5) {
            hazardButton.tap()
            sleep(1)
            snapshot("05_iPad_Pro_129_meldingen")
            app.buttons.matching(identifier: "xmark").firstMatch.tap()
            sleep(1)
        }

        // 6. Vrienden — location sharing panel
        let friendsButton = app.buttons["dashboard_delen"]
        if friendsButton.waitForExistence(timeout: 5) {
            friendsButton.tap()
            sleep(1)
            snapshot("06_iPad_Pro_129_vrienden")
            app.buttons.matching(identifier: "xmark").firstMatch.tap()
            sleep(1)
        }

        // 7. Meldingen kaart — map view
        sleep(1)
        snapshot("07_iPad_Pro_129_meldingen_kaart")
    }

    // MARK: - Basic test

    func testAppLaunches() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
