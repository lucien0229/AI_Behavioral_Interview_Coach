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
        AppModel(service: CoachServiceFactory.makeService())
    }
}
