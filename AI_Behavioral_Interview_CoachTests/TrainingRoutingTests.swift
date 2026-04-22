import XCTest
@testable import AI_Behavioral_Interview_Coach

final class TrainingRoutingTests: XCTestCase {
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
}
