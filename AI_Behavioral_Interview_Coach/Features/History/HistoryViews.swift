import SwiftUI

struct HistoryListView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isLoading = true

    private var summaries: [PracticeSummary] {
        appModel.history.isEmpty ? appModel.homeSnapshot.recentPractice : appModel.history
    }

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                RouteNavBar(title: "History")

                if isLoading {
                    CoachLoadingView(
                        title: "Loading history",
                        subtitle: "We're fetching your recent practice summaries."
                    )
                } else if summaries.isEmpty {
                    HistoryEmptyStateView(startTraining: startTraining)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent practice")
                            .font(.system(size: 31, weight: .bold))
                            .foregroundStyle(CoachColor.text)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(summaries) { summary in
                                Button {
                                    appModel.navigationPath.append(.historyDetail(sessionID: summary.id))
                                } label: {
                                    HistorySummaryRow(summary: summary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        CoachPrimaryButton(title: "Start training") {
                            startTraining()
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .task {
            await loadHistory()
        }
    }

    private func loadHistory() async {
        isLoading = true
        defer { isLoading = false }
        await appModel.refreshHome()
    }

    private func startTraining() {
        appModel.navigationPath.removeAll()
        Task {
            await appModel.startTraining()
        }
    }
}

struct HistoryDetailView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isLoading = true

    let sessionID: String

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                RouteNavBar(title: "Practice detail")

                if isLoading {
                    CoachLoadingView(
                        title: "Loading practice detail",
                        subtitle: "We're fetching this round from your history."
                    )
                } else if let session = appModel.currentSession, session.id == sessionID {
                    if session.isTerminal {
                        detailContent(for: session)
                    } else {
                        HistoryActiveSessionView(session: session, continueTraining: continueTraining)
                    }
                } else {
                    HistoryDetailUnavailableView(backToHistory: backToHistory)
                }
            }
        }
        .task(id: sessionID) {
            await loadSession()
        }
    }

    private func loadSession() async {
        isLoading = true
        defer { isLoading = false }

        await appModel.loadSession(id: sessionID)

        guard let session = appModel.currentSession, session.id == sessionID, !session.isTerminal else {
            return
        }

        if appModel.navigationPath.last == .historyDetail(sessionID: sessionID) {
            _ = appModel.navigationPath.popLast()
            appModel.navigationPath.append(.trainingSession(sessionID: sessionID))
        }
    }

    @ViewBuilder
    private func detailContent(for session: TrainingSession) -> some View {
        let statusText = historyStatusText(for: session)
        let completionText = completionReasonText(for: session)

        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(session.focus.displayName)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(CoachColor.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(statusText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(CoachColor.text48)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DetailSection(title: "Question", text: session.questionText)

            DetailSection(
                title: "Follow-up",
                text: session.followupText ?? "This round did not reach a follow-up prompt."
            )

            if let feedback = session.feedback {
                DetailSection(
                    title: "Feedback",
                    text: [
                        feedback.biggestGap,
                        feedback.whyItMatters,
                        feedback.redoPriority,
                        feedback.strongestSignal
                    ]
                    .joined(separator: "\n\n")
                )
            }

            if let redoReview = session.redoReview {
                DetailSection(
                    title: "Redo review",
                    text: [
                        redoReview.headline,
                        redoReview.stillMissing,
                        redoReview.nextAttempt
                    ]
                    .joined(separator: "\n\n")
                )
            } else {
                DetailSection(
                    title: "Redo review",
                    text: "Redo review unavailable."
                )
            }

            if let completionText {
                DetailSection(title: "Completion reason", text: completionText)
            }

            CoachSecondaryButton(title: "Delete practice round", showsBorder: true) {
                appModel.activeSheet = .deleteConfirmation(.practiceRound(sessionID: sessionID))
            }
        }
    }

    private func continueTraining() {
        appModel.navigationPath.removeAll()
        appModel.navigationPath.append(.trainingSession(sessionID: sessionID))
    }

    private func backToHistory() {
        if appModel.navigationPath.last == .historyDetail(sessionID: sessionID) {
            _ = appModel.navigationPath.popLast()
        }
    }
}

private struct HistorySummaryRow: View {
    let summary: PracticeSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "message.square")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(CoachColor.text48)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 6) {
                Text(summary.questionText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CoachColor.text)
                    .lineLimit(2)

                Text(summary.metadataLine)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CoachColor.text48)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CoachColor.text48)
                .padding(.top, 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoachColor.surface)
        .overlay {
            RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                .stroke(CoachColor.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
    }
}

private struct HistoryEmptyStateView: View {
    let startTraining: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("No practice history yet")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(CoachColor.text)
                .fixedSize(horizontal: false, vertical: true)

            Text("Complete a practice round to see it here.")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(CoachColor.text80)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            CoachPrimaryButton(title: "Start training") {
                startTraining()
            }
        }
    }
}

private struct HistoryActiveSessionView: View {
    let session: TrainingSession
    let continueTraining: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(session.focus.displayName)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(CoachColor.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text("This round is still active. Continue training to finish it.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(CoachColor.text48)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DetailSection(title: "Current question", text: session.questionText)

            CoachPrimaryButton(title: "Continue training") {
                continueTraining()
            }
        }
    }
}

private struct HistoryDetailUnavailableView: View {
    let backToHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Practice detail unavailable")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(CoachColor.text)
                .fixedSize(horizontal: false, vertical: true)

            Text("This practice round could not be loaded.")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(CoachColor.text80)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            CoachSecondaryButton(title: "Back to history") {
                backToHistory()
            }
        }
    }
}

private struct DetailSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CoachSectionTitle(title: title)
            Text(text)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(CoachColor.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RouteNavBar: View {
    @Environment(\.dismiss) private var dismiss
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CoachColor.text)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(CoachColor.text)

            Spacer(minLength: 0)
        }
    }
}

private func historyStatusText(for summary: PracticeSummary) -> String {
    historyStatusText(for: summary.status)
}

private func historyStatusText(for session: TrainingSession) -> String {
    if session.isTerminal {
        return historyStatusText(for: session.completionReason?.rawValue ?? session.status.rawValue)
    }
    return historyStatusText(for: session.status.rawValue)
}

private func historyStatusText(for rawStatus: String) -> String {
    switch rawStatus {
    case "redo_review_generated":
        return "Redo review generated"
    case "redo_skipped":
        return "Redo skipped"
    case "redo_review_unavailable":
        return "Redo review unavailable"
    case "completed":
        return "Completed"
    case "abandoned":
        return "Abandoned"
    case "failed":
        return "Failed"
    case "waiting_first_answer":
        return "Waiting for answer"
    case "waiting_followup_answer":
        return "Waiting for follow-up"
    default:
        return rawStatus.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private func completionReasonText(for session: TrainingSession) -> String? {
    guard let completionReason = session.completionReason else {
        return nil
    }

    switch completionReason {
    case .redoReviewGenerated:
        return "Redo review generated."
    case .redoSkipped:
        return "Redo was skipped."
    case .redoReviewUnavailable:
        return "Redo review was unavailable."
    }
}
