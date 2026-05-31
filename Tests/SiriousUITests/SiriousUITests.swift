import XCTest

final class SiriousUITests: XCTestCase {
    @MainActor
    func testLaunchShowsCommandCenter() {
        let app = launchSirious()

        XCTAssertTrue(app.staticTexts["Sirious"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Local voice command routing lab"].exists)
        XCTAssertTrue(app.staticTexts["Route"].exists)
        XCTAssertTrue(app.staticTexts["local_function"].exists)
        XCTAssertTrue(app.staticTexts["Domain"].exists)
        XCTAssertTrue(app.staticTexts["app_control"].exists)
        XCTAssertTrue(app.staticTexts["Readiness"].exists)
        XCTAssertTrue(app.staticTexts["actionable"].exists)
    }

    @MainActor
    func testSettingsShowsPermissionLaunchAndDictationControls() {
        let app = launchSirious()

        openSettings(in: app)

        XCTAssertTrue(app.staticTexts["Permissions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Permissions"].exists)
        XCTAssertTrue(app.staticTexts["Accessibility"].exists)
        XCTAssertTrue(app.staticTexts["Files"].exists)
        XCTAssertTrue(app.staticTexts["Home Folder"].exists)
        XCTAssertTrue(app.staticTexts["Launch"].exists)
        XCTAssertTrue(app.staticTexts["Open at Login"].exists)
        XCTAssertTrue(app.staticTexts["Dictation"].exists)
        XCTAssertTrue(app.staticTexts["Pause Before Exit"].exists)
        XCTAssertTrue(app.buttons["Open Debug Window"].exists)
    }

    @MainActor
    func testSettingsOpensDebugWindow() {
        let app = launchSirious()

        openSettings(in: app)
        app.buttons["Open Debug Window"].click()

        XCTAssertTrue(app.staticTexts["Transcript"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Final Transcript"].exists)
        XCTAssertTrue(app.buttons["Classify Transcript"].exists)
        XCTAssertTrue(app.buttons["Refresh System Commands"].exists)
        XCTAssertTrue(app.staticTexts["System Command Catalog"].exists)
        XCTAssertTrue(app.staticTexts["Latest Route"].exists)
    }

    @MainActor
    private func launchSirious() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SIRIOUS_SKIP_STARTUP_FILE_ACCESS_PROMPT"] = "1"
        app.launch()
        return app
    }

    @MainActor
    private func openSettings(in app: XCUIApplication) {
        app.typeKey(",", modifierFlags: .command)
    }
}
