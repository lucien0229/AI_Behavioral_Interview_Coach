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
    var selectedFocus: TrainingFocus = .ownership
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
            homeSnapshot = try await service.home()
            navigationPath.append(.resumeManage)
        } catch CoachServiceError.unsupportedFileType {
            activeSheet = .apiError("Only PDF or DOCX resumes are supported in this version.")
        } catch {
            activeSheet = .apiError("Resume upload failed. Please choose another file.")
        }
    }

    func startTraining() async {
        do {
            let session = try await service.createTrainingSession(focus: selectedFocus)
            currentSession = session
            navigationPath.append(.trainingSession(sessionID: session.id))
            homeSnapshot = try await service.home()
        } catch CoachServiceError.noCredits {
            activeSheet = .paywall
        } catch CoachServiceError.activeSessionExists {
            if let active = homeSnapshot.activeSession {
                navigationPath.append(.trainingSession(sessionID: active.id))
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

    func submitFirstAnswer() async {
        guard let currentSession else { return }
        do {
            self.currentSession = try await service.submitFirstAnswer(sessionID: currentSession.id)
        } catch {
            activeSheet = .apiError("We could not submit your answer. Please try again.")
        }
    }

    func submitFollowupAnswer() async {
        guard let currentSession else { return }
        do {
            self.currentSession = try await service.submitFollowupAnswer(sessionID: currentSession.id)
            homeSnapshot = try await service.home()
        } catch {
            activeSheet = .apiError("We could not submit your follow-up answer. Please try again.")
        }
    }

    func submitRedo() async {
        guard let currentSession else { return }
        do {
            self.currentSession = try await service.submitRedo(sessionID: currentSession.id)
            await refreshHome()
        } catch {
            activeSheet = .apiError("We could not evaluate your redo. Your original feedback is saved.")
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

    func deleteAllData() async {
        do {
            _ = try await service.deleteAllData()
            navigationPath.removeAll()
            await refreshHome()
        } catch {
            activeSheet = .apiError("We could not delete your app data.")
        }
    }
}
