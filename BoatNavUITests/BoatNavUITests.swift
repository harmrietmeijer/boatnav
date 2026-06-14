import XCTest

@MainActor
final class BoatNavUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Standard Screenshots

    func testScreenshots() throws {
        setupSnapshot(app)
        app.launch()

        sleep(3)
        snapshot("01_kaart")

        let routeButton = app.buttons["arrow.triangle.turn.up.right.diamond.fill"]
        if routeButton.waitForExistence(timeout: 5) {
            routeButton.tap()
            sleep(1)
            snapshot("02_navigatie")
        }

        snapshot("03_snelheid")

        let settingsButton = app.buttons["gearshape.fill"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(1)
            snapshot("04_instellingen")
        }
    }

    // MARK: - Turn-by-Turn Navigation Screenshots (for Apple CarPlay review)

    func testNavigationScreenshots() throws {
        app.launchArguments += ["SCREENSHOT_MODE", "-FASTLANE_SNAPSHOT", "YES", "-ui_testing"]
        setupSnapshot(app)
        app.launch()

        // Wait for demo route to load and navigation panel to appear
        sleep(5)

        // 1. Navigation panel with route instructions
        let attachment1 = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment1.name = "nav_01_route_instructies"
        attachment1.lifetime = .keepAlways
        add(attachment1)
        snapshot("nav_01_route_instructies")

        // 2. Scroll down to show more maneuvers
        app.swipeUp()
        sleep(1)
        let attachment2 = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment2.name = "nav_02_route_details"
        attachment2.lifetime = .keepAlways
        add(attachment2)
        snapshot("nav_02_route_details")
    }

    // MARK: - Basic test

    func testAppLaunches() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
