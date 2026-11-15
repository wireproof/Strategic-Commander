import XCTest
final class FleetGestureTests: XCTestCase {
    func testDragFleetAndLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()
        let source = app.buttons["planet-0"]
        let destination = app.buttons["planet-2"]
        XCTAssertTrue(source.waitForExistence(timeout: 20))
        source.press(forDuration: 0.1, thenDragTo: destination)
        XCTAssertTrue(app.staticTexts["To Sirius"].waitForExistence(timeout: 5))
        let launch = app.buttons["Launch Fleet to Sirius"]
        XCTAssertTrue(launch.exists)
        launch.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS 'ships launched to Sirius'")).firstMatch.waitForExistence(timeout: 5))
    }
    func testBattlePlaybackAndReport() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-battle"]
        app.launch()
        let end = app.buttons["END TURN"]
        XCTAssertTrue(end.waitForExistence(timeout:20))
        end.tap()
        XCTAssertTrue(app.staticTexts["BATTLE AT SIRIUS"].waitForExistence(timeout:5))
        let report = app.buttons["Turn Report"]
        XCTAssertTrue(report.waitForExistence(timeout:25)); report.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS 'BATTLE AT Sirius'")).firstMatch.waitForExistence(timeout:5))
    }
}
