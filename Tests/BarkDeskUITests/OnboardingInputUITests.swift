import XCTest

final class OnboardingInputUITests: XCTestCase {
    func testKeyboardInputChangesOnboardingFields() {
        let app = XCUIApplication()
        app.launchEnvironment["BARKDESK_HOME"] = NSTemporaryDirectory()
            + "BarkDeskUITests-\(UUID().uuidString)"
        app.launchEnvironment["BARKDESK_KEYCHAIN_SERVICE"] = "app.barkdesk.ui-tests.\(UUID().uuidString)"
        app.launch()

        let startButton = app.buttons["开始设置"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.click()

        let serverField = app.textFields["onboarding.serverURL"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 3))
        serverField.click()
        serverField.typeText("https://keyboard-input.example.com")
        XCTAssertEqual(serverField.value as? String, "https://keyboard-input.example.com")

        let deviceKeyField = app.secureTextFields["onboarding.deviceKey"]
        XCTAssertTrue(deviceKeyField.waitForExistence(timeout: 3))
        deviceKeyField.click()
        deviceKeyField.typeText("keyboard-device-key")
        XCTAssertTrue(app.buttons["继续"].isEnabled)
    }
}
