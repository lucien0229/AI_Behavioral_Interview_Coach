import Foundation

struct AnalyticsEvent: Equatable, Sendable {
    let name: String
    let properties: [String: String]
}

protocol AnalyticsService: Sendable {
    func track(_ event: AnalyticsEvent) async
    func reset() async
}

protocol AnalyticsSink: Sendable {
    func send(_ event: AnalyticsEvent) async
    func reset() async
}

actor AnalyticsPipeline: AnalyticsService {
    private let sink: any AnalyticsSink

    init(sink: any AnalyticsSink = NoopAnalyticsSink()) {
        self.sink = sink
    }

    func track(_ event: AnalyticsEvent) async {
        guard AnalyticsPrivacyGuard.allows(event) else {
            return
        }

        await sink.send(event)
    }

    func reset() async {
        await sink.reset()
    }
}

actor NoopAnalyticsSink: AnalyticsSink {
    func send(_ event: AnalyticsEvent) async {
    }

    func reset() async {
    }
}

enum AnalyticsPrivacyGuard {
    private static let forbiddenPropertyNames: Set<String> = [
        "resume_text",
        "source_snippets",
        "transcript_text",
        "question_text",
        "follow_up_text",
        "feedback_text",
        "biggest_gap",
        "why_it_matters",
        "redo_priority",
        "redo_outline",
        "strongest_signal",
        "signed_transaction_info",
        "transaction_payload",
        "apple_transaction_payload",
        "app_account_token"
    ]

    static func allows(_ event: AnalyticsEvent) -> Bool {
        let normalizedKeys = Set(event.properties.keys.map { $0.lowercased() })
        return normalizedKeys.isDisjoint(with: forbiddenPropertyNames)
    }
}
