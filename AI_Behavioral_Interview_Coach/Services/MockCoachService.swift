import Foundation

actor MockCoachService: CoachService {
    private let processingDelayNanoseconds: UInt64
    private var bootstrapContext: BootstrapContext?
    private var activeResume: ActiveResume?
    private var credits = UsageBalance.initialFree
    private var activeSession: TrainingSession?
    private var completedSessions: [TrainingSession] = []

    init(processingDelayNanoseconds: UInt64 = 350_000_000) {
        self.processingDelayNanoseconds = processingDelayNanoseconds
    }

    func bootstrap() async throws -> BootstrapContext {
        try await simulateProcessingDelay()

        if let bootstrapContext {
            return bootstrapContext
        }

        let context = BootstrapContext(
            appUserID: "mock_user_alex",
            accessToken: "mock_access_token",
            appAccountToken: "mock_app_account_token"
        )
        bootstrapContext = context
        return context
    }

    func home() async throws -> HomeSnapshot {
        try requireBootstrap()
        try await simulateProcessingDelay()
        return homeSnapshot()
    }

    func uploadResume(fileName: String) async throws -> ActiveResume {
        try requireBootstrap()
        try validateResumeFileName(fileName)

        activeResume = .uploading(fileName: fileName)
        try await simulateProcessingDelay()
        activeResume = .parsing(fileName: fileName)
        try await simulateProcessingDelay()

        let resume = ActiveResume.readyUsable(fileName: fileName)
        activeResume = resume
        return resume
    }

    func deleteResume(mode: DeleteResumeMode) async throws -> HomeSnapshot {
        try requireBootstrap()
        try await simulateProcessingDelay()

        activeResume = nil

        if mode == .resumeAndLinkedTraining {
            activeSession = nil
            completedSessions.removeAll()
        }

        return homeSnapshot()
    }

    func createTrainingSession(focus: TrainingFocus) async throws -> TrainingSession {
        try requireBootstrap()

        guard activeSession == nil else {
            throw CoachServiceError.activeSessionExists
        }

        try requireReadyResume()

        guard credits.availableSessionCredits > 0 else {
            throw CoachServiceError.noCredits
        }

        let session = TrainingSession(
            id: "session_\(UUID().uuidString)",
            status: .questionGenerating,
            focus: focus,
            questionText: questionText(for: focus),
            followupText: nil,
            feedback: nil,
            redoReview: nil,
            completionReason: nil
        )
        activeSession = session
        try await simulateProcessingDelay()

        var readySession = session
        readySession.status = .waitingFirstAnswer
        activeSession = readySession
        return readySession
    }

    func session(id: String) async throws -> TrainingSession {
        try requireBootstrap()
        try await simulateProcessingDelay()

        if let activeSession, activeSession.id == id {
            return activeSession
        }

        guard let completedSession = completedSessions.first(where: { $0.id == id }) else {
            throw CoachServiceError.sessionNotFound
        }

        return completedSession
    }

    func submitFirstAnswer(sessionID: String) async throws -> TrainingSession {
        var session = try requireActiveSession(id: sessionID)

        guard session.status == .waitingFirstAnswer else {
            throw CoachServiceError.invalidSessionState
        }

        session.status = .firstAnswerProcessing
        activeSession = session
        try await simulateProcessingDelay()

        session.status = .followupGenerating
        activeSession = session
        try await simulateProcessingDelay()

        session.status = .waitingFollowupAnswer
        session.followupText = followupText(for: session.focus)
        activeSession = session
        return session
    }

    func submitFollowupAnswer(sessionID: String) async throws -> TrainingSession {
        var session = try requireActiveSession(id: sessionID)

        guard session.status == .waitingFollowupAnswer else {
            throw CoachServiceError.invalidSessionState
        }

        session.status = .followupAnswerProcessing
        activeSession = session
        try await simulateProcessingDelay()

        session.status = .feedbackGenerating
        activeSession = session
        try await simulateProcessingDelay()

        session.status = .redoAvailable
        session.feedback = mockFeedback
        activeSession = session
        credits.availableSessionCredits = max(0, credits.availableSessionCredits - 1)
        return session
    }

    func submitRedo(sessionID: String) async throws -> TrainingSession {
        var session = try requireActiveSession(id: sessionID)

        guard session.status == .redoAvailable else {
            throw CoachServiceError.invalidSessionState
        }

        session.status = .redoProcessing
        activeSession = session
        try await simulateProcessingDelay()

        session.status = .redoEvaluating
        activeSession = session
        try await simulateProcessingDelay()

        session.status = .completed
        session.redoReview = mockRedoReview
        session.completionReason = .redoReviewGenerated
        completeActiveSession(session)
        return session
    }

    func skipRedo(sessionID: String) async throws -> TrainingSession {
        var session = try requireActiveSession(id: sessionID)

        guard session.status == .redoAvailable else {
            throw CoachServiceError.invalidSessionState
        }

        try await simulateProcessingDelay()

        session.status = .completed
        session.completionReason = .redoSkipped
        completeActiveSession(session)
        return session
    }

    func history() async throws -> [PracticeSummary] {
        try requireBootstrap()
        try await simulateProcessingDelay()
        return completedSessions.map(practiceSummary)
    }

    func historyDetail(id: String) async throws -> TrainingSession {
        try requireBootstrap()
        try await simulateProcessingDelay()

        guard let session = completedSessions.first(where: { $0.id == id }) else {
            throw CoachServiceError.sessionNotFound
        }

        return session
    }

    func deletePractice(id: String) async throws -> [PracticeSummary] {
        try requireBootstrap()
        try await simulateProcessingDelay()

        guard let index = completedSessions.firstIndex(where: { $0.id == id }) else {
            throw CoachServiceError.sessionNotFound
        }

        completedSessions.remove(at: index)
        return completedSessions.map(practiceSummary)
    }

    func mockPurchaseSprintPack() async throws {
        try requireBootstrap()
        try await simulateProcessingDelay()
        credits.availableSessionCredits += 5
    }

    func mockRestorePurchase() async throws {
        try requireBootstrap()
        try await simulateProcessingDelay()
        credits.availableSessionCredits += 5
    }

    func deleteAllData() async throws -> BootstrapContext {
        try await simulateProcessingDelay()

        activeResume = nil
        credits = .initialFree
        activeSession = nil
        completedSessions.removeAll()

        let context = BootstrapContext(
            appUserID: "mock_user_alex",
            accessToken: "mock_access_token",
            appAccountToken: "mock_app_account_token"
        )
        bootstrapContext = context
        return context
    }
}

private extension MockCoachService {
    var mockFeedback: FeedbackPayload {
        FeedbackPayload(
            biggestGap: "You described the team outcome before making your personal decision clear.",
            whyItMatters: "Behavioral interviewers need to understand the judgment you owned, not just the project result.",
            redoPriority: "Lead with the decision you made, the tradeoff you accepted, and the measurable result.",
            redoOutline: [
                "Set the business context in one sentence.",
                "Name the decision you personally owned.",
                "Explain the tradeoff and why it mattered.",
                "Close with the result and what changed."
            ],
            strongestSignal: "The example has real scope and shows cross-functional pressure.",
            assessments: [
                AssessmentLine(id: "answer_fit", label: "Answer fit", status: .strong),
                AssessmentLine(id: "story", label: "Story", status: .strong),
                AssessmentLine(id: "personal_ownership", label: "Personal ownership", status: .weak),
                AssessmentLine(id: "evidence", label: "Evidence and outcome", status: .mixed)
            ]
        )
    }

    var mockRedoReview: RedoReviewPayload {
        RedoReviewPayload(
            status: .improved,
            headline: "Clearer ownership signal.",
            stillMissing: "The result would be stronger with one concrete metric.",
            nextAttempt: "Keep the same structure and add the before-and-after impact."
        )
    }

    func simulateProcessingDelay() async throws {
        guard processingDelayNanoseconds > 0 else {
            return
        }

        try await Task.sleep(nanoseconds: processingDelayNanoseconds)
    }

    func requireBootstrap() throws {
        guard bootstrapContext != nil else {
            throw CoachServiceError.notBootstrapped
        }
    }

    func validateResumeFileName(_ fileName: String) throws {
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        guard fileExtension == "pdf" || fileExtension == "docx" else {
            throw CoachServiceError.unsupportedFileType
        }
    }

    func requireReadyResume() throws {
        guard let activeResume else {
            throw CoachServiceError.resumeNotReady
        }

        switch activeResume {
        case .readyUsable, .readyLimited:
            return
        case .uploading, .parsing, .unusable, .failed:
            throw CoachServiceError.resumeNotReady
        }
    }

    func requireActiveSession(id: String) throws -> TrainingSession {
        try requireBootstrap()

        guard let activeSession, activeSession.id == id else {
            throw CoachServiceError.sessionNotFound
        }

        return activeSession
    }

    func completeActiveSession(_ session: TrainingSession) {
        activeSession = nil
        completedSessions.insert(session, at: 0)
    }

    func homeSnapshot() -> HomeSnapshot {
        HomeSnapshot(
            activeResume: activeResume,
            activeSession: activeSession,
            credits: credits,
            recentPractice: completedSessions.prefix(3).map(practiceSummary)
        )
    }

    func questionText(for focus: TrainingFocus) -> String {
        switch focus {
        case .ownership:
            return "Tell me about a time you personally took ownership of an ambiguous problem and drove it to resolution."
        case .prioritization:
            return "Tell me about a time you had to make a high-stakes prioritization decision with incomplete information."
        case .crossFunctionalInfluence:
            return "Tell me about a time you influenced cross-functional partners without direct authority."
        case .conflictHandling:
            return "Tell me about a time you handled a serious disagreement with a teammate or stakeholder."
        case .failureLearning:
            return "Tell me about a time you failed, what you learned, and how your behavior changed afterward."
        case .ambiguity:
            return "Tell me about a time you brought structure to an ambiguous problem."
        }
    }

    func followupText(for focus: TrainingFocus) -> String {
        switch focus {
        case .ownership:
            return "What specific decision did you personally make when the outcome was still uncertain?"
        case .prioritization:
            return "What tradeoff did you choose, and what did you intentionally deprioritize?"
        case .crossFunctionalInfluence:
            return "Which stakeholder changed their position because of your influence, and why?"
        case .conflictHandling:
            return "What did you say or do that moved the conflict toward a decision?"
        case .failureLearning:
            return "What concrete behavior changed in your next similar situation?"
        case .ambiguity:
            return "What signal did you use first to reduce the ambiguity?"
        }
    }

    func practiceSummary(for session: TrainingSession) -> PracticeSummary {
        PracticeSummary(
            id: session.id,
            title: session.focus.displayName,
            subtitle: session.questionText,
            status: session.completionReason?.rawValue ?? session.status.rawValue
        )
    }
}
