import XCTest
@testable import AI_Behavioral_Interview_Coach

final class MockCoachServiceTests: XCTestCase {
    func testBootstrapStartsWithNoResumeAndTwoCredits() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)

        _ = try await service.bootstrap()
        let home = try await service.home()

        XCTAssertNil(home.activeResume)
        XCTAssertNil(home.activeSession)
        XCTAssertEqual(home.credits.availableSessionCredits, 2)
    }

    func testStartSessionBlocksWhenActiveSessionExists() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        _ = try await service.createTrainingSession(focus: .ownership)

        do {
            _ = try await service.createTrainingSession(focus: .prioritization)
            XCTFail("Expected active session error")
        } catch CoachServiceError.activeSessionExists {
            XCTAssertTrue(true)
        }
    }

    func testHappyPathConsumesOneCreditAndCreatesHistory() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        var session = try await service.createTrainingSession(focus: .ownership)

        XCTAssertEqual(session.status, .waitingFirstAnswer)

        session = try await service.submitFirstAnswer(sessionID: session.id)
        XCTAssertEqual(session.status, .waitingFollowupAnswer)

        session = try await service.submitFollowupAnswer(sessionID: session.id)
        XCTAssertEqual(session.status, .redoAvailable)

        let homeAfterFeedback = try await service.home()
        XCTAssertEqual(homeAfterFeedback.credits.availableSessionCredits, 1)

        session = try await service.skipRedo(sessionID: session.id)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.completionReason, .redoSkipped)

        let history = try await service.history()
        XCTAssertEqual(history.count, 1)
    }

    func testMockPurchaseAddsCredits() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        try await service.mockPurchaseSprintPack()

        let home = try await service.home()
        XCTAssertEqual(home.credits.availableSessionCredits, 7)
    }

    func testMockRestoreAddsCredits() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        try await service.mockRestorePurchase()

        let home = try await service.home()
        XCTAssertEqual(home.credits.availableSessionCredits, 7)
    }

    func testActiveSessionErrorWinsOverMissingResumeAndNoCredits() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")

        var session = try await service.createTrainingSession(focus: .ownership)
        session = try await service.submitFirstAnswer(sessionID: session.id)
        session = try await service.submitFollowupAnswer(sessionID: session.id)
        _ = try await service.skipRedo(sessionID: session.id)

        session = try await service.createTrainingSession(focus: .prioritization)
        session = try await service.submitFirstAnswer(sessionID: session.id)
        _ = try await service.submitFollowupAnswer(sessionID: session.id)
        _ = try await service.deleteResume(mode: .resumeOnlyRedactedHistory)

        do {
            _ = try await service.createTrainingSession(focus: .ambiguity)
            XCTFail("Expected active session error")
        } catch CoachServiceError.activeSessionExists {
            XCTAssertTrue(true)
        }
    }
}
