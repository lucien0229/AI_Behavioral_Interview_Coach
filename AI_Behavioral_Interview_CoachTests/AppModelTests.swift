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
    func testStartTrainingShowsSpecificGuidanceForUnusableResume() async throws {
        let service = PollingCoachService(createTrainingError: .resumeProfileUnusable)
        let model = AppModel(service: service)

        await model.startTraining()

        XCTAssertEqual(
            model.activeSheet,
            AppSheet.apiError("Your resume does not include enough interview-ready experience. Upload a more detailed resume to start training.")
        )
        XCTAssertNil(model.currentSession)
        XCTAssertTrue(model.navigationPath.isEmpty)
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

        let didSubmit = await model.submitFirstAnswer(recording: RecordedAudio.testFixture)

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
    func testTranscriptQualityErrorAsksForFirstAnswerRecordingAgain() async throws {
        let waitingSession = TrainingSession.fixture(status: .waitingFirstAnswer)
        let service = PollingCoachService(firstAnswerError: .transcriptQualityTooLow)
        let model = AppModel(service: service)
        model.currentSession = waitingSession

        let didSubmit = await model.submitFirstAnswer(recording: .testFixture)

        XCTAssertFalse(didSubmit)
        XCTAssertEqual(model.currentSession, waitingSession)
        XCTAssertEqual(
            model.activeSheet,
            AppSheet.apiError("We could not use that recording. Record again in English with a clear, complete answer.")
        )
    }

    @MainActor
    func testTranscriptionFailureAsksForFollowupRecordingAgain() async throws {
        let waitingSession = TrainingSession.fixture(status: .waitingFollowupAnswer)
        let service = PollingCoachService(followupAnswerError: .transcriptionFailed)
        let model = AppModel(service: service)
        model.currentSession = waitingSession

        let didSubmit = await model.submitFollowupAnswer(recording: RecordedAudio.testFixture)

        XCTAssertFalse(didSubmit)
        XCTAssertEqual(model.currentSession, waitingSession)
        XCTAssertEqual(
            model.activeSheet,
            AppSheet.apiError("We could not transcribe that recording. Record again in a quieter place.")
        )
    }

    @MainActor
    func testAudioUploadFailureKeepsRedoRecordingAvailableForRetry() async throws {
        let redoSession = TrainingSession.fixture(status: .redoAvailable)
        let service = PollingCoachService(redoError: .audioUploadFailed)
        let model = AppModel(service: service)
        model.currentSession = redoSession

        let didSubmit = await model.submitRedo(recording: RecordedAudio.testFixture)

        XCTAssertFalse(didSubmit)
        XCTAssertEqual(model.currentSession, redoSession)
        XCTAssertEqual(
            model.activeSheet,
            AppSheet.apiError("We could not upload that recording. Check your connection and try submitting again.")
        )
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
    func testAbandonCurrentSessionReleasesSessionAndRoutesHome() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        let activeSession = try await service.createTrainingSession(focus: .ownership)
        let analytics = RecordingAnalyticsService()
        let model = AppModel(service: service, analytics: analytics)
        model.currentSession = activeSession
        model.navigationPath = [.trainingSession(sessionID: activeSession.id)]

        await model.abandonCurrentSession()

        let home = try await service.home()
        let events = await analytics.events()
        XCTAssertNil(model.currentSession)
        XCTAssertNil(home.activeSession)
        XCTAssertEqual(home.credits.availableSessionCredits, 2)
        XCTAssertEqual(model.navigationPath, [])
        let abandoned = events.last { $0.name == "training_session_abandoned" }
        XCTAssertEqual(abandoned?.properties["session_id"], activeSession.id)
        XCTAssertEqual(abandoned?.properties["credit_state"], "released")
    }

    @MainActor
    func testAbandonCurrentTerminalSessionRoutesHomeWithoutCallingAbandon() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        var session = try await service.createTrainingSession(focus: .ownership)
        session = try await service.submitFirstAnswer(sessionID: session.id, recording: .testFixture)
        session = try await service.submitFollowupAnswer(sessionID: session.id, recording: .testFixture)
        session = try await service.submitRedo(sessionID: session.id, recording: .testFixture)
        let model = AppModel(service: service)
        model.currentSession = session
        model.navigationPath = [.trainingSession(sessionID: session.id)]

        await model.abandonCurrentSession()

        XCTAssertNil(model.currentSession)
        XCTAssertEqual(model.navigationPath, [])
        XCTAssertNil(model.activeSheet)
        XCTAssertEqual(model.homeSnapshot.recentPractice.map(\.id), [session.id])
    }

    @MainActor
    func testBootstrapTracksHomeViewedWithPrimaryState() async {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        let analytics = RecordingAnalyticsService()
        let model = AppModel(service: service, analytics: analytics)

        await model.bootstrap()

        let events = await analytics.events()
        XCTAssertEqual(events.map(\.name), [
            "app_bootstrap_started",
            "app_bootstrap_completed",
            "home_viewed"
        ])
        let homeViewed = try? XCTUnwrap(events.last)
        XCTAssertEqual(homeViewed?.properties["event_schema_version"], "analytics_v1")
        XCTAssertEqual(homeViewed?.properties["app_user_id"], "mock_user_alex")
        XCTAssertEqual(homeViewed?.properties["home_primary_state"], "noResume")
    }

    @MainActor
    func testTrainingFunnelTracksServerBackedCompletionInOrder() async {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        let analytics = RecordingAnalyticsService()
        let model = AppModel(service: service, analytics: analytics)

        await model.bootstrap()
        await model.uploadResume(fileName: "alex_pm_resume.pdf")
        await model.startTraining()
        _ = await model.submitFirstAnswer(recording: .testFixture)
        _ = await model.submitFollowupAnswer(recording: .testFixture)
        await model.trackFeedbackViewed()
        await model.skipRedo()

        let events = await analytics.events()
        XCTAssertContainsOrderedEventNames(
            events,
            [
                "training_session_create_started",
                "training_session_created",
                "question_viewed",
                "first_answer_submitted",
                "follow_up_viewed",
                "follow_up_answer_submitted",
                "feedback_generated",
                "feedback_viewed",
                "redo_skipped",
                "training_session_completed"
            ]
        )
        let completed = events.last { $0.name == "training_session_completed" }
        XCTAssertEqual(completed?.properties["completion_reason"], "redo_skipped")
    }

    @MainActor
    func testFeedbackViewedIsOnlyTrackedAfterExplicitViewExposure() async {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        let analytics = RecordingAnalyticsService()
        let model = AppModel(service: service, analytics: analytics)

        await model.bootstrap()
        await model.uploadResume(fileName: "alex_pm_resume.pdf")
        await model.startTraining()
        _ = await model.submitFirstAnswer(recording: .testFixture)
        _ = await model.submitFollowupAnswer(recording: .testFixture)

        var events = await analytics.events()
        XCTAssertFalse(events.contains { $0.name == "feedback_viewed" })

        await model.trackFeedbackViewed()

        events = await analytics.events()
        XCTAssertTrue(events.contains { $0.name == "feedback_viewed" })
    }

    @MainActor
    func testPurchaseVerifiedIsNotTrackedWhenPurchaseFails() async {
        let service = PollingCoachService(purchaseError: .purchaseVerificationFailed)
        let analytics = RecordingAnalyticsService()
        let model = AppModel(service: service, analytics: analytics)

        await model.buySprintPack()

        let events = await analytics.events()
        XCTAssertTrue(events.contains { $0.name == "purchase_started" })
        XCTAssertTrue(events.contains { $0.name == "purchase_failed" })
        XCTAssertFalse(events.contains { $0.name == "purchase_verified" })
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
    func testBuySprintPackShowsSpecificPurchaseFailureGuidance() async {
        let cases: [(error: CoachServiceError, message: String)] = [
            (.purchaseCancelled, "Purchase canceled."),
            (.purchasePending, "Purchase is pending approval."),
            (.purchaseVerificationFailed, "Purchase verification failed.")
        ]

        for testCase in cases {
            let service = PollingCoachService(purchaseError: testCase.error)
            let model = AppModel(service: service)

            await model.buySprintPack()

            XCTAssertEqual(model.activeSheet, .apiError(testCase.message))
        }
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

private func XCTAssertContainsOrderedEventNames(
    _ events: [AnalyticsEvent],
    _ expectedNames: [String],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    var searchStartIndex = events.startIndex

    for expectedName in expectedNames {
        guard let foundIndex = events[searchStartIndex...].firstIndex(where: { $0.name == expectedName }) else {
            XCTFail("Missing analytics event \(expectedName)", file: file, line: line)
            return
        }
        searchStartIndex = events.index(after: foundIndex)
    }
}

private actor RecordingAnalyticsService: AnalyticsService {
    private var capturedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) async {
        capturedEvents.append(event)
    }

    func reset() async {
        capturedEvents.removeAll()
    }

    func events() -> [AnalyticsEvent] {
        capturedEvents
    }
}

private actor PollingCoachService: CoachService {
    private let createdSession: TrainingSession?
    private let firstAnswerSession: TrainingSession?
    private let followupAnswerSession: TrainingSession?
    private let redoSession: TrainingSession?
    private let createTrainingError: CoachServiceError?
    private let firstAnswerError: CoachServiceError?
    private let followupAnswerError: CoachServiceError?
    private let redoError: CoachServiceError?
    private let purchaseError: CoachServiceError?
    private var queuedSessionResponses: [TrainingSession]
    private var requestedSessionIDs: [String] = []

    init(
        createdSession: TrainingSession? = nil,
        firstAnswerSession: TrainingSession? = nil,
        followupAnswerSession: TrainingSession? = nil,
        redoSession: TrainingSession? = nil,
        createTrainingError: CoachServiceError? = nil,
        firstAnswerError: CoachServiceError? = nil,
        followupAnswerError: CoachServiceError? = nil,
        redoError: CoachServiceError? = nil,
        purchaseError: CoachServiceError? = nil,
        sessionResponses: [TrainingSession] = []
    ) {
        self.createdSession = createdSession
        self.firstAnswerSession = firstAnswerSession
        self.followupAnswerSession = followupAnswerSession
        self.redoSession = redoSession
        self.createTrainingError = createTrainingError
        self.firstAnswerError = firstAnswerError
        self.followupAnswerError = followupAnswerError
        self.redoError = redoError
        self.purchaseError = purchaseError
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
        if let createTrainingError {
            throw createTrainingError
        }

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
        if let firstAnswerError {
            throw firstAnswerError
        }

        guard let firstAnswerSession else {
            throw CoachServiceError.mockFailure(message: "Missing first answer session")
        }
        return firstAnswerSession
    }

    func submitFollowupAnswer(sessionID: String, recording: RecordedAudio) async throws -> TrainingSession {
        if let followupAnswerError {
            throw followupAnswerError
        }

        guard let followupAnswerSession else {
            throw CoachServiceError.mockFailure(message: "Missing follow-up answer session")
        }
        return followupAnswerSession
    }

    func submitRedo(sessionID: String, recording: RecordedAudio) async throws -> TrainingSession {
        if let redoError {
            throw redoError
        }

        guard let redoSession else {
            throw CoachServiceError.mockFailure(message: "Missing redo session")
        }
        return redoSession
    }

    func skipRedo(sessionID: String) async throws -> TrainingSession {
        TrainingSession.fixture(status: .completed)
    }

    func abandonSession(sessionID: String) async throws -> TrainingSession {
        TrainingSession.fixture(status: .abandoned)
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

    func purchaseSprintPack() async throws {
        if let purchaseError {
            throw purchaseError
        }
    }

    func restorePurchase() async throws {
    }

    func deleteAllData() async throws -> BootstrapContext {
        try await bootstrap()
    }
}
