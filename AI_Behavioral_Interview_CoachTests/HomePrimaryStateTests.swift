import XCTest
@testable import AI_Behavioral_Interview_Coach

final class HomePrimaryStateTests: XCTestCase {
    func testActiveSessionWinsOverReadyResumeAndNoCredits() {
        let snapshot = HomeSnapshot(
            activeResume: .readyUsable(fileName: "alex_pm_resume.pdf"),
            activeSession: TrainingSession.fixture(status: .redoAvailable),
            credits: UsageBalance(availableSessionCredits: 0),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .activeSession)
    }

    func testNoResumeShowsUpload() {
        let snapshot = HomeSnapshot(activeResume: nil, activeSession: nil, credits: .initialFree, recentPractice: [])

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .noResume)
    }

    func testReadyResumeWithNoCreditsShowsOutOfCredits() {
        let snapshot = HomeSnapshot(
            activeResume: .readyUsable(fileName: "alex_pm_resume.pdf"),
            activeSession: nil,
            credits: UsageBalance(availableSessionCredits: 0),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .outOfCredits)
    }

    func testUploadingResumeWithNoCreditsShowsResumeProcessing() {
        let snapshot = HomeSnapshot(
            activeResume: .uploading(fileName: "alex_pm_resume.pdf"),
            activeSession: nil,
            credits: UsageBalance(availableSessionCredits: 0),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .resumeProcessing)
    }

    func testParsingResumeWithNoCreditsShowsResumeProcessing() {
        let snapshot = HomeSnapshot(
            activeResume: .parsing(fileName: "alex_pm_resume.pdf"),
            activeSession: nil,
            credits: UsageBalance(availableSessionCredits: 0),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .resumeProcessing)
    }

    func testFailedResumeWithNoCreditsShowsResumeFailed() {
        let snapshot = HomeSnapshot(
            activeResume: .failed(fileName: "alex_pm_resume.pdf", reason: "Unsupported format"),
            activeSession: nil,
            credits: UsageBalance(availableSessionCredits: 0),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .resumeFailed)
    }

    func testUnusableResumeWithNoCreditsShowsResumeUnusable() {
        let snapshot = HomeSnapshot(
            activeResume: .unusable(fileName: "alex_pm_resume.pdf", reason: "Missing work history"),
            activeSession: nil,
            credits: UsageBalance(availableSessionCredits: 0),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .resumeUnusable)
    }

    func testReadyUsableResumeWithCreditsShowsReady() {
        let snapshot = HomeSnapshot(
            activeResume: .readyUsable(fileName: "alex_pm_resume.pdf"),
            activeSession: nil,
            credits: UsageBalance(availableSessionCredits: 1),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .ready)
    }

    func testLimitedReadyResumeShowsReadyLimitedWhenCreditsRemain() {
        let snapshot = HomeSnapshot(
            activeResume: .readyLimited(fileName: "alex_pm_resume.pdf"),
            activeSession: nil,
            credits: UsageBalance(availableSessionCredits: 1),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .readyLimited)
    }

    func testReadyLimitedResumeWithNoCreditsShowsOutOfCredits() {
        let snapshot = HomeSnapshot(
            activeResume: .readyLimited(fileName: "alex_pm_resume.pdf"),
            activeSession: nil,
            credits: UsageBalance(availableSessionCredits: 0),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .outOfCredits)
    }

    func testReadyUsableResumeWithNegativeCreditsShowsOutOfCredits() {
        let snapshot = HomeSnapshot(
            activeResume: .readyUsable(fileName: "alex_pm_resume.pdf"),
            activeSession: nil,
            credits: UsageBalance(availableSessionCredits: -1),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .outOfCredits)
    }
}
