import Observation
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

// Temporary scaffold placeholders. Later feature tasks replace these with real app models and views.
private struct MockCoachService {}

@MainActor
@Observable
private final class AppModel {
    init(service: MockCoachService) {}
}

private struct LaunchView: View {
    var body: some View {
        Text("Interview Coach")
            .font(.title)
            .padding()
    }
}
