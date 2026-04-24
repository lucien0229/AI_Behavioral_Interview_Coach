import XCTest
@testable import AI_Behavioral_Interview_Coach

final class AI_Behavioral_Interview_CoachTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }

    func testAnalyticsPipelineRejectsForbiddenFields() async {
        let sink = RecordingAnalyticsSink()
        let pipeline = AnalyticsPipeline(sink: sink)
        let event = AnalyticsEvent(
            name: "feedback_viewed",
            properties: [
                "event_schema_version": "analytics_v1",
                "session_id": "session_123",
                "transcript_text": "I solved the problem by..."
            ]
        )

        await pipeline.track(event)

        let events = await sink.events()
        XCTAssertTrue(events.isEmpty)
    }

    func testAnalyticsPipelineAcceptsAllowedEventWithSchemaVersion() async {
        let sink = RecordingAnalyticsSink()
        let pipeline = AnalyticsPipeline(sink: sink)
        let event = AnalyticsEvent(
            name: "home_viewed",
            properties: [
                "event_schema_version": "analytics_v1",
                "home_primary_state": "ready"
            ]
        )

        await pipeline.track(event)

        let events = await sink.events()
        XCTAssertEqual(events.map(\.name), ["home_viewed"])
        XCTAssertEqual(events.first?.properties["event_schema_version"], "analytics_v1")
        XCTAssertEqual(events.first?.properties["home_primary_state"], "ready")
    }
}

private actor RecordingAnalyticsSink: AnalyticsSink {
    private var capturedEvents: [AnalyticsEvent] = []

    func send(_ event: AnalyticsEvent) async {
        capturedEvents.append(event)
    }

    func reset() async {
        capturedEvents.removeAll()
    }

    func events() -> [AnalyticsEvent] {
        capturedEvents
    }
}
