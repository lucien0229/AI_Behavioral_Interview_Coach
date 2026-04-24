import SwiftUI

@main
struct AI_Behavioral_Interview_CoachApp: App {
    @State private var appModel: AppModel

    init() {
        _appModel = State(initialValue: Self.makeAppModel())
    }

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environment(appModel)
        }
    }

    private static func makeAppModel() -> AppModel {
        let environment = ProcessInfo.processInfo.environment
        let hasSeededResume = environment["AIBIC_UI_TEST_READY_RESUME"] == "1"
        let processingDelayNanoseconds: UInt64 = environment["AIBIC_UI_TEST_FAST"] == "1" ? 0 : 350_000_000

        return AppModel(
            service: MockCoachService(
                processingDelayNanoseconds: processingDelayNanoseconds,
                initialActiveResume: hasSeededResume ? .readyUsable(fileName: "alex_pm_resume.pdf") : nil
            )
        )
    }
}
