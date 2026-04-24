import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private let service: any CoachService
    private let analytics: any AnalyticsService
    private let maxSessionPollAttempts = 25
    private let analyticsDeviceSessionID: String
    private let analyticsEnvironment: String
    private let appVersion: String
    private let localeIdentifier: String
    private var appUserID: String?
    private var trackedExposureEvents: Set<String> = []

    var isBootstrapping = true
    var homeSnapshot = HomeSnapshot(activeResume: nil, activeSession: nil, credits: .initialFree, recentPractice: [])
    var navigationPath: [AppRoute] = []
    var activeSheet: AppSheet?
    var selectedFocus: TrainingFocus?
    var currentSession: TrainingSession?
    var history: [PracticeSummary] = []

    init(
        service: any CoachService,
        analytics: any AnalyticsService = AnalyticsPipeline(),
        analyticsEnvironment: String = ProcessInfo.processInfo.environment["AIBIC_ANALYTICS_ENVIRONMENT"] ?? "development",
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
        localeIdentifier: String = Locale.current.identifier,
        analyticsDeviceSessionID: String = UUID().uuidString
    ) {
        self.service = service
        self.analytics = analytics
        self.analyticsEnvironment = analyticsEnvironment
        self.appVersion = appVersion
        self.localeIdentifier = localeIdentifier
        self.analyticsDeviceSessionID = analyticsDeviceSessionID
    }

    var homePrimaryState: HomePrimaryState {
        HomePrimaryState.derive(from: homeSnapshot)
    }

    func bootstrap() async {
        isBootstrapping = true
        do {
            await trackAnalytics("app_bootstrap_started")
            let context = try await service.bootstrap()
            appUserID = context.appUserID
            await trackAnalytics("app_bootstrap_completed")
            homeSnapshot = try await service.home()
            await trackHomeViewed()
        } catch {
            await trackAnalytics("app_bootstrap_failed", properties: analyticsErrorProperties(error))
            await trackAPIError(error, operation: "bootstrap", endpoint: "/app-users/bootstrap")
            activeSheet = .apiError("We could not prepare your practice space. Please try again.")
        }
        isBootstrapping = false
    }

    func refreshHome() async {
        do {
            homeSnapshot = try await service.home()
            history = try await service.history()
            await trackHomeViewed()
        } catch {
            await trackAPIError(error, operation: "refresh_home", endpoint: "/home")
            activeSheet = .apiError("We could not refresh your latest practice state.")
        }
    }

    func uploadResume(fileName: String) async {
        do {
            await trackAnalytics("resume_upload_started", properties: ["file_type": fileType(for: fileName), "source_language": "en"])
            _ = try await service.uploadResume(fileName: fileName)
            await trackAnalytics("resume_upload_completed", properties: ["file_type": fileType(for: fileName), "source_language": "en"], emittedBy: "server")
            guard !Task.isCancelled else { return }
            homeSnapshot = try await service.home()
            if case .readyUsable = homeSnapshot.activeResume {
                await trackAnalytics("resume_parse_completed", properties: ["profile_quality_status": "usable"], emittedBy: "server")
            }
            await trackHomeViewed()
            guard !Task.isCancelled else { return }
            navigationPath.append(.resumeManage)
        } catch is CancellationError {
            return
        } catch CoachServiceError.unsupportedFileType {
            await trackAPIError(CoachServiceError.unsupportedFileType, operation: "upload_resume", endpoint: "/resumes")
            activeSheet = .apiError("Only PDF or DOCX resumes are supported in this version.")
        } catch CoachServiceError.resumeParseFailed {
            await trackAnalytics("resume_parse_failed", properties: analyticsErrorProperties(CoachServiceError.resumeParseFailed), emittedBy: "server")
            await trackAPIError(CoachServiceError.resumeParseFailed, operation: "upload_resume", endpoint: "/resumes")
            activeSheet = .apiError("Resume upload failed. Please choose another file.")
        } catch CoachServiceError.resumeProfileUnusable {
            await trackAnalytics("resume_profile_unusable", properties: ["profile_quality_status": "unusable"], emittedBy: "server")
            await trackAPIError(CoachServiceError.resumeProfileUnusable, operation: "upload_resume", endpoint: "/resumes")
            activeSheet = .apiError("Resume upload failed. Please choose another file.")
        } catch {
            await trackAPIError(error, operation: "upload_resume", endpoint: "/resumes")
            activeSheet = .apiError("Resume upload failed. Please choose another file.")
        }
    }

    func startTraining() async {
        await startTraining(focus: selectedFocus)
    }

    func startTrainingWithoutFocus() async {
        await startTraining(focus: nil)
    }

    private func startTraining(focus: TrainingFocus?) async {
        do {
            if let focus {
                await trackAnalytics("training_focus_selected", properties: ["training_focus": focus.rawValue])
            }
            await trackAnalytics("training_session_create_started", properties: trainingProperties(focus: focus))
            let session = try await service.createTrainingSession(focus: focus)
            await trackSessionEvent("training_session_created", session: session, emittedBy: "server", extraProperties: ["credit_state": "reserved"])
            currentSession = session
            routeToTrainingSession(id: session.id)
            currentSession = try await pollSessionUntilDisplayable(session)
            homeSnapshot = try await service.home()
            await trackHomeViewed()
            await trackVisibleSessionStepIfNeeded(currentSession)
        } catch is CancellationError {
            return
        } catch CoachServiceError.noCredits {
            await trackAnalytics("training_session_create_failed", properties: analyticsErrorProperties(CoachServiceError.noCredits).merging(trainingProperties(focus: focus)) { current, _ in current })
            await trackAPIError(CoachServiceError.noCredits, operation: "create_training_session", endpoint: "/training-sessions")
            await trackAnalytics("paywall_viewed", properties: ["paywall_reason": "insufficient_credits"])
            activeSheet = .paywall
        } catch CoachServiceError.resumeProfileUnusable {
            await trackAnalytics("training_session_create_failed", properties: analyticsErrorProperties(CoachServiceError.resumeProfileUnusable).merging(trainingProperties(focus: focus)) { current, _ in current })
            await trackAPIError(CoachServiceError.resumeProfileUnusable, operation: "create_training_session", endpoint: "/training-sessions")
            activeSheet = .apiError("Your resume does not include enough interview-ready experience. Upload a more detailed resume to start training.")
        } catch CoachServiceError.activeSessionExists {
            do {
                await trackAnalytics("training_session_create_failed", properties: analyticsErrorProperties(CoachServiceError.activeSessionExists).merging(["active_session_exists": "true"]) { current, _ in current })
                await trackAPIError(CoachServiceError.activeSessionExists, operation: "create_training_session", endpoint: "/training-sessions")
                homeSnapshot = try await service.home()
                guard let activeSession = homeSnapshot.activeSession else {
                    activeSheet = .apiError("We could not find your active practice round.")
                    return
                }
                currentSession = activeSession
                routeToTrainingSession(id: activeSession.id)
                currentSession = try await pollSessionUntilDisplayable(activeSession)
                await trackVisibleSessionStepIfNeeded(currentSession)
            } catch is CancellationError {
                return
            } catch {
                await trackAPIError(error, operation: "load_active_session", endpoint: "/home")
                activeSheet = .apiError("We could not start this practice round.")
            }
        } catch {
            await trackAnalytics("training_session_create_failed", properties: analyticsErrorProperties(error).merging(trainingProperties(focus: focus)) { current, _ in current })
            await trackAPIError(error, operation: "create_training_session", endpoint: "/training-sessions")
            activeSheet = .apiError("We could not start this practice round.")
        }
    }

    func loadSession(id: String) async {
        do {
            let session = try await service.session(id: id)
            currentSession = session
            currentSession = try await pollSessionUntilDisplayable(session)
            await trackVisibleSessionStepIfNeeded(currentSession)
        } catch is CancellationError {
            return
        } catch {
            await trackAPIError(error, operation: "load_session", endpoint: "/training-sessions/{session_id}")
            activeSheet = .apiError("We could not load this practice round.")
        }
    }

    func submitFirstAnswer(recording: RecordedAudio) async -> Bool {
        guard let currentSession else { return false }
        do {
            let session = try await service.submitFirstAnswer(sessionID: currentSession.id, recording: recording)
            await trackSessionEvent(
                "first_answer_submitted",
                session: session,
                emittedBy: "server",
                extraProperties: answerProperties(step: "first_answer", recording: recording)
            )
            self.currentSession = session
            self.currentSession = try await pollSessionUntilDisplayable(session)
            await trackVisibleSessionStepIfNeeded(self.currentSession)
            return true
        } catch is CancellationError {
            return false
        } catch {
            await trackAnswerFailure(error, step: "first_answer", operation: "submit_first_answer", endpoint: "/training-sessions/{session_id}/first-answer")
            return handleRecordingSubmitFailure(error, fallbackMessage: "We could not submit your answer. Please try again.")
        }
    }

    func submitFollowupAnswer(recording: RecordedAudio) async -> Bool {
        guard let currentSession else { return false }
        do {
            let session = try await service.submitFollowupAnswer(sessionID: currentSession.id, recording: recording)
            await trackSessionEvent(
                "follow_up_answer_submitted",
                session: session,
                emittedBy: "server",
                extraProperties: answerProperties(step: "follow_up_answer", recording: recording)
            )
            self.currentSession = session
            self.currentSession = try await pollSessionUntilDisplayable(session)
            if self.currentSession?.feedback != nil {
                await trackSessionEvent("feedback_generated", session: self.currentSession, emittedBy: "server")
            }
            do {
                homeSnapshot = try await service.home()
                await trackHomeViewed()
            } catch {
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            await trackAnswerFailure(error, step: "follow_up_answer", operation: "submit_follow_up_answer", endpoint: "/training-sessions/{session_id}/follow-up-answer")
            return handleRecordingSubmitFailure(error, fallbackMessage: "We could not submit your follow-up answer. Please try again.")
        }
    }

    func submitRedo(recording: RecordedAudio) async -> Bool {
        guard let currentSession else { return false }
        do {
            let session = try await service.submitRedo(sessionID: currentSession.id, recording: recording)
            await trackSessionEvent(
                "redo_submitted",
                session: session,
                emittedBy: "server",
                extraProperties: answerProperties(step: "redo_answer", recording: recording)
            )
            self.currentSession = session
            self.currentSession = try await pollSessionUntilDisplayable(session)
            if self.currentSession?.redoReview != nil {
                await trackSessionEvent("redo_review_generated", session: self.currentSession, emittedBy: "server")
            }
            await trackCompletionIfNeeded(self.currentSession)
            await refreshHome()
            return true
        } catch is CancellationError {
            return false
        } catch {
            await trackAnswerFailure(error, step: "redo_answer", operation: "submit_redo", endpoint: "/training-sessions/{session_id}/redo")
            return handleRecordingSubmitFailure(error, fallbackMessage: "We could not evaluate your redo. Your original feedback is saved.")
        }
    }

    func skipRedo() async {
        guard let currentSession else { return }
        do {
            self.currentSession = try await service.skipRedo(sessionID: currentSession.id)
            await trackSessionEvent("redo_skipped", session: self.currentSession, emittedBy: "server")
            await trackCompletionIfNeeded(self.currentSession)
            await refreshHome()
        } catch {
            await trackAPIError(error, operation: "skip_redo", endpoint: "/training-sessions/{session_id}/skip-redo")
            activeSheet = .apiError("We could not finish this round. Please try again.")
        }
    }

    func abandonCurrentSession() async {
        guard let currentSession else {
            navigationPath.removeAll()
            await refreshHome()
            return
        }

        guard currentSession.status.canAbandonBeforeFeedback else {
            if currentSession.isTerminal {
                self.currentSession = nil
            }
            navigationPath.removeAll()
            await refreshHome()
            return
        }

        do {
            let abandonedSession = try await service.abandonSession(sessionID: currentSession.id)
            await trackSessionEvent(
                "training_session_abandoned",
                session: abandonedSession,
                emittedBy: "server",
                extraProperties: ["credit_state": "released", "abandon_reason": "user_back_home"]
            )
            self.currentSession = nil
            navigationPath.removeAll()
            await refreshHome()
        } catch CoachServiceError.invalidSessionState {
            navigationPath.removeAll()
            await refreshHome()
        } catch {
            await trackAPIError(error, operation: "abandon_session", endpoint: "/training-sessions/{session_id}/abandon")
            activeSheet = .apiError("We could not end this practice round. Please try again.")
        }
    }

    func buySprintPack() async {
        do {
            await trackAnalytics("purchase_started")
            try await service.purchaseSprintPack()
            await trackAnalytics("purchase_verified", emittedBy: "server")
            activeSheet = nil
            await refreshHome()
        } catch CoachServiceError.purchaseCancelled {
            await trackAnalytics("purchase_failed", properties: analyticsErrorProperties(CoachServiceError.purchaseCancelled))
            activeSheet = .apiError("Purchase canceled.")
        } catch CoachServiceError.purchasePending {
            await trackAnalytics("purchase_failed", properties: analyticsErrorProperties(CoachServiceError.purchasePending))
            activeSheet = .apiError("Purchase is pending approval.")
        } catch CoachServiceError.purchaseVerificationFailed {
            await trackAnalytics("purchase_failed", properties: analyticsErrorProperties(CoachServiceError.purchaseVerificationFailed))
            await trackAPIError(CoachServiceError.purchaseVerificationFailed, operation: "purchase_sprint_pack", endpoint: "/billing/apple/verify")
            activeSheet = .apiError("Purchase verification failed.")
        } catch {
            await trackAnalytics("purchase_failed", properties: analyticsErrorProperties(error))
            await trackAPIError(error, operation: "purchase_sprint_pack", endpoint: "/billing/apple/verify")
            activeSheet = .apiError("Purchase could not be completed.")
        }
    }

    func restorePurchase() async {
        do {
            try await service.restorePurchase()
            await trackAnalytics("purchase_restored", emittedBy: "server")
            activeSheet = nil
            await refreshHome()
        } catch {
            await trackAnalytics("purchase_failed", properties: analyticsErrorProperties(error))
            await trackAPIError(error, operation: "restore_purchase", endpoint: "/billing/apple/restore")
            activeSheet = .apiError("Purchase restore could not be completed.")
        }
    }

    func deleteResume(mode: DeleteResumeMode) async {
        do {
            let nextHomeSnapshot = try await service.deleteResume(mode: mode)
            await trackAnalytics("resume_delete_completed", properties: ["delete_mode": deleteModeAnalyticsValue(mode)], emittedBy: "server")
            homeSnapshot = nextHomeSnapshot
            history = try await service.history()
            await trackHomeViewed()

            if let currentSession, !currentSession.isTerminal {
                self.currentSession = nextHomeSnapshot.activeSession
            }

            navigationPath.removeAll()
            activeSheet = nil
        } catch {
            await trackAPIError(error, operation: "delete_resume", endpoint: "/resumes/active")
            activeSheet = .apiError("We could not delete your resume.")
        }
    }

    func deletePractice(id: String) async {
        do {
            history = try await service.deletePractice(id: id)
            await trackAnalytics("training_session_delete_completed", properties: ["session_id": id], emittedBy: "server")
            homeSnapshot = try await service.home()
            await trackHomeViewed()

            if currentSession?.id == id {
                currentSession = nil
            }

            navigationPath = [.historyList]

            activeSheet = nil
        } catch {
            await trackAPIError(error, operation: "delete_practice", endpoint: "/training-sessions/{session_id}")
            activeSheet = .apiError("We could not delete this practice round.")
        }
    }

    func deleteAllData() async {
        do {
            _ = try await service.deleteAllData()
            await trackAnalytics("user_data_delete_completed", emittedBy: "server")
            await analytics.reset()
            navigationPath.removeAll()
            currentSession = nil
            history = []
            selectedFocus = nil
            homeSnapshot = HomeSnapshot(activeResume: nil, activeSession: nil, credits: .initialFree, recentPractice: [])
            activeSheet = nil
            isBootstrapping = true
            await bootstrap()
        } catch {
            await trackAPIError(error, operation: "delete_all_data", endpoint: "/app-users/me/data")
            activeSheet = .apiError("We could not delete your app data.")
        }
    }

    func trackFeedbackViewed() async {
        guard let currentSession, currentSession.feedback != nil else {
            return
        }

        await trackSessionExposure("feedback_viewed", session: currentSession)
    }

    func trackRedoReviewViewed() async {
        guard let currentSession, currentSession.redoReview != nil else {
            return
        }

        await trackSessionExposure("redo_review_viewed", session: currentSession)
    }

    func trackRecordingStarted(eventName: String) async {
        await trackSessionEvent(eventName, session: currentSession)
    }

    private func routeToTrainingSession(id: String) {
        let route = AppRoute.trainingSession(sessionID: id)
        guard navigationPath.last != route else {
            return
        }
        navigationPath.append(route)
    }

    private func trackHomeViewed() async {
        await trackAnalytics("home_viewed", properties: ["home_primary_state": homePrimaryState.analyticsValue])
    }

    private func trackVisibleSessionStepIfNeeded(_ session: TrainingSession?) async {
        guard let session else { return }

        switch session.status {
        case .waitingFirstAnswer:
            await trackSessionExposure("question_viewed", session: session)
        case .waitingFollowupAnswer:
            await trackSessionExposure("follow_up_viewed", session: session)
        case .questionGenerating, .firstAnswerProcessing, .followupGenerating, .followupAnswerProcessing, .feedbackGenerating, .redoAvailable, .redoProcessing, .redoEvaluating, .completed, .abandoned, .failed:
            return
        }
    }

    private func trackSessionExposure(_ eventName: String, session: TrainingSession) async {
        let key = "\(eventName):\(session.id)"
        guard trackedExposureEvents.insert(key).inserted else {
            return
        }

        await trackSessionEvent(eventName, session: session)
    }

    private func trackCompletionIfNeeded(_ session: TrainingSession?) async {
        guard let session, session.status == .completed else {
            return
        }

        await trackSessionEvent(
            "training_session_completed",
            session: session,
            emittedBy: "server",
            extraProperties: ["completion_reason": session.completionReason?.rawValue ?? "unknown"]
        )
    }

    private func trackSessionEvent(
        _ eventName: String,
        session: TrainingSession?,
        emittedBy: String = "client",
        extraProperties: [String: String] = [:]
    ) async {
        guard let session else {
            await trackAnalytics(eventName, properties: extraProperties, emittedBy: emittedBy)
            return
        }

        var properties = extraProperties
        properties["session_id"] = session.id
        properties["training_focus"] = session.focus.rawValue
        properties["session_status"] = session.status.rawValue
        await trackAnalytics(eventName, properties: properties, emittedBy: emittedBy)
    }

    private func trackAnswerFailure(_ error: Error, step: String, operation: String, endpoint: String) async {
        var properties = analyticsErrorProperties(error)
        properties["answer_step"] = step

        switch error {
        case CoachServiceError.transcriptQualityTooLow:
            properties["transcript_status"] = "completed"
            properties["transcript_quality_status"] = "low_confidence"
        case CoachServiceError.transcriptionFailed:
            properties["transcript_status"] = "failed"
            properties["transcript_quality_status"] = "failed"
        default:
            break
        }

        let eventName: String
        switch step {
        case "first_answer":
            eventName = "first_answer_transcription_failed"
        case "follow_up_answer":
            eventName = "follow_up_answer_transcription_failed"
        case "redo_answer":
            eventName = "redo_transcription_failed"
        default:
            eventName = "answer_transcription_failed"
        }

        await trackSessionEvent(eventName, session: currentSession, emittedBy: "server", extraProperties: properties)
        await trackAPIError(error, operation: operation, endpoint: endpoint)
    }

    private func trackAPIError(_ error: Error, operation: String, endpoint: String, idempotencyKeyReused: Bool = false) async {
        var properties = analyticsErrorProperties(error)
        properties["failed_operation"] = operation
        properties["failed_endpoint"] = endpoint
        properties["idempotency_key_reused"] = String(idempotencyKeyReused)
        properties["http_status"] = "unavailable"
        properties["request_id"] = "unavailable"
        await trackAnalytics("api_error_received", properties: properties)
    }

    private func trackAnalytics(
        _ name: String,
        properties: [String: String] = [:],
        emittedBy: String = "client"
    ) async {
        var eventProperties = properties
        eventProperties["event_name"] = name
        eventProperties["event_id"] = UUID().uuidString
        eventProperties["event_schema_version"] = "analytics_v1"
        eventProperties["occurred_at"] = ISO8601DateFormatter().string(from: Date())
        eventProperties["emitted_by"] = emittedBy
        eventProperties["environment"] = analyticsEnvironment
        eventProperties["platform"] = "ios"
        eventProperties["app_version"] = appVersion
        eventProperties["locale"] = localeIdentifier
        eventProperties["device_session_id"] = analyticsDeviceSessionID

        if let appUserID {
            eventProperties["app_user_id"] = appUserID
        }

        await analytics.track(AnalyticsEvent(name: name, properties: eventProperties))
    }

    private func trainingProperties(focus: TrainingFocus?) -> [String: String] {
        guard let focus else { return [:] }
        return ["training_focus": focus.rawValue]
    }

    private func answerProperties(step: String, recording: RecordedAudio) -> [String: String] {
        [
            "answer_step": step,
            "duration_seconds_bucket": durationBucket(for: recording.durationSeconds),
            "transcript_status": "completed",
            "transcript_quality_status": "usable"
        ]
    }

    private func durationBucket(for durationSeconds: TimeInterval) -> String {
        switch durationSeconds {
        case ..<16:
            return "0_15"
        case ..<31:
            return "16_30"
        case ..<61:
            return "31_60"
        case ..<121:
            return "61_120"
        default:
            return "over_120"
        }
    }

    private func fileType(for fileName: String) -> String {
        URL(fileURLWithPath: fileName).pathExtension.lowercased()
    }

    private func deleteModeAnalyticsValue(_ mode: DeleteResumeMode) -> String {
        switch mode {
        case .resumeOnlyRedactedHistory:
            return "resume_only_redacted_history"
        case .resumeAndLinkedTraining:
            return "resume_and_linked_training"
        }
    }

    private func analyticsErrorProperties(_ error: Error) -> [String: String] {
        ["error_code": analyticsErrorCode(error)]
    }

    private func analyticsErrorCode(_ error: Error) -> String {
        guard let coachError = error as? CoachServiceError else {
            return "UNKNOWN"
        }

        switch coachError {
        case .notBootstrapped:
            return "NOT_BOOTSTRAPPED"
        case .unsupportedFileType:
            return "UNSUPPORTED_FILE_TYPE"
        case .fileTooLarge:
            return "FILE_TOO_LARGE"
        case .resumeNotReady:
            return "RESUME_NOT_READY"
        case .resumeParseFailed:
            return "RESUME_PARSE_FAILED"
        case .resumeProfileUnusable:
            return "RESUME_PROFILE_UNUSABLE"
        case .noCredits:
            return "INSUFFICIENT_SESSION_CREDITS"
        case .activeSessionExists:
            return "ACTIVE_SESSION_EXISTS"
        case .sessionNotFound:
            return "TRAINING_SESSION_NOT_FOUND"
        case .invalidSessionState:
            return "INVALID_SESSION_STATE"
        case .idempotencyConflict:
            return "IDEMPOTENCY_CONFLICT"
        case .audioUploadFailed:
            return "AUDIO_UPLOAD_FAILED"
        case .transcriptionFailed:
            return "TRANSCRIPTION_FAILED"
        case .transcriptQualityTooLow:
            return "TRANSCRIPT_QUALITY_TOO_LOW"
        case .aiGenerationFailed:
            return "AI_GENERATION_FAILED"
        case .purchaseVerificationFailed:
            return "APPLE_PURCHASE_VERIFICATION_FAILED"
        case .purchaseCancelled:
            return "PURCHASE_CANCELLED"
        case .purchasePending:
            return "PURCHASE_PENDING"
        case .purchaseUnavailable:
            return "PURCHASE_UNAVAILABLE"
        case .mockFailure:
            return "MOCK_FAILURE"
        }
    }

    private func handleRecordingSubmitFailure(_ error: Error, fallbackMessage: String) -> Bool {
        if let coachError = error as? CoachServiceError {
            switch coachError {
            case .transcriptQualityTooLow:
                activeSheet = .apiError("We could not use that recording. Record again in English with a clear, complete answer.")
                return false
            case .transcriptionFailed:
                activeSheet = .apiError("We could not transcribe that recording. Record again in a quieter place.")
                return false
            case .audioUploadFailed:
                activeSheet = .apiError("We could not upload that recording. Check your connection and try submitting again.")
                return false
            default:
                break
            }
        }

        activeSheet = .apiError(fallbackMessage)
        return false
    }

    private func pollSessionUntilDisplayable(_ session: TrainingSession) async throws -> TrainingSession {
        var latestSession = session
        var completedPolls = 0

        while latestSession.status.requiresSessionPolling && completedPolls < maxSessionPollAttempts {
            try await waitBeforeNextSessionPoll(afterCompletedPolls: completedPolls)
            try Task.checkCancellation()

            do {
                latestSession = try await service.session(id: latestSession.id)
                currentSession = latestSession
                completedPolls += 1
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                return latestSession
            }
        }

        return latestSession
    }

    private func waitBeforeNextSessionPoll(afterCompletedPolls completedPolls: Int) async throws {
        guard completedPolls > 0 else {
            return
        }

        let intervalNanoseconds: UInt64 = completedPolls <= 10 ? 2_000_000_000 : 5_000_000_000
        try await Task.sleep(nanoseconds: intervalNanoseconds)
    }
}

private extension TrainingSessionStatus {
    var canAbandonBeforeFeedback: Bool {
        switch self {
        case .questionGenerating, .waitingFirstAnswer, .firstAnswerProcessing, .followupGenerating, .waitingFollowupAnswer, .followupAnswerProcessing, .feedbackGenerating:
            return true
        case .redoAvailable, .redoProcessing, .redoEvaluating, .completed, .abandoned, .failed:
            return false
        }
    }

    var requiresSessionPolling: Bool {
        switch self {
        case .questionGenerating, .firstAnswerProcessing, .followupGenerating, .followupAnswerProcessing, .feedbackGenerating, .redoProcessing, .redoEvaluating:
            return true
        case .waitingFirstAnswer, .waitingFollowupAnswer, .redoAvailable, .completed, .abandoned, .failed:
            return false
        }
    }
}

private extension HomePrimaryState {
    var analyticsValue: String {
        switch self {
        case .activeSession:
            return "activeSession"
        case .noResume:
            return "noResume"
        case .resumeProcessing:
            return "resumeProcessing"
        case .resumeFailed:
            return "resumeFailed"
        case .resumeUnusable:
            return "resumeUnusable"
        case .outOfCredits:
            return "outOfCredits"
        case .readyLimited:
            return "readyLimited"
        case .ready:
            return "ready"
        }
    }
}
