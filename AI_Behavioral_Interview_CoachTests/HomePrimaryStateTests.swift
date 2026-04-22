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

    func testLimitedReadyResumeShowsReadyLimitedWhenCreditsRemain() {
        let snapshot = HomeSnapshot(
            activeResume: .readyLimited(fileName: "alex_pm_resume.pdf"),
            activeSession: nil,
            credits: UsageBalance(availableSessionCredits: 1),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .readyLimited)
    }
}
