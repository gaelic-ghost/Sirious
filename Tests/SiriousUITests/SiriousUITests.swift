import XCTest

final class SiriousUITests: XCTestCase {
    @MainActor
    func testLaunchShowsCommandCenter() {
        let app = XCUIApplication()
        app.launchEnvironment["SIRIOUS_SKIP_STARTUP_FILE_ACCESS_PROMPT"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["Sirious"].waitForExistence(timeout: 5))
    }
}
