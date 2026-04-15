import XCTest

/// M0 UI canary. Launches the app and confirms it reaches foreground.
/// Real XCUITest coverage lands in later milestones once there are
/// actual flows to drive.
final class SealoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_appLaunchesToForeground() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }
}
