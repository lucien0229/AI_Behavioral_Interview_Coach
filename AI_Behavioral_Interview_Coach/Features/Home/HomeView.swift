import SwiftUI

struct HomeRootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        NavigationStack(path: $appModel.navigationPath) {
            HomeView()
                .navigationDestination(for: AppRoute.self, destination: destinationView)
        }
        .sheet(item: $appModel.activeSheet, content: sheetView)
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .resumeUpload:
            ResumeUploadView()
        case .resumeManage:
            ResumeManageView()
        case .trainingSession(let sessionID):
            TrainingSessionView(sessionID: sessionID)
        case .historyList:
            FeaturePlaceholderRouteView(
                title: "History",
                message: "Task 8 history list is not implemented yet."
            )
        case .historyDetail(let sessionID):
            FeaturePlaceholderRouteView(
                title: "History Detail",
                message: "Task 8 history detail is not implemented yet.",
                detail: "Session ID: \(sessionID)"
            )
        case .settings:
            FeaturePlaceholderRouteView(
                title: "Settings",
                message: "Task 9 settings is not implemented yet."
            )
        case .privacyNotice:
            FeaturePlaceholderRouteView(
                title: "Privacy Notice",
                message: "Task 9 privacy notice is not implemented yet."
            )
        }
    }

    @ViewBuilder
    private func sheetView(for sheet: AppSheet) -> some View {
        switch sheet {
        case .focusPicker:
            FocusPickerSheet()
        case .paywall:
            PlaceholderSheet(
                title: "Sprint Pack",
                message: "The paywall flow is not implemented yet."
            )
        case .deleteConfirmation(let intent):
            PlaceholderSheet(
                title: deleteTitle(for: intent),
                message: "This destructive confirmation flow is not implemented yet."
            )
        case .microphonePermission:
            PlaceholderSheet(
                title: "Microphone Permission",
                message: "The microphone permission flow is not implemented yet."
            )
        case .apiError(let message):
            APIErrorSheet(message: message)
        }
    }

    private func deleteTitle(for intent: DeleteIntent) -> String {
        switch intent {
        case .resumeOnly:
            return "Delete Resume"
        case .resumeAndTraining:
            return "Delete Resume and Training"
        case .practiceRound:
            return "Delete Practice Round"
        case .allData:
            return "Delete All Data"
        }
    }
}

struct HomeView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        switch appModel.homePrimaryState {
        case .noResume:
            HomeNoResumeView()
        case .ready, .readyLimited:
            HomeReadyView()
        case .activeSession:
            HomeActiveSessionView()
        case .resumeProcessing:
            HomeResumeProcessingView()
        case .resumeFailed:
            HomeResumeIssueView(
                title: "Resume upload failed",
                message: "Please choose another file. Only PDF or DOCX resumes are supported in this version."
            )
        case .resumeUnusable:
            HomeResumeIssueView(
                title: "This resume needs more detail",
                message: "We couldn't find enough concrete experience to build useful practice."
            )
        case .outOfCredits:
            HomeOutOfCreditsView()
        }
    }
}

private struct HomeNoResumeView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                HomeHeaderView(subtitle: "Resume required to begin")

                HomeHeroText(
                    title: "Upload your resume to start",
                    subtitle: "Your practice questions will be based on your real experience."
                )

                CoachPrimaryButton(title: "Upload resume") {
                    appModel.navigationPath.append(.resumeUpload)
                }

                CoachSecondaryButton(title: "Privacy") {
                    appModel.navigationPath.append(.privacyNotice)
                }

                HomeRowList(items: [
                    .init(systemImage: "doc.text", title: "Resume", detail: "No active resume", showsChevron: false),
                    .init(systemImage: "dollarsign.circle", title: "Practice credits", detail: creditsCopy(appModel.homeSnapshot.credits.availableSessionCredits), showsChevron: false),
                    .init(systemImage: "questionmark.circle", title: "History", detail: "Complete a round to see summaries", showsChevron: true) {
                        appModel.navigationPath.append(.historyList)
                    }
                ])
            }
        }
    }
}

private struct HomeReadyView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                HomeHeaderView(subtitle: "Your next round is ready")

                HomeHeroText(
                    title: "Ready for a practice round",
                    subtitle: "One question, one follow-up, and focused feedback."
                )

                CoachPrimaryButton(title: "Start training") {
                    Task { await appModel.startTraining() }
                }

                CoachSecondaryButton(title: "Choose focus") {
                    appModel.activeSheet = .focusPicker
                }

                VStack(alignment: .leading, spacing: 16) {
                    HomeRowList(items: [
                        .init(systemImage: "doc.text", title: appModel.homeSnapshot.activeResume?.fileName ?? "alex_pm_resume.pdf", detail: "Ready · 3 anchor experiences", showsChevron: true) {
                            appModel.navigationPath.append(.resumeManage)
                        }
                    ])

                    HStack(spacing: 12) {
                        CoachTag(title: "Ownership")
                        CoachTag(title: "Prioritization")
                        CoachTag(title: "Influence")
                    }

                    HomeRowList(items: homeHistoryRows(
                        recentPractice: appModel.homeSnapshot.recentPractice,
                        emptyState: nil,
                        showHistoryListRow: true,
                        historyListAction: { appModel.navigationPath.append(.historyList) },
                        historyDetailAction: { sessionID in
                            appModel.navigationPath.append(.historyDetail(sessionID: sessionID))
                        }
                    ))
                }
            }
        }
    }
}

private struct HomeActiveSessionView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        CoachLightScreen {
            let session = appModel.homeSnapshot.activeSession

            VStack(alignment: .leading, spacing: 24) {
                HomeHeaderView(subtitle: "Continue where you left off")

                CoachTag(title: "Active session", isSelected: true)

                HomeHeroText(
                    title: "Practice in progress",
                    subtitle: "Feedback is ready. Complete the redo step or skip it to finish."
                )

                CoachPrimaryButton(title: "Continue session") {
                    if let session {
                        appModel.navigationPath.append(.trainingSession(sessionID: session.id))
                    }
                }

                HomeRowList(items: [
                    .init(systemImage: "arrow.2.squarepath", title: "Current step", detail: currentStepText(session), showsChevron: false),
                    .init(systemImage: "target", title: "Current focus", detail: currentFocusText(session: session, selectedFocus: appModel.selectedFocus), showsChevron: false),
                    .init(systemImage: "dollarsign.circle", title: "Practice credits", detail: creditsCopy(appModel.homeSnapshot.credits.availableSessionCredits), showsChevron: false),
                    .init(systemImage: "questionmark.circle", title: "View all history", detail: "Recent practice summaries", showsChevron: true) {
                        appModel.navigationPath.append(.historyList)
                    }
                ])
            }
        }
    }
}

private struct HomeResumeProcessingView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                HomeHeaderView(subtitle: "Resume preparation")

                HomeHeroText(
                    title: "Reading your resume",
                    subtitle: "We'll let you know when personalized practice is ready."
                )

                CoachPrimaryButton(title: "View status") {
                    appModel.navigationPath.append(.resumeManage)
                }

                CoachSecondaryButton(title: "Cancel resume") {
                    appModel.activeSheet = .deleteConfirmation(.resumeOnly)
                }

                HomeRowList(items: [
                    .init(systemImage: "doc.text", title: appModel.homeSnapshot.activeResume?.fileName ?? "alex_pm_resume.pdf", detail: resumeProcessingDetail(appModel.homeSnapshot.activeResume), showsChevron: true) {
                        appModel.navigationPath.append(.resumeManage)
                    },
                    .init(systemImage: "dollarsign.circle", title: "Practice credits", detail: creditsCopy(appModel.homeSnapshot.credits.availableSessionCredits), showsChevron: false)
                ] + homeHistoryRows(
                    recentPractice: appModel.homeSnapshot.recentPractice,
                    emptyState: .init(title: "History", detail: "Complete a round to see summaries"),
                    showHistoryListRow: true,
                    historyListAction: { appModel.navigationPath.append(.historyList) },
                    historyDetailAction: { sessionID in
                        appModel.navigationPath.append(.historyDetail(sessionID: sessionID))
                    }
                ))
            }
        }
    }
}

private struct HomeHistoryEmptyState {
    let title: String
    let detail: String
}

private func homeHistoryRows(
    recentPractice: [PracticeSummary],
    emptyState: HomeHistoryEmptyState?,
    showHistoryListRow: Bool,
    historyListAction: @escaping () -> Void,
    historyDetailAction: @escaping (String) -> Void
) -> [HomeRowItem] {
    var items: [HomeRowItem] = []

    if let summary = recentPractice.first {
        items.append(
            .init(
                systemImage: "questionmark.circle",
                title: "Last practice",
                detail: "\(summary.subtitle) · \(summary.status)",
                showsChevron: true
            ) {
                historyDetailAction(summary.id)
            }
        )
    } else if let emptyState {
        items.append(
            .init(
                systemImage: "questionmark.circle",
                title: emptyState.title,
                detail: emptyState.detail,
                showsChevron: false
            )
        )
    }

    if showHistoryListRow {
        items.append(
            .init(systemImage: "questionmark.circle", title: "View all history", detail: "Recent practice summaries", showsChevron: true) {
                historyListAction()
            }
        )
    }

    return items
}

private struct HomeOutOfCreditsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                HomeHeaderView(subtitle: "Personalized practice is ready")

                HomeHeroText(
                    title: "You're out of practice credits",
                    subtitle: "Buy a Sprint Pack to continue personalized practice."
                )

                CoachPrimaryButton(title: "Buy Sprint Pack") {
                    appModel.activeSheet = .paywall
                }

                CoachSecondaryButton(title: "Restore purchase") {
                    appModel.activeSheet = .paywall
                }

                HomeRowList(items: [
                    .init(systemImage: "questionmark.circle", title: appModel.homeSnapshot.activeResume?.fileName ?? "alex_pm_resume.pdf", detail: "Ready for practice", showsChevron: true) {
                        appModel.navigationPath.append(.resumeManage)
                    },
                    .init(systemImage: "dollarsign.circle", title: "Available credits", detail: "0 practice rounds remaining", showsChevron: false),
                    .init(systemImage: "questionmark.circle", title: "View all history", detail: "Recent practice summaries", showsChevron: true) {
                        appModel.navigationPath.append(.historyList)
                    }
                ])
            }
        }
    }
}

private struct HomeResumeIssueView: View {
    @Environment(AppModel.self) private var appModel
    let title: String
    let message: String

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                HomeHeaderView(subtitle: "Resume needs attention")

                HomeHeroText(title: title, subtitle: message)

                CoachPrimaryButton(title: "Upload resume") {
                    appModel.navigationPath.append(.resumeUpload)
                }

                CoachSecondaryButton(title: "Privacy") {
                    appModel.navigationPath.append(.privacyNotice)
                }

                HomeRowList(items: [
                    .init(systemImage: "doc.text", title: appModel.homeSnapshot.activeResume?.fileName ?? "alex_pm_resume.pdf", detail: resumeIssueDetail(appModel.homeSnapshot.activeResume), showsChevron: false),
                    .init(systemImage: "dollarsign.circle", title: "Practice credits", detail: creditsCopy(appModel.homeSnapshot.credits.availableSessionCredits), showsChevron: false),
                    .init(systemImage: "questionmark.circle", title: "History", detail: "Complete a round to see summaries", showsChevron: true) {
                        appModel.navigationPath.append(.historyList)
                    }
                ])
            }
        }
    }
}

private struct HomeHeaderView: View {
    @Environment(AppModel.self) private var appModel
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Interview Coach")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(CoachColor.text)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(CoachColor.text48)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button {
                appModel.navigationPath.append(.settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(CoachColor.text)
                    .frame(width: 36, height: 36)
                    .background(CoachColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                            .stroke(CoachColor.line, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HomeHeroText: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(CoachColor.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(CoachColor.text80)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HomeRowList: View {
    let items: [HomeRowItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                if let action = item.action {
                    Button(action: action) {
                        CoachRow(
                            systemImage: item.systemImage,
                            title: item.title,
                            detail: item.detail,
                            showsChevron: item.showsChevron
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    CoachRow(
                        systemImage: item.systemImage,
                        title: item.title,
                        detail: item.detail,
                        showsChevron: item.showsChevron
                    )
                }
            }
        }
    }
}

private struct HomeRowItem {
    let systemImage: String?
    let title: String
    let detail: String?
    let showsChevron: Bool
    var action: (() -> Void)? = nil
}

private struct FeaturePlaceholderRouteView: View {
    let title: String
    let message: String
    var detail: String? = nil

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                FeatureNavBar(title: title)

                VStack(alignment: .leading, spacing: 18) {
                    Text(title)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(CoachColor.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(CoachColor.text80)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail {
                        Text(detail)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(CoachColor.text48)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct PlaceholderSheet: View {
    let title: String
    let message: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetHandle()

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(CoachColor.text)

            Text(message)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(CoachColor.text80)
                .fixedSize(horizontal: false, vertical: true)

            CoachPrimaryButton(title: "Close") {
                dismiss()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .presentationDetents([.fraction(0.42)])
        .presentationDragIndicator(.hidden)
    }
}

private struct APIErrorSheet: View {
    let message: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetHandle()

            Text("Something went wrong")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(CoachColor.text)

            Text(message)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(CoachColor.text80)
                .fixedSize(horizontal: false, vertical: true)

            CoachPrimaryButton(title: "Close") {
                dismiss()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .presentationDetents([.fraction(0.42)])
        .presentationDragIndicator(.hidden)
    }
}

private struct FocusPickerSheet: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetHandle()

            VStack(alignment: .leading, spacing: 10) {
                Text("Choose a practice focus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(CoachColor.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Pick one signal to guide the question, or start without a focus.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(CoachColor.text80)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 16) {
                Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                    GridRow {
                        FocusPickerChip(
                            title: TrainingFocus.ownership.displayName,
                            isSelected: appModel.selectedFocus == .ownership
                        ) {
                            appModel.selectedFocus = .ownership
                        }
                        FocusPickerChip(
                            title: TrainingFocus.prioritization.displayName,
                            isSelected: appModel.selectedFocus == .prioritization
                        ) {
                            appModel.selectedFocus = .prioritization
                        }
                    }

                    GridRow {
                        FocusPickerChip(
                            title: TrainingFocus.crossFunctionalInfluence.displayName,
                            isSelected: appModel.selectedFocus == .crossFunctionalInfluence
                        ) {
                            appModel.selectedFocus = .crossFunctionalInfluence
                        }
                        .gridCellColumns(2)
                    }

                    GridRow {
                        FocusPickerChip(
                            title: TrainingFocus.conflictHandling.displayName,
                            isSelected: appModel.selectedFocus == .conflictHandling
                        ) {
                            appModel.selectedFocus = .conflictHandling
                        }
                        FocusPickerChip(
                            title: TrainingFocus.failureLearning.displayName,
                            isSelected: appModel.selectedFocus == .failureLearning
                        ) {
                            appModel.selectedFocus = .failureLearning
                        }
                    }

                    GridRow {
                        FocusPickerChip(
                            title: TrainingFocus.ambiguity.displayName,
                            isSelected: appModel.selectedFocus == .ambiguity
                        ) {
                            appModel.selectedFocus = .ambiguity
                        }
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            CoachPrimaryButton(title: "Start training") {
                appModel.activeSheet = nil
                Task { await appModel.startTraining() }
            }

            CoachSecondaryButton(title: "Start without a focus") {
                appModel.activeSheet = nil
                Task { await appModel.startTrainingWithoutFocus() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .presentationDetents([.fraction(0.72)])
        .presentationDragIndicator(.hidden)
    }
}

private struct FocusPickerChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(foregroundColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(backgroundColor)
                .overlay {
                    RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var backgroundColor: Color {
        isSelected ? CoachColor.surface : CoachColor.surfaceMuted
    }

    private var foregroundColor: Color {
        isSelected ? CoachColor.blue : CoachColor.text80
    }

    private var borderColor: Color {
        isSelected ? CoachColor.blue : CoachColor.line
    }
}

private struct SheetHandle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(CoachColor.line)
            .frame(width: 146, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}

private func creditsCopy(_ count: Int) -> String {
    let resolved = max(count, 0)
    if resolved == 0 {
        return "0 practice rounds remaining"
    }
    return resolved == 1 ? "1 free round available" : "\(resolved) free rounds available"
}

private func currentStepText(_ session: TrainingSession?) -> String {
    guard let session else { return "Redo available" }

    switch session.status {
    case .redoAvailable:
        return "Redo available"
    case .waitingFirstAnswer:
        return "Waiting for answer"
    case .waitingFollowupAnswer:
        return "Waiting for follow-up"
    case .questionGenerating, .firstAnswerProcessing, .followupGenerating, .followupAnswerProcessing, .feedbackGenerating, .redoProcessing, .redoEvaluating:
        return "Processing"
    case .completed:
        return "Completed"
    case .abandoned:
        return "Abandoned"
    case .failed:
        return "Failed"
    }
}

private func currentFocusText(session: TrainingSession?, selectedFocus: TrainingFocus?) -> String {
    session?.focus.displayName ?? selectedFocus?.displayName ?? "No focus selected"
}

private func resumeProcessingDetail(_ resume: ActiveResume?) -> String {
    guard let resume else {
        return "Parsing · usually under a minute"
    }

    switch resume {
    case .uploading:
        return "Uploading · usually under a minute"
    case .parsing:
        return "Parsing · usually under a minute"
    case .readyUsable, .readyLimited:
        return "Ready for practice"
    case .unusable(_, let reason):
        return reason
    case .failed(_, let reason):
        return reason
    }
}

private func resumeIssueDetail(_ resume: ActiveResume?) -> String {
    guard let resume else {
        return "Needs attention"
    }

    switch resume {
    case .unusable(_, let reason):
        return reason
    case .failed(_, let reason):
        return reason
    case .uploading:
        return "Upload in progress"
    case .parsing:
        return "Parsing in progress"
    case .readyUsable, .readyLimited:
        return "Ready for practice"
    }
}
