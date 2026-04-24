import XCTest
@testable import AI_Behavioral_Interview_Coach

final class CoachServiceFactoryTests: XCTestCase {
    func testDefaultsToMockServiceWhenAPIBaseURLIsMissing() {
        let service = CoachServiceFactory.makeService(
            environment: [:],
            userDefaults: UserDefaults(suiteName: "CoachServiceFactoryTests-default")!
        )

        XCTAssertTrue(service is MockCoachService)
    }

    func testUsesRemoteServiceWhenAPIBaseURLIsProvided() {
        let service = CoachServiceFactory.makeService(
            environment: [
                "AIBIC_API_BASE_URL": "https://api.example.test",
                "AIBIC_INSTALLATION_ID": "install-123"
            ],
            userDefaults: UserDefaults(suiteName: "CoachServiceFactoryTests-remote")!
        )

        XCTAssertTrue(service is RemoteCoachService)
    }
}
