import Foundation

struct BootstrapContext: Equatable {
    let appUserID: String
    let accessToken: String
    let appAccountToken: String
}

struct RecordedAudio: Equatable, Sendable {
    let fileURL: URL
    let durationSeconds: TimeInterval
}

enum CoachServiceError: Error, Equatable {
    case notBootstrapped
    case unsupportedFileType
    case fileTooLarge
    case resumeNotReady
    case resumeParseFailed
    case resumeProfileUnusable
    case noCredits
    case activeSessionExists
    case sessionNotFound
    case invalidSessionState
    case idempotencyConflict
    case audioUploadFailed
    case transcriptionFailed
    case transcriptQualityTooLow
    case aiGenerationFailed
    case purchaseVerificationFailed
    case mockFailure(message: String)
}

protocol CoachService: Sendable {
    func bootstrap() async throws -> BootstrapContext
    func home() async throws -> HomeSnapshot
    func uploadResume(fileName: String) async throws -> ActiveResume
    func deleteResume(mode: DeleteResumeMode) async throws -> HomeSnapshot
    func createTrainingSession(focus: TrainingFocus?) async throws -> TrainingSession
    func session(id: String) async throws -> TrainingSession
    func submitFirstAnswer(sessionID: String, recording: RecordedAudio) async throws -> TrainingSession
    func submitFollowupAnswer(sessionID: String, recording: RecordedAudio) async throws -> TrainingSession
    func submitRedo(sessionID: String, recording: RecordedAudio) async throws -> TrainingSession
    func skipRedo(sessionID: String) async throws -> TrainingSession
    func history() async throws -> [PracticeSummary]
    func historyDetail(id: String) async throws -> TrainingSession
    func deletePractice(id: String) async throws -> [PracticeSummary]
    func purchaseSprintPack() async throws
    func restorePurchase() async throws
    func deleteAllData() async throws -> BootstrapContext
}

enum DeleteResumeMode: Equatable {
    case resumeOnlyRedactedHistory
    case resumeAndLinkedTraining
}
