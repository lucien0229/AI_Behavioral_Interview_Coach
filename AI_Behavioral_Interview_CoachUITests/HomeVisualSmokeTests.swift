import XCTest

final class HomeVisualSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomePrivacyAndResumeEntryRenderOnIPhone() throws {
        let app = XCUIApplication()
        app.launch()

        let uploadResumeButton = app.buttons["Upload resume"]
        XCTAssertTrue(uploadResumeButton.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Interview Coach"].exists)
        XCTAssertTrue(app.staticTexts["Resume required to begin"].exists)
        XCTAssertTrue(app.staticTexts["Upload your resume to start"].exists)
        XCTAssertTrue(app.buttons["Privacy"].exists)

        addScreenshot(named: "01-home-no-resume")

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Data & privacy"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(identifier: "Back").count, 1)
        addScreenshot(named: "24-settings")
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Interview Coach"].waitForExistence(timeout: 3))

        app.buttons["Privacy"].tap()
        XCTAssertTrue(app.staticTexts["Privacy notice"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["What we use"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "Back").count, 1)
        addScreenshot(named: "25-privacy-notice")

        app.launch()
        let relaunchedUploadResumeButton = app.buttons["Upload resume"]
        XCTAssertTrue(relaunchedUploadResumeButton.waitForExistence(timeout: 8))
        relaunchedUploadResumeButton.tap()
        XCTAssertTrue(app.staticTexts["Upload your resume"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Choose file"].exists)
        XCTAssertTrue(app.buttons["Privacy notice"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "Back").count, 1)
        addScreenshot(named: "06-resume-upload")
    }

    @MainActor
    private func addScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
