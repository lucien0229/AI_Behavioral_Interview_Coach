import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private let service: any CoachService

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
            navigationPath.append(.trainingSession(sessionID: session.id))
            homeSnapshot = try await service.home()
        } catch CoachServiceError.noCredits {
            activeSheet = .paywall
        } catch CoachServiceError.activeSessionExists {
            do {
                homeSnapshot = try await service.home()
                guard let activeSession = homeSnapshot.activeSession else {
                    activeSheet = .apiError("We could not find your active practice round.")
                    return
                }
                currentSession = activeSession
                navigationPath.append(.trainingSession(sessionID: activeSession.id))
            } catch {
                activeSheet = .apiError("We could not start this practice round.")
            }
        } catch {
            activeSheet = .apiError("We could not start this practice round.")
        }
    }

    func loadSession(id: String) async {
        do {
            currentSession = try await service.session(id: id)
        } catch {
            activeSheet = .apiError("We could not load this practice round.")
        }
    }

    func submitFirstAnswer() async -> Bool {
        guard let currentSession else { return false }
        do {
            self.currentSession = try await service.submitFirstAnswer(sessionID: currentSession.id)
            return true
        } catch {
            activeSheet = .apiError("We could not submit your answer. Please try again.")
            return false
        }
    }

    func submitFollowupAnswer() async -> Bool {
        guard let currentSession else { return false }
        do {
            self.currentSession = try await service.submitFollowupAnswer(sessionID: currentSession.id)
            do {
                homeSnapshot = try await service.home()
            } catch {
            }
            return true
        } catch {
            activeSheet = .apiError("We could not submit your follow-up answer. Please try again.")
            return false
        }
    }

    func submitRedo() async -> Bool {
        guard let currentSession else { return false }
        do {
            self.currentSession = try await service.submitRedo(sessionID: currentSession.id)
            await refreshHome()
            return true
        } catch {
            activeSheet = .apiError("We could not evaluate your redo. Your original feedback is saved.")
            return false
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
}
