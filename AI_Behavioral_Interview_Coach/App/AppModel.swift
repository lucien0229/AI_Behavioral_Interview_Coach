import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private let service: any CoachService
    private let maxSessionPollAttempts = 25

    var isBootstrapping = true
    var homeSnapshot = HomeSnapshot(activeResume: nil, activeSession: nil, credits: .initialFree, recentPractice: [])
    var navigationPath: [AppRoute] = []
    var activeSheet: AppSheet?
    var selectedFocus: TrainingFocus?
    var currentSession: TrainingSession?
    var history: [PracticeSummary] = []

    init(service: any CoachService) {
        self.service = service
    }

    var homePrimaryState: HomePrimaryState {
        HomePrimaryState.derive(from: homeSnapshot)
    }

    func bootstrap() async {
        isBootstrapping = true
        do {
            _ = try await service.bootstrap()
            homeSnapshot = try await service.home()
        } catch {
            activeSheet = .apiError("We could not prepare your practice space. Please try again.")
        }
        isBootstrapping = false
    }

    func refreshHome() async {
        do {
            homeSnapshot = try await service.home()
            history = try await service.history()
        } catch {
            activeSheet = .apiError("We could not refresh your latest practice state.")
        }
    }

    func uploadResume(fileName: String) async {
        do {
            _ = try await service.uploadResume(fileName: fileName)
            guard !Task.isCancelled else { return }
            homeSnapshot = try await service.home()
            guard !Task.isCancelled else { return }
            navigationPath.append(.resumeManage)
        } catch is CancellationError {
            return
        } catch CoachServiceError.unsupportedFileType {
            activeSheet = .apiError("Only PDF or DOCX resumes are supported in this version.")
        } catch {
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
            let session = try await service.createTrainingSession(focus: focus)
            currentSession = session
            routeToTrainingSession(id: session.id)
            currentSession = try await pollSessionUntilDisplayable(session)
            homeSnapshot = try await service.home()
        } catch is CancellationError {
            return
        } catch CoachServiceError.noCredits {
            activeSheet = .paywall
        } catch CoachServiceError.resumeProfileUnusable {
            activeSheet = .apiError("Your resume does not include enough interview-ready experience. Upload a more detailed resume to start training.")
        } catch CoachServiceError.activeSessionExists {
            do {
                homeSnapshot = try await service.home()
                guard let activeSession = homeSnapshot.activeSession else {
                    activeSheet = .apiError("We could not find your active practice round.")
                    return
                }
                currentSession = activeSession
                routeToTrainingSession(id: activeSession.id)
                currentSession = try await pollSessionUntilDisplayable(activeSession)
            } catch is CancellationError {
                return
            } catch {
                activeSheet = .apiError("We could not start this practice round.")
            }
        } catch {
            activeSheet = .apiError("We could not start this practice round.")
        }
    }

    func loadSession(id: String) async {
        do {
            let session = try await service.session(id: id)
            currentSession = session
            currentSession = try await pollSessionUntilDisplayable(session)
        } catch is CancellationError {
            return
        } catch {
            activeSheet = .apiError("We could not load this practice round.")
        }
    }

    func submitFirstAnswer(recording: RecordedAudio) async -> Bool {
        guard let currentSession else { return false }
        do {
            let session = try await service.submitFirstAnswer(sessionID: currentSession.id, recording: recording)
            self.currentSession = session
            self.currentSession = try await pollSessionUntilDisplayable(session)
            return true
        } catch is CancellationError {
            return false
        } catch {
            return handleRecordingSubmitFailure(error, fallbackMessage: "We could not submit your answer. Please try again.")
        }
    }

    func submitFollowupAnswer(recording: RecordedAudio) async -> Bool {
        guard let currentSession else { return false }
        do {
            let session = try await service.submitFollowupAnswer(sessionID: currentSession.id, recording: recording)
            self.currentSession = session
            self.currentSession = try await pollSessionUntilDisplayable(session)
            do {
                homeSnapshot = try await service.home()
            } catch {
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            return handleRecordingSubmitFailure(error, fallbackMessage: "We could not submit your follow-up answer. Please try again.")
        }
    }

    func submitRedo(recording: RecordedAudio) async -> Bool {
        guard let currentSession else { return false }
        do {
            let session = try await service.submitRedo(sessionID: currentSession.id, recording: recording)
            self.currentSession = session
            self.currentSession = try await pollSessionUntilDisplayable(session)
            await refreshHome()
            return true
        } catch is CancellationError {
            return false
        } catch {
            return handleRecordingSubmitFailure(error, fallbackMessage: "We could not evaluate your redo. Your original feedback is saved.")
        }
    }

    func skipRedo() async {
        guard let currentSession else { return }
        do {
            self.currentSession = try await service.skipRedo(sessionID: currentSession.id)
            await refreshHome()
        } catch {
            activeSheet = .apiError("We could not finish this round. Please try again.")
        }
    }

    func buySprintPack() async {
        do {
            try await service.mockPurchaseSprintPack()
            activeSheet = nil
            await refreshHome()
        } catch {
            activeSheet = .apiError("Purchase could not be completed.")
        }
    }

    func restorePurchase() async {
        do {
            try await service.mockRestorePurchase()
            activeSheet = nil
            await refreshHome()
        } catch {
            activeSheet = .apiError("Purchase restore could not be completed.")
        }
    }

    func deleteResume(mode: DeleteResumeMode) async {
        do {
            let nextHomeSnapshot = try await service.deleteResume(mode: mode)
            homeSnapshot = nextHomeSnapshot
            history = try await service.history()

            if let currentSession, !currentSession.isTerminal {
                self.currentSession = nextHomeSnapshot.activeSession
            }

            navigationPath.removeAll()
            activeSheet = nil
        } catch {
            activeSheet = .apiError("We could not delete your resume.")
        }
    }

    func deletePractice(id: String) async {
        do {
            history = try await service.deletePractice(id: id)
            homeSnapshot = try await service.home()

            if currentSession?.id == id {
                currentSession = nil
            }

            navigationPath = [.historyList]

            activeSheet = nil
        } catch {
            activeSheet = .apiError("We could not delete this practice round.")
        }
    }

    func deleteAllData() async {
        do {
            _ = try await service.deleteAllData()
            navigationPath.removeAll()
            currentSession = nil
            history = []
            selectedFocus = nil
            homeSnapshot = HomeSnapshot(activeResume: nil, activeSession: nil, credits: .initialFree, recentPractice: [])
            activeSheet = nil
            isBootstrapping = true
            await bootstrap()
        } catch {
            activeSheet = .apiError("We could not delete your app data.")
        }
    }

    private func routeToTrainingSession(id: String) {
        let route = AppRoute.trainingSession(sessionID: id)
        guard navigationPath.last != route else {
            return
        }
        navigationPath.append(route)
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
    var requiresSessionPolling: Bool {
        switch self {
        case .questionGenerating, .firstAnswerProcessing, .followupGenerating, .followupAnswerProcessing, .feedbackGenerating, .redoProcessing, .redoEvaluating:
            return true
        case .waitingFirstAnswer, .waitingFollowupAnswer, .redoAvailable, .completed, .abandoned, .failed:
            return false
        }
    }
}
