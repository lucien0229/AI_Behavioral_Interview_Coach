import Foundation

enum AppRoute: Hashable {
    case resumeUpload
    case resumeManage
    case trainingSession(sessionID: String)
    case historyList
    case historyDetail(sessionID: String)
    case settings
    case privacyNotice
}

enum AppSheet: Identifiable, Equatable {
    case focusPicker
    case paywall
    case deleteConfirmation(DeleteIntent)
    case microphonePermission
    case apiError(String)

    var id: String {
        switch self {
        case .focusPicker: "focusPicker"
        case .paywall: "paywall"
        case .deleteConfirmation(let intent): "deleteConfirmation-\(intent.id)"
        case .microphonePermission: "microphonePermission"
        case .apiError(let message): "apiError-\(message)"
        }
    }
}

enum DeleteIntent: Identifiable, Equatable {
    case resumeOnly
    case resumeAndTraining
    case practiceRound(sessionID: String)
    case allData

    var id: String {
        switch self {
        case .resumeOnly: "resumeOnly"
        case .resumeAndTraining: "resumeAndTraining"
        case .practiceRound(let sessionID): "practiceRound-\(sessionID)"
        case .allData: "allData"
        }
    }
}

enum TrainingScreenState: Equatable {
    case processing
    case firstAnswer
    case followupAnswer
    case feedback
    case redo
    case completed
    case abandoned
    case failed

    static func route(for session: TrainingSession) -> TrainingScreenState {
        switch session.status {
        case .questionGenerating, .firstAnswerProcessing, .followupGenerating, .followupAnswerProcessing, .feedbackGenerating, .redoProcessing, .redoEvaluating:
            return .processing
        case .waitingFirstAnswer:
            return .firstAnswer
        case .waitingFollowupAnswer:
            return .followupAnswer
        case .redoAvailable:
            return .feedback
        case .completed:
            return .completed
        case .abandoned:
            return .abandoned
        case .failed:
            return .failed
        }
    }
}
