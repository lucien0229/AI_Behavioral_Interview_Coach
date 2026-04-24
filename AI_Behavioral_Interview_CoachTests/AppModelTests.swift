import XCTest
@testable import AI_Behavioral_Interview_Coach

final class AppModelTests: XCTestCase {
    @MainActor
    func testActiveSessionExistsRefreshesHomeAndRoutesToActiveSession() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        let activeSession = try await service.createTrainingSession(focus: .ownership)
        let model = AppModel(service: service)
        XCTAssertNil(model.selectedFocus)

        await model.startTraining()

        XCTAssertEqual(model.homeSnapshot.activeSession?.id, activeSession.id)
        XCTAssertEqual(model.currentSession?.id, activeSession.id)
        XCTAssertEqual(model.navigationPath, [.trainingSession(sessionID: activeSession.id)])
        XCTAssertNil(model.activeSheet)
        XCTAssertNil(model.selectedFocus)
    }

    @MainActor
    func testStartTrainingWithoutSelectedFocusKeepsSelectionNil() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        let model = AppModel(service: service)

        await model.startTraining()

        XCTAssertNil(model.selectedFocus)
        XCTAssertEqual(model.currentSession?.focus, .ownership)
    }

    @MainActor
    func testConcurrentStartTrainingRoutesOnlyOnce() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 50_000_000)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        let model = AppModel(service: service)

        let firstStart = Task { @MainActor in
            await model.startTraining()
        }
        let secondStart = Task { @MainActor in
            await model.startTraining()
        }

        await firstStart.value
        await secondStart.value

        let route = try XCTUnwrap(model.currentSession.map { AppRoute.trainingSession(sessionID: $0.id) })
        XCTAssertEqual(model.navigationPath, [route])
    }

    @MainActor
    func testDeleteAllDataClearsTransientAppState() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        let activeSession = try await service.createTrainingSession(focus: .ownership)
        let model = AppModel(service: service)
        model.currentSession = activeSession
        model.activeSheet = .apiError("Before delete")
        model.history = [
            PracticeSummary(
                id: "session_1",
                title: "Practice",
                questionText: "Practice",
                focusLabel: "Ownership",
                completionDateText: "Apr 21",
                redoStatusText: "Complete",
                finalAssessmentSummary: "Saved"
            )
        ]
        model.navigationPath = [.trainingSession(sessionID: activeSession.id), .settings]
        model.selectedFocus = .ambiguity

        await model.deleteAllData()

        XCTAssertNil(model.currentSession)
        XCTAssertNil(model.activeSheet)
        XCTAssertEqual(model.history, [])
        XCTAssertEqual(model.navigationPath, [])
        XCTAssertNil(model.selectedFocus)
    }

    @MainActor
    func testBuySprintPackRefreshesCreditsAndDismissesSheet() async {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        let model = AppModel(service: service)
        await model.bootstrap()
        model.activeSheet = .paywall

        await model.buySprintPack()

        XCTAssertNil(model.activeSheet)
        XCTAssertEqual(model.homeSnapshot.credits.availableSessionCredits, 7)
    }

    @MainActor
    func testDeletePracticeRoutesBackToHistoryList() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        var session = try await service.createTrainingSession(focus: .ownership)
        session = try await service.submitFirstAnswer(sessionID: session.id, recording: .testFixture)
        session = try await service.submitFollowupAnswer(sessionID: session.id, recording: .testFixture)
        session = try await service.skipRedo(sessionID: session.id)

        let model = AppModel(service: service)
        model.currentSession = session
        model.navigationPath = [.historyDetail(sessionID: session.id)]

        await model.deletePractice(id: session.id)

        XCTAssertEqual(model.navigationPath, [.historyList])
        XCTAssertNil(model.currentSession)
        XCTAssertNil(model.activeSheet)
    }
}
