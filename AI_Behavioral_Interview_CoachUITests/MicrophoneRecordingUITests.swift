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
    func testFirstAnswerSubmissionReachesFollowupAndFeedback() throws {
        let app = makeReadyResumeApp()
        app.resetAuthorizationStatus(for: .microphone)

        reachFeedback(in: app)
        addScreenshot(named: "18-feedback-ready")
    }

    @MainActor
    func testRedoSubmissionCompletesAndAppearsInHistory() throws {
        let app = makeReadyResumeApp()
        app.resetAuthorizationStatus(for: .microphone)

        reachFeedback(in: app)
        app.buttons["Redo this answer"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Redo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["One guided redo"].exists)
        XCTAssertTrue(app.buttons["Start recording"].firstMatch.exists)

        recordCurrentAnswer(
            in: app,
            recordingText: "Recording your redo.",
            submitButtonTitle: "Submit redo"
        )
        app.buttons["Submit redo"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Practice complete"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Redo review"].exists)
        XCTAssertTrue(app.staticTexts["Clearer ownership signal."].exists)
        XCTAssertTrue(app.staticTexts["Partially improved"].exists)
        addScreenshot(named: "19-result-complete")

        app.buttons["Back home"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Last practice"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["View all history"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Redo reviewed")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Partially improved")).firstMatch.exists)
        addScreenshot(named: "20-home-history-after-redo")
    }

    @MainActor
    private func reachFeedback(in app: XCUIApplication) {
        startFirstAnswer(in: app)
        recordCurrentAnswer(in: app, systemPromptButtonIndex: 1)
        app.buttons["Submit answer"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Follow-up"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Answer the follow-up"].exists)
        XCTAssertTrue(app.buttons["Start recording"].firstMatch.exists)
        addScreenshot(named: "12-followup-ready")

        recordCurrentAnswer(in: app)
        app.buttons["Submit answer"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Feedback"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Biggest gap"].exists)
        XCTAssertTrue(app.staticTexts["Why it matters"].exists)
        XCTAssertTrue(app.staticTexts["Redo priority"].exists)
        XCTAssertTrue(app.staticTexts["You described the team outcome before making your personal decision clear."].exists)
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
    private func recordCurrentAnswer(
        in app: XCUIApplication,
        systemPromptButtonIndex: Int? = nil,
        recordingText: String = "Recording your answer.",
        submitButtonTitle: String = "Submit answer"
    ) {
        app.buttons["Start recording"].firstMatch.tap()

        if let systemPromptButtonIndex {
            tapSystemMicrophonePromptButton(at: systemPromptButtonIndex)
        }

        XCTAssertTrue(app.buttons["Stop recording"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[recordingText].exists)

        RunLoop.current.run(until: Date().addingTimeInterval(2.4))
        app.buttons["Stop recording"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Ready to submit."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[submitButtonTitle].firstMatch.exists)
    }

    @MainActor
    private func addScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
