import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isRestoring = false

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                RouteNavBar(title: "Settings")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Data & privacy")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(CoachColor.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Manage practice data, billing restore, and deletion.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(CoachColor.text80)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                section(title: "Practice data") {
                    settingsRow(
                        systemImage: "doc.text",
                        title: "Manage resume",
                        detail: appModel.homeSnapshot.activeResume?.fileName ?? "No active resume"
                    ) {
                        appModel.navigationPath.append(.resumeManage)
                    }

                    settingsRow(
                        systemImage: "arrow.clockwise",
                        title: "Restore purchase",
                        detail: "Refresh Sprint Pack credits"
                    ) {
                        guard !isRestoring else { return }
                        isRestoring = true
                        Task { @MainActor in
                            await appModel.restorePurchase()
                            isRestoring = false
                        }
                    }
                    .disabled(isRestoring)
                }

                section(title: "Privacy and deletion") {
                    settingsRow(
                        systemImage: "shield",
                        title: "Privacy notice",
                        detail: "How v1 uses training data"
                    ) {
                        appModel.navigationPath.append(.privacyNotice)
                    }

                    settingsRow(
                        systemImage: "trash",
                        title: "Delete all app data",
                        detail: "Resume, audio, transcripts, feedback, history"
                    ) {
                        appModel.activeSheet = .deleteConfirmation(.allData)
                    }
                }

                section(title: "App version") {
                    CoachRow(
                        systemImage: "info.circle",
                        title: "App version",
                        detail: appVersionText(),
                        showsChevron: false
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CoachSectionTitle(title: title)
            content()
        }
    }

    @ViewBuilder
    private func settingsRow(
        systemImage: String,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            CoachRow(
                systemImage: systemImage,
                title: title,
                detail: detail,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
    }
}

struct PrivacyNoticeView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                RouteNavBar(title: "Privacy")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy notice")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(CoachColor.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Short, practical guidance on what this version uses and why.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(CoachColor.text80)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                privacySection(
                    title: "What we use",
                    body: "Resume file, practice audio, transcripts, AI feedback, and purchase entitlement status."
                )

                privacySection(
                    title: "Why we use it",
                    body: "To generate resume-based questions, transcribe spoken answers, provide feedback and redo review, and manage credits and restore."
                )

                privacySection(
                    title: "What we do not do in v1",
                    body: "No public profile, no resume rewriting product, and no required account signup before practice."
                )

                privacySection(
                    title: "Your controls",
                    body: "Delete the active resume, delete a practice round, or delete all app data."
                )

                CoachPrimaryButton(title: "Manage data") {
                    appModel.navigationPath.append(.settings)
                }
            }
        }
    }

    @ViewBuilder
    private func privacySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CoachSectionTitle(title: title)
            Text(body)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(CoachColor.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private func appVersionText() -> String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    let build = info?["CFBundleVersion"] as? String

    if let build, !build.isEmpty {
        return "\(version) (\(build))"
    }
    return version
}
