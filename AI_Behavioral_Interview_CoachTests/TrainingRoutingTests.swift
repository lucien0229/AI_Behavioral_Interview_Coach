import XCTest
@testable import AI_Behavioral_Interview_Coach

final class TrainingRoutingTests: XCTestCase {
    func testProcessingStatusesRouteToProcessing() {
        let statuses: [TrainingSessionStatus] = [
            .questionGenerating,
            .firstAnswerProcessing,
            .followupGenerating,
            .followupAnswerProcessing,
            .feedbackGenerating,
            .redoProcessing,
            .redoEvaluating
        ]

        for status in statuses {
            XCTAssertEqual(TrainingScreenState.route(for: .fixture(status: status)), .processing)
        }
    }

    func testWaitingFirstAnswerRoutesToFirstAnswer() {
        XCTAssertEqual(TrainingScreenState.route(for: .fixture(status: .waitingFirstAnswer)), .firstAnswer)
    }

    func testWaitingFollowupRoutesToFollowupAnswer() {
        XCTAssertEqual(TrainingScreenState.route(for: .fixture(status: .waitingFollowupAnswer)), .followupAnswer)
    }

    func testRedoAvailableRoutesToFeedback() {
        XCTAssertEqual(TrainingScreenState.route(for: .fixture(status: .redoAvailable)), .feedback)
    }

    func testCompletedRoutesToCompleted() {
        XCTAssertEqual(TrainingScreenState.route(for: .fixture(status: .completed)), .completed)
    }

    func testAbandonedRoutesToAbandoned() {
        XCTAssertEqual(TrainingScreenState.route(for: .fixture(status: .abandoned)), .abandoned)
    }

    func testFailedRoutesToFailed() {
        XCTAssertEqual(TrainingScreenState.route(for: .fixture(status: .failed)), .failed)
    }
}
