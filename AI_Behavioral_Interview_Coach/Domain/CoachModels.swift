import Foundation

enum TrainingFocus: String, CaseIterable, Identifiable, Codable, Equatable {
    case ownership
    case prioritization
    case crossFunctionalInfluence = "cross_functional_influence"
    case conflictHandling = "conflict_handling"
    case failureLearning = "failure_learning"
    case ambiguity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ownership: "Ownership"
        case .prioritization: "Prioritization"
        case .crossFunctionalInfluence: "Cross-functional Influence"
        case .conflictHandling: "Conflict Handling"
        case .failureLearning: "Failure / Learning"
        case .ambiguity: "Ambiguity"
        }
    }
}

enum VisibleAssessmentStatus: String, Codable, Equatable {
    case strong = "Strong"
    case mixed = "Mixed"
    case weak = "Weak"
}

enum ImprovementStatus: String, Codable, Equatable {
    case improved
    case partiallyImproved = "partially_improved"
    case notImproved = "not_improved"
    case regressed
}

enum ActiveResume: Equatable {
    case uploading(fileName: String)
    case parsing(fileName: String)
    case readyUsable(fileName: String)
    case readyLimited(fileName: String)
    case unusable(fileName: String, reason: String)
    case failed(fileName: String, reason: String)

    var fileName: String {
        switch self {
        case .uploading(let fileName), .parsing(let fileName), .readyUsable(let fileName), .readyLimited(let fileName), .unusable(let fileName, _), .failed(let fileName, _):
            fileName
        }
    }
}

struct UsageBalance: Equatable {
    var availableSessionCredits: Int

    static let initialFree = UsageBalance(availableSessionCredits: 2)
}

enum TrainingSessionStatus: String, Codable, Equatable {
    case questionGenerating = "question_generating"
    case waitingFirstAnswer = "waiting_first_answer"
    case firstAnswerProcessing = "first_answer_processing"
    case followupGenerating = "followup_generating"
    case waitingFollowupAnswer = "waiting_followup_answer"
    case followupAnswerProcessing = "followup_answer_processing"
    case feedbackGenerating = "feedback_generating"
    case redoAvailable = "redo_available"
    case redoProcessing = "redo_processing"
    case redoEvaluating = "redo_evaluating"
    case completed
    case abandoned
    case failed
}

enum CompletionReason: String, Codable, Equatable {
    case redoReviewGenerated = "redo_review_generated"
    case redoSkipped = "redo_skipped"
    case redoReviewUnavailable = "redo_review_unavailable"
}

struct AssessmentLine: Identifiable, Equatable {
    let id: String
    let label: String
    let status: VisibleAssessmentStatus
}

struct FeedbackPayload: Equatable {
    let biggestGap: String
    let whyItMatters: String
    let redoPriority: String
    let redoOutline: [String]
    let strongestSignal: String
    let assessments: [AssessmentLine]
}

struct RedoReviewPayload: Equatable {
    let status: ImprovementStatus
    let headline: String
    let stillMissing: String
    let nextAttempt: String
}

struct TrainingSession: Identifiable, Equatable {
    let id: String
    var status: TrainingSessionStatus
    var focus: TrainingFocus
    var questionText: String
    var followupText: String?
    var feedback: FeedbackPayload?
    var redoReview: RedoReviewPayload?
    var completionReason: CompletionReason?

    var isTerminal: Bool {
        status == .completed || status == .abandoned || status == .failed
    }

    static func fixture(status: TrainingSessionStatus = .waitingFirstAnswer) -> TrainingSession {
        TrainingSession(
            id: "session_fixture",
            status: status,
            focus: .ownership,
            questionText: "Tell me about a time you had to make a high-stakes prioritization decision with incomplete information.",
            followupText: status == .waitingFollowupAnswer ? "What specific decision did you personally make at that point?" : nil,
            feedback: status == .redoAvailable || status == .completed ? .fixture : nil,
            redoReview: nil,
            completionReason: nil
        )
    }
}

extension FeedbackPayload {
    static let fixture = FeedbackPayload(
        biggestGap: "You still did not make your personal ownership explicit enough.",
        whyItMatters: "Interviewers must see what you personally decided or drove.",
        redoPriority: "Name your decision, tradeoff, and result before adding team context.",
        redoOutline: ["Set context in one sentence.", "State the decision you owned.", "Explain the tradeoff.", "Close with the result."],
        strongestSignal: "You picked a relevant example with real business context.",
        assessments: [
            AssessmentLine(id: "answered_question", label: "Answered the question", status: .strong),
            AssessmentLine(id: "story_fit", label: "Story fit", status: .strong),
            AssessmentLine(id: "personal_ownership", label: "Personal ownership", status: .weak),
            AssessmentLine(id: "evidence_and_outcome", label: "Evidence and outcome", status: .mixed),
            AssessmentLine(id: "holds_up_under_follow_up", label: "Holds up under follow-up", status: .weak)
        ]
    )
}

struct PracticeSummary: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let status: String
}

struct HomeSnapshot: Equatable {
    var activeResume: ActiveResume?
    var activeSession: TrainingSession?
    var credits: UsageBalance
    var recentPractice: [PracticeSummary]
}
