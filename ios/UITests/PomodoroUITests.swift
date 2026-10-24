import XCTest

/// Walks through every screen on the simulator: the timer, typing a time,
/// settings tabs, the pairing screen and the Lock Screen timer. With
/// SHOTS=<folder> (test.sh passes it) it saves a screenshot of each.
@MainActor
final class PomodoroUITests: XCTestCase {
    private let app = XCUIApplication()
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() async throws {
        continueAfterFailure = false
        app.launch()
    }

    func testScreens() {
        shot("1-timer")

        app.staticTexts["25:00"].tap()
        app.typeText("10")
        shot("1b-typing")
        app.typeText("\n")
        XCTAssertTrue(app.staticTexts["10:00"].waitForExistence(timeout: 2))

        app.buttons["Start"].tap()
        allowIfAsked()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 2))
        shot("2-running")

        // The Live Activity, in the Notification Centre over the Home Screen.
        XCUIDevice.shared.press(.home)
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.01))
        top.press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7)))
        // Right after an install the extension takes a while to draw it.
        let pause = springboard.buttons["Pause"]
        let shown = pause.waitForExistence(timeout: 15)
        shot("3-lock-screen")
        XCTAssertTrue(shown, "the Live Activity is on screen")
        pause.tap()
        sleep(2)
        shot("4-lock-screen-paused")
        app.activate()
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 3), "the Lock Screen button paused the timer")

        app.buttons["Stop and reset"].tap()
        app.buttons["Settings"].tap()
        for tab in ["General", "Intervals", "Sounds", "Devices"] {
            app.buttons[tab].tap()
            shot("5-settings-\(tab.lowercased())")
        }
        // "Pair again" once paired.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Pair '")).firstMatch.tap()
        allowIfAsked()
        shot("6-pair")
    }

    /// The system asks for notifications at the first start, and for the camera at pairing.
    private func allowIfAsked() {
        for title in ["Allow", "OK"] where springboard.buttons[title].waitForExistence(timeout: 2) {
            springboard.buttons[title].tap()
            return
        }
    }

    private func shot(_ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["SHOTS"] else { return }
        let url = URL(fileURLWithPath: folder).appendingPathComponent(name + ".png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
    }
}
