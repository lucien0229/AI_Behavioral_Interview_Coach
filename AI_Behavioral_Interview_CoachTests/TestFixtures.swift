import Foundation
@testable import AI_Behavioral_Interview_Coach

extension RecordedAudio {
    static let testFixture = RecordedAudio(
        fileURL: URL(fileURLWithPath: "/tmp/aibic-test-audio.m4a"),
        durationSeconds: 3
    )
}
