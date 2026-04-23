import SwiftUI

struct PaywallSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var isPending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetHandle()

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Continue personalized practice")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(CoachColor.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(creditSummary)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(CoachColor.text80)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(CoachColor.text48)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(isPending)
            }

            ProductCardView

            CoachPrimaryButton(title: "Buy Sprint Pack", isLoading: isPending) {
                guard !isPending else { return }
                isPending = true
                Task { @MainActor in
                    await appModel.buySprintPack()
                    isPending = false
                }
            }

            SheetSecondaryButton(title: "Restore purchase", isDisabled: isPending) {
                guard !isPending else { return }
                isPending = true
                Task { @MainActor in
                    await appModel.restorePurchase()
                    isPending = false
                }
            }

            Text("Purchases are verified with Apple before credits appear.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(CoachColor.text48)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .presentationDetents([.fraction(0.68)])
        .presentationDragIndicator(.hidden)
    }

    private var creditSummary: String {
        let count = max(appModel.homeSnapshot.credits.availableSessionCredits, 0)
        return count == 1 ? "1 practice credit available." : "\(count) practice credits available."
    }

    @ViewBuilder
    private var ProductCardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sprint Pack")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(CoachColor.text)

                    Text("5 personalized practice rounds")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(CoachColor.text80)
                }

                Spacer(minLength: 12)

                CoachTag(title: "One-time")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoachColor.surfaceMuted)
        .overlay {
            RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                .stroke(CoachColor.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
    }
}

struct DeleteConfirmationSheet: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    let intent: DeleteIntent
    @State private var isPending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetHandle()

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(CoachColor.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(CoachColor.text80)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            content

            SheetSecondaryButton(title: "Cancel", isDisabled: isPending) {
                dismiss()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .presentationDetents([.fraction(0.56)])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private var content: some View {
        switch intent {
        case .resumeOnly, .resumeAndTraining:
            VStack(alignment: .leading, spacing: 12) {
                SheetChoiceButton(
                    title: "Delete resume only",
                    subtitle: "Keep redacted history summaries",
                    systemImage: "doc",
                    isPending: isPending
                ) {
                    performResumeDelete(mode: .resumeOnlyRedactedHistory)
                }

                SheetChoiceButton(
                    title: "Delete resume and linked training",
                    subtitle: "Remove related practice content and audio",
                    systemImage: "trash",
                    isPending: isPending
                ) {
                    performResumeDelete(mode: .resumeAndLinkedTraining)
                }
            }
        case .cancelResumeProcessing:
            CoachPrimaryButton(title: "Cancel resume processing", isLoading: isPending) {
                performResumeDelete(mode: .resumeOnlyRedactedHistory)
            }
        case .practiceRound(let sessionID):
            CoachPrimaryButton(title: "Delete practice round", isLoading: isPending) {
                guard !isPending else { return }
                isPending = true
                Task { @MainActor in
                    await appModel.deletePractice(id: sessionID)
                    isPending = false
                }
            }
        case .allData:
            CoachPrimaryButton(title: "Delete all app data", isLoading: isPending) {
                guard !isPending else { return }
                isPending = true
                Task { @MainActor in
                    await appModel.deleteAllData()
                    isPending = false
                }
            }
        }
    }

    private var title: String {
        switch intent {
        case .resumeOnly, .resumeAndTraining:
            return "Delete resume"
        case .cancelResumeProcessing:
            return "Cancel resume processing?"
        case .practiceRound:
            return "Delete this practice round?"
        case .allData:
            return "Delete all app data?"
        }
    }

    private var message: String {
        switch intent {
        case .resumeOnly, .resumeAndTraining:
            return "Your original resume will be removed. Choose what happens to linked practice content. Purchase and credit records are not shown as training content."
        case .cancelResumeProcessing:
            return "This stops using the current resume for practice. You can upload another resume afterward. Any partial resume data already derived from this file will be cleared."
        case .practiceRound:
            return "This removes the visible practice content and related audio. Purchase and credit records are not removed."
        case .allData:
            return "This deletes your resume, audio, transcripts, feedback, and history. Your local app profile will be reset."
        }
    }

    private func performResumeDelete(mode: DeleteResumeMode) {
        guard !isPending else { return }
        isPending = true
        Task { @MainActor in
            await appModel.deleteResume(mode: mode)
            isPending = false
        }
    }
}

struct MicrophonePermissionSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetHandle()

            VStack(spacing: 18) {
                Image(systemName: "mic")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(CoachColor.text)

                Text("Allow microphone access")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(CoachColor.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Answer out loud for this version. Text input is not the main path.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(CoachColor.text80)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CoachPrimaryButton(title: "Continue") {
                dismiss()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .presentationDetents([.fraction(0.48)])
        .presentationDragIndicator(.hidden)
    }
}

private struct SheetHandle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(CoachColor.line)
            .frame(width: 79, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}

private struct SheetChoiceButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isPending: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(CoachColor.text48)
                    .frame(width: 20, height: 20)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(CoachColor.text)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(CoachColor.text48)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

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
        .buttonStyle(.plain)
        .disabled(isPending)
    }
}

private struct SheetSecondaryButton: View {
    let title: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CoachColor.linkBlue)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: CoachSize.secondaryButtonHeight)
                .background(CoachColor.transparent)
                .overlay {
                    RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                        .stroke(CoachColor.blue, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
