import SwiftUI

struct LaunchView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if appModel.isBootstrapping {
                LaunchLoadingView()
            } else {
                HomeRootView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background((appModel.isBootstrapping ? Color.black : CoachColor.canvas).ignoresSafeArea())
        .task {
            guard appModel.isBootstrapping else { return }
            await appModel.bootstrap()
        }
    }
}

private struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer(minLength: 0)

                VStack(spacing: 18) {
                    Text("Interview Coach")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Preparing your practice space")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    LaunchProgressBar()
                        .frame(width: 201, height: 5)
                        .padding(.top, 6)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct LaunchProgressBar: View {
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.22))

            Capsule()
                .fill(.white)
                .frame(width: 86)
        }
    }
}
