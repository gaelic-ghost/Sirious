import XCTest

final class SiriousUITests: XCTestCase {
    @MainActor
    func testLaunchShowsCommandCenter() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Sirious"].waitForExistence(timeout: 5))
    }
}
