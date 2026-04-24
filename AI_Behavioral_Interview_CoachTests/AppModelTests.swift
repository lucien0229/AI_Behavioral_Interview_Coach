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
    func testStartTrainingPollsQuestionGeneratingSessionUntilFirstAnswerReady() async throws {
        let processingSession = TrainingSession.fixture(status: .questionGenerating)
        let readySession = TrainingSession.fixture(status: .waitingFirstAnswer)
        let service = PollingCoachService(
            createdSession: processingSession,
            sessionResponses: [readySession]
        )
        let model = AppModel(service: service)

        await model.startTraining()

        let sessionRequestIDs = await service.sessionRequestIDs()
        XCTAssertEqual(model.currentSession?.status, .waitingFirstAnswer)
        XCTAssertEqual(model.navigationPath, [.trainingSession(sessionID: processingSession.id)])
        XCTAssertEqual(sessionRequestIDs, [processingSession.id])
    }

    @MainActor
    func testLoadSessionPollsProcessingSessionUntilFirstAnswerReady() async throws {
        let processingSession = TrainingSession.fixture(status: .questionGenerating)
        let readySession = TrainingSession.fixture(status: .waitingFirstAnswer)
        let service = PollingCoachService(
            sessionResponses: [processingSession, readySession]
        )
        let model = AppModel(service: service)

        await model.loadSession(id: processingSession.id)

        let sessionRequestIDs = await service.sessionRequestIDs()
        XCTAssertEqual(model.currentSession?.status, .waitingFirstAnswer)
        XCTAssertEqual(sessionRequestIDs, [processingSession.id, processingSession.id])
    }

    @MainActor
    func testSubmitFirstAnswerPollsProcessingSessionUntilFollowupReady() async throws {
        let waitingSession = TrainingSession.fixture(status: .waitingFirstAnswer)
        let processingSession = TrainingSession.fixture(status: .firstAnswerProcessing)
        let readySession = TrainingSession.fixture(status: .waitingFollowupAnswer)
        let service = PollingCoachService(
            firstAnswerSession: processingSession,
            sessionResponses: [readySession]
        )
        let model = AppModel(service: service)
        model.currentSession = waitingSession

        let didSubmit = await model.submitFirstAnswer(recording: .testFixture)

        let sessionRequestIDs = await service.sessionRequestIDs()
        XCTAssertTrue(didSubmit)
        XCTAssertEqual(model.currentSession?.status, .waitingFollowupAnswer)
        XCTAssertEqual(sessionRequestIDs, [waitingSession.id])
    }

    @MainActor
    func testSubmitFollowupAnswerPollsProcessingSessionUntilFeedbackReady() async throws {
        let waitingSession = TrainingSession.fixture(status: .waitingFollowupAnswer)
        let processingSession = TrainingSession.fixture(status: .feedbackGenerating)
        let readySession = TrainingSession.fixture(status: .redoAvailable)
        let service = PollingCoachService(
            followupAnswerSession: processingSession,
            sessionResponses: [readySession]
        )
        let model = AppModel(service: service)
        model.currentSession = waitingSession

        let didSubmit = await model.submitFollowupAnswer(recording: .testFixture)

        let sessionRequestIDs = await service.sessionRequestIDs()
        XCTAssertTrue(didSubmit)
        XCTAssertEqual(model.currentSession?.status, .redoAvailable)
        XCTAssertEqual(sessionRequestIDs, [waitingSession.id])
    }

    @MainActor
    func testSubmitRedoPollsProcessingSessionUntilCompleted() async throws {
        let redoSession = TrainingSession.fixture(status: .redoAvailable)
        let processingSession = TrainingSession.fixture(status: .redoEvaluating)
        let completedSession = TrainingSession.fixture(status: .completed)
        let service = PollingCoachService(
            redoSession: processingSession,
            sessionResponses: [completedSession]
        )
        let model = AppModel(service: service)
        model.currentSession = redoSession

        let didSubmit = await model.submitRedo(recording: .testFixture)

        let sessionRequestIDs = await service.sessionRequestIDs()
        XCTAssertTrue(didSubmit)
        XCTAssertEqual(model.currentSession?.status, .completed)
        XCTAssertEqual(sessionRequestIDs, [redoSession.id])
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

private actor PollingCoachService: CoachService {
    private let createdSession: TrainingSession?
    private let firstAnswerSession: TrainingSession?
    private let followupAnswerSession: TrainingSession?
    private let redoSession: TrainingSession?
    private var queuedSessionResponses: [TrainingSession]
    private var requestedSessionIDs: [String] = []

    init(
        createdSession: TrainingSession? = nil,
        firstAnswerSession: TrainingSession? = nil,
        followupAnswerSession: TrainingSession? = nil,
        redoSession: TrainingSession? = nil,
        sessionResponses: [TrainingSession] = []
    ) {
        self.createdSession = createdSession
        self.firstAnswerSession = firstAnswerSession
        self.followupAnswerSession = followupAnswerSession
        self.redoSession = redoSession
        queuedSessionResponses = sessionResponses
    }

    func sessionRequestIDs() -> [String] {
        requestedSessionIDs
    }

    func bootstrap() async throws -> BootstrapContext {
        BootstrapContext(
            appUserID: "test-user",
            accessToken: "test-token",
            appAccountToken: "test-account-token"
        )
    }

    func home() async throws -> HomeSnapshot {
        HomeSnapshot(activeResume: .readyUsable(fileName: "resume.pdf"), activeSession: nil, credits: .initialFree, recentPractice: [])
    }

    func uploadResume(fileName: String) async throws -> ActiveResume {
        .readyUsable(fileName: fileName)
    }

    func deleteResume(mode: DeleteResumeMode) async throws -> HomeSnapshot {
        try await home()
    }

    func createTrainingSession(focus: TrainingFocus?) async throws -> TrainingSession {
        guard let createdSession else {
            throw CoachServiceError.mockFailure(message: "Missing created session")
        }
        return createdSession
    }

    func session(id: String) async throws -> TrainingSession {
        requestedSessionIDs.append(id)
        guard !queuedSessionResponses.isEmpty else {
            throw CoachServiceError.sessionNotFound
        }
        return queuedSessionResponses.removeFirst()
    }

    func submitFirstAnswer(sessionID: String, recording: RecordedAudio) async throws -> TrainingSession {
        guard let firstAnswerSession else {
            throw CoachServiceError.mockFailure(message: "Missing first answer session")
        }
        return firstAnswerSession
    }

    func submitFollowupAnswer(sessionID: String, recording: RecordedAudio) async throws -> TrainingSession {
        guard let followupAnswerSession else {
            throw CoachServiceError.mockFailure(message: "Missing follow-up answer session")
        }
        return followupAnswerSession
    }

    func submitRedo(sessionID: String, recording: RecordedAudio) async throws -> TrainingSession {
        guard let redoSession else {
            throw CoachServiceError.mockFailure(message: "Missing redo session")
        }
        return redoSession
    }

    func skipRedo(sessionID: String) async throws -> TrainingSession {
        TrainingSession.fixture(status: .completed)
    }

    func history() async throws -> [PracticeSummary] {
        []
    }

    func historyDetail(id: String) async throws -> TrainingSession {
        try await session(id: id)
    }

    func deletePractice(id: String) async throws -> [PracticeSummary] {
        []
    }

    func mockPurchaseSprintPack() async throws {
    }

    func mockRestorePurchase() async throws {
    }

    func deleteAllData() async throws -> BootstrapContext {
        try await bootstrap()
    }
}
