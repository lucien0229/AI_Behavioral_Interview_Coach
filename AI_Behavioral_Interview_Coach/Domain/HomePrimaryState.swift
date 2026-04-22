enum HomePrimaryState: Equatable {
    case activeSession
    case noResume
    case resumeProcessing
    case resumeFailed
    case resumeUnusable
    case outOfCredits
    case readyLimited
    case ready

    static func derive(from snapshot: HomeSnapshot) -> HomePrimaryState {
        if snapshot.activeSession != nil {
            return .activeSession
        }

        guard let resume = snapshot.activeResume else {
            return .noResume
        }

        switch resume {
        case .uploading, .parsing:
            return .resumeProcessing
        case .failed:
            return .resumeFailed
        case .unusable:
            return .resumeUnusable
        case .readyLimited:
            if snapshot.credits.availableSessionCredits <= 0 {
                return .outOfCredits
            }
            return .readyLimited
        case .readyUsable:
            if snapshot.credits.availableSessionCredits <= 0 {
                return .outOfCredits
            }
            return .ready
        }
    }
}
