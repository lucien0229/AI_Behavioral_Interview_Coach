import XCTest

final class MicrophoneRecordingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstAnswerRecordingCanBeCapturedAfterMicrophoneAllowed() throws {
        let app = makeReadyResumeApp()
        app.resetAuthorizationStatus(for: .microphone)

        startFirstAnswer(in: app)
        app.buttons["Start recording"].firstMatch.tap()
        tapSystemMicrophonePromptButton(at: 1)

        XCTAssertTrue(app.buttons["Stop recording"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recording your answer."].exists)

        RunLoop.current.run(until: Date().addingTimeInterval(2.4))
        app.buttons["Stop recording"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Ready to submit."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Submit answer"].firstMatch.exists)
        addScreenshot(named: "11-first-answer-recorded")
    }

    @MainActor
    func testMicrophoneDeniedShowsPermissionGuidance() throws {
        let app = makeReadyResumeApp()
        app.resetAuthorizationStatus(for: .microphone)

        startFirstAnswer(in: app)
        app.buttons["Start recording"].firstMatch.tap()
        tapSystemMicrophonePromptButton(at: 0)

        XCTAssertTrue(app.staticTexts["Allow microphone access"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Answer out loud for this version. Text input is not the main path."].exists)
        XCTAssertTrue(app.buttons["Continue"].exists)
        addScreenshot(named: "26-microphone-permission-sheet")
    }

    @MainActor
    private func makeReadyResumeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["AIBIC_UI_TEST_READY_RESUME"] = "1"
        app.launchEnvironment["AIBIC_UI_TEST_FAST"] = "1"
        app.launchEnvironment["AIBIC_UI_TEST_FAKE_AUDIO"] = "1"
        return app
    }

    @MainActor
    private func startFirstAnswer(in app: XCUIApplication) {
        app.launch()

        let startTrainingButton = app.buttons["Start training"]
        XCTAssertTrue(startTrainingButton.waitForExistence(timeout: 8))
        startTrainingButton.tap()

        XCTAssertTrue(app.staticTexts["Your first answer"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Start recording"].firstMatch.exists)
    }

    @MainActor
    private func tapSystemMicrophonePromptButton(at index: Int) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let microphonePrompt = springboard.alerts.firstMatch
        XCTAssertTrue(microphonePrompt.waitForExistence(timeout: 5))

        let button = microphonePrompt.buttons.element(boundBy: index)
        XCTAssertTrue(button.exists)
        button.tap()
    }

    @MainActor
    private func addScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
