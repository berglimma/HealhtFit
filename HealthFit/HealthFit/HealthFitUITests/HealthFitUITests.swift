import XCTest

final class HealthFitUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchShowsInterface() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.waitForExistence(timeout: 5))
    }
}
