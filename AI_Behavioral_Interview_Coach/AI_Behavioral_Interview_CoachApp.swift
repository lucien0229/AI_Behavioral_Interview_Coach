import SwiftUI

@main
struct AI_Behavioral_Interview_CoachApp: App {
    @State private var appModel = AppModel(service: MockCoachService())

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environment(appModel)
        }
    }
}
