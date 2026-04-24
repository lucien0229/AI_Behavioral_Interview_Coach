import SwiftUI

struct TrainingSessionView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showingRedoAnswer = false

    let sessionID: String

    var body: some View {
        let session = appModel.currentSession

        Group {
            if let session, session.id == sessionID {
                content(for: session)
            } else {
                CoachLoadingView(
                    title: "Preparing your personalized question",
                    subtitle: "We're using your resume to choose a relevant prompt.",
                    isDark: true
                )
            }
        }
        .task(id: sessionID) {
            await appModel.loadSession(id: sessionID)
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    @ViewBuilder
    private func content(for session: TrainingSession) -> some View {
        let baseRoute = TrainingScreenState.route(for: session)
        let route: TrainingScreenState = showingRedoAnswer ? .redo : baseRoute

        switch route {
        case .processing:
            TrainingProcessingView(session: session, onBackHome: dismissToHome)
        case .firstAnswer:
            RecordingPromptView(
                navTitle: "Question",
                focus: session.focus,
                eyebrow: "Based on your launch work,",
                question: session.questionText,
                recordingLabel: "Your first answer",
                submitTitle: "Submit answer",
                recordingStartedEventName: "first_answer_recording_started",
                topSupplement: {
                    EmptyView()
                },
                onBackHome: dismissToHome,
                onSubmit: { recording in
                    await appModel.submitFirstAnswer(recording: recording)
                }
            )
        case .followupAnswer:
            RecordingPromptView(
                navTitle: "Follow-up",
                focus: session.focus,
                eyebrow: "Based on your first answer,",
                question: session.followupText ?? "What specific decision did you personally make at that point?",
                recordingLabel: "Answer the follow-up",
                submitTitle: "Submit answer",
                recordingStartedEventName: "follow_up_answer_recording_started",
                topSupplement: {
                    OriginalQuestionCard(question: session.questionText)
                },
                onBackHome: dismissToHome,
                onSubmit: { recording in
                    await appModel.submitFollowupAnswer(recording: recording)
                }
            )
        case .feedback:
            FeedbackRedoDecisionView(
                session: session,
                onBackHome: dismissToHome,
                onRedo: {
                    showingRedoAnswer = true
                },
                onSkipRedo: {
                    await appModel.skipRedo()
                }
            )
        case .redo:
            RedoAnswerView(
                session: session,
                onBack: {
                    showingRedoAnswer = false
                },
                onSubmit: { recording in
                    await appModel.submitRedo(recording: recording)
                },
                onSubmitFinished: {
                    showingRedoAnswer = false
                }
            )
        case .completed:
            CompletedResultView(
                session: session,
                onBackHome: dismissToHome,
                onStartNext: startNextTraining
            )
        case .abandoned:
            TerminalTrainingView(
                title: "Practice ended",
                message: "This round was abandoned. You can return home and start again when you're ready.",
                onBackHome: dismissToHome
            )
        case .failed:
            TerminalTrainingView(
                title: "Practice failed",
                message: "We could not finish this practice round. Return home and start again.",
                onBackHome: dismissToHome
            )
        }
    }

    private func dismissToHome() {
        Task {
            await appModel.abandonCurrentSession()
        }
    }

    private func startNextTraining() async {
        appModel.navigationPath.removeAll()
        await appModel.startTraining()
    }
}

private struct TrainingProcessingView: View {
    let session: TrainingSession
    let onBackHome: () -> Void
    @State private var showsLongWaitNotice = false

    var body: some View {
        CoachDarkScreen {
            VStack(alignment: .leading, spacing: CoachSpace.lg) {
                TrainingNavBar(title: "Practice", isDark: true, onBack: {
                    onBackHome()
                })

                TrainingProgressBars(activeCount: processingProgressCount(for: session.status))
                    .padding(.top, CoachSpace.xs)

                Text(processingTitle(for: session.status))
                    .font(.coachDisplay)
                    .foregroundStyle(CoachColor.darkText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, CoachSpace.lg)

                Text(processingSubtitle(for: session.status))
                    .font(.coachBody)
                    .foregroundStyle(CoachColor.darkMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if showsLongWaitNotice {
                    TrainingNoticeCard(
                        systemImage: "clock",
                        message: "This is taking longer than usual. You can come back later.",
                        isDark: true
                    )
                }

                CoachSecondaryButton(title: "Back home", isDark: true, showsBorder: true) {
                    onBackHome()
                }
            }
            .padding(.top, CoachSpace.lg)
            .task(id: processingTaskID) {
                showsLongWaitNotice = false

                do {
                    try await Task.sleep(nanoseconds: 90_000_000_000)
                    guard !Task.isCancelled else {
                        return
                    }
                    showsLongWaitNotice = true
                } catch {
                    return
                }
            }
        }
    }

    private var processingTaskID: String {
        "\(session.id)-\(session.status.rawValue)"
    }
}

private struct RecordingPromptView<Supplement: View>: View {
    @Environment(AppModel.self) private var appModel
    @State private var recorder = AudioRecorder()
    @State private var isSubmitting = false

    let navTitle: String
    let focus: TrainingFocus
    let eyebrow: String
    let question: String
    let recordingLabel: String
    let submitTitle: String
    let recordingStartedEventName: String
    let topSupplement: () -> Supplement
    let onBackHome: () -> Void
    let onSubmit: (RecordedAudio) async -> Bool

    init(
        navTitle: String,
        focus: TrainingFocus,
        eyebrow: String,
        question: String,
        recordingLabel: String,
        submitTitle: String,
        recordingStartedEventName: String,
        @ViewBuilder topSupplement: @escaping () -> Supplement,
        onBackHome: @escaping () -> Void,
        onSubmit: @escaping (RecordedAudio) async -> Bool
    ) {
        self.navTitle = navTitle
        self.focus = focus
        self.eyebrow = eyebrow
        self.question = question
        self.recordingLabel = recordingLabel
        self.submitTitle = submitTitle
        self.recordingStartedEventName = recordingStartedEventName
        self.topSupplement = topSupplement
        self.onBackHome = onBackHome
        self.onSubmit = onSubmit
    }

    var body: some View {
        CoachDarkScreen {
            VStack(alignment: .leading, spacing: CoachSpace.lg) {
                TrainingNavBar(title: navTitle, isDark: true, onBack: {
                    if isReviewingRecording {
                        recorder.rerecord()
                    } else {
                        onBackHome()
                    }
                })

                CoachTag(title: focus.displayName, isSelected: true, isDark: true)

                topSupplement()

                Text(eyebrow)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(CoachColor.darkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(question)
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(CoachColor.darkText)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                RecordingControlCard(
                    title: recordingLabel,
                    subtitle: recordingSubtitle,
                    elapsedSeconds: recorder.elapsedSeconds,
                    state: recorder.recordingState,
                    canSubmit: recorder.canSubmit,
                    isSubmitting: isSubmitting,
                    primaryTitle: primaryTitle,
                    secondaryTitle: secondaryTitle,
                    primaryDisabled: primaryDisabled,
                    circleIcon: circleIcon,
                    circleAccessibilityLabel: circleAccessibilityLabel,
                    onPrimary: handlePrimaryAction,
                    onCircle: handleCircleAction,
                    onSecondary: handleSecondaryAction
                )
            }
            .padding(.top, CoachSpace.lg)
            .onDisappear {
                recorder.cleanupRecording()
            }
        }
    }

    private var isReviewingRecording: Bool {
        if case .recorded = recorder.recordingState {
            return true
        }
        if case .playing = recorder.recordingState {
            return true
        }
        return false
    }

    private var primaryTitle: String {
        switch recorder.recordingState {
        case .idle:
            return "Start recording"
        case .recording:
            return "Stop recording"
        case .recorded, .playing:
            return submitTitle
        }
    }

    private var secondaryTitle: String {
        isReviewingRecording ? "Re-record" : "Back"
    }

    private var primaryDisabled: Bool {
        if isSubmitting {
            return true
        }

        if case .playing = recorder.recordingState {
            return true
        }

        if case .recorded = recorder.recordingState {
            return !recorder.canSubmit
        }

        return false
    }

    private var circleIcon: String {
        switch recorder.recordingState {
        case .idle:
            return "mic"
        case .recording:
            return "square"
        case .recorded:
            return "play.fill"
        case .playing:
            return "square"
        }
    }

    private var circleAccessibilityLabel: String {
        switch recorder.recordingState {
        case .idle:
            return "Start recording"
        case .recording:
            return "Stop recording"
        case .recorded:
            return "Play recording"
        case .playing:
            return "Stop playback"
        }
    }

    private var recordingSubtitle: String {
        switch recorder.recordingState {
        case .idle:
            return "Start when you're ready."
        case .recording:
            return "Recording your answer."
        case .recorded where recorder.canSubmit:
            return "Ready to submit."
        case .recorded:
            return "Record at least 2 seconds before submitting."
        case .playing:
            return "Playing back your answer."
        }
    }

    private func handlePrimaryAction() {
        switch recorder.recordingState {
        case .idle:
            Task { await attemptStartRecording() }
        case .recording:
            recorder.stopRecording()
        case .recorded:
            guard recorder.canSubmit, !isSubmitting else { return }
            Task { await submitRecording() }
        case .playing:
            break
        }
    }

    private func handleCircleAction() {
        switch recorder.recordingState {
        case .idle:
            Task { await attemptStartRecording() }
        case .recording:
            recorder.stopRecording()
        case .recorded:
            recorder.playRecording()
        case .playing:
            recorder.stopPlayback()
        }
    }

    private func handleSecondaryAction() {
        if isReviewingRecording {
            recorder.rerecord()
        } else {
            onBackHome()
        }
    }

    private func attemptStartRecording() async {
        if recorder.permissionState == .unknown {
            await recorder.requestPermission()
        }

        guard recorder.permissionState == .granted else {
            appModel.activeSheet = .microphonePermission
            return
        }

        await appModel.trackRecordingStarted(eventName: recordingStartedEventName)
        recorder.startRecording()
    }

    private func submitRecording() async {
        guard !isSubmitting else {
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        guard case .recorded(let url) = recorder.recordingState else {
            return
        }

        let recording = RecordedAudio(fileURL: url, durationSeconds: recorder.elapsedSeconds)
        if await onSubmit(recording) {
            recorder.cleanupRecording()
        }
    }
}

private struct FeedbackRedoDecisionView: View {
    @Environment(AppModel.self) private var appModel

    let session: TrainingSession
    let onBackHome: () -> Void
    let onRedo: () -> Void
    let onSkipRedo: () async -> Void

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: CoachSpace.lg) {
                TrainingNavBar(title: "Feedback", isDark: false, onBack: {
                    onBackHome()
                })

                FeedbackSection(
                    title: "Biggest gap",
                    message: feedback.biggestGap
                )

                FeedbackSection(
                    title: "Why it matters",
                    message: feedback.whyItMatters
                )

                FeedbackSection(
                    title: "Redo priority",
                    message: feedback.redoPriority
                )

                FeedbackOutlineSection(items: feedback.redoOutline)

                FeedbackSection(
                    title: "Strongest signal",
                    message: feedback.strongestSignal
                )

                AssessmentSection(assessments: feedback.assessments)

                CoachPrimaryButton(title: "Redo this answer") {
                    onRedo()
                }

                CoachSecondaryButton(title: "Skip redo", showsBorder: true) {
                    Task {
                        await onSkipRedo()
                    }
                }
            }
            .padding(.top, CoachSpace.lg)
            .task(id: session.id) {
                await appModel.trackFeedbackViewed()
            }
        }
    }

    private var feedback: FeedbackPayload {
        session.feedback ?? .fixture
    }
}

private struct RedoAnswerView: View {
    @Environment(AppModel.self) private var appModel
    @State private var recorder = AudioRecorder()
    @State private var isSubmitting = false

    let session: TrainingSession
    let onBack: () -> Void
    let onSubmit: (RecordedAudio) async -> Bool
    let onSubmitFinished: () -> Void

    var body: some View {
        CoachDarkScreen {
            VStack(alignment: .leading, spacing: CoachSpace.lg) {
                TrainingNavBar(title: "Redo", isDark: true, onBack: {
                    if isReviewingRecording {
                        recorder.rerecord()
                    } else {
                        onBack()
                    }
                })

                Text("Redo priority")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CoachColor.darkMuted)

                Text("Focus on the decision you personally made.")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(CoachColor.darkText)
                    .lineSpacing(4)

                RedoDetailsCard(session: session)

                RecordingControlCard(
                    title: "One guided redo",
                    subtitle: recordingSubtitle,
                    elapsedSeconds: recorder.elapsedSeconds,
                    state: recorder.recordingState,
                    canSubmit: recorder.canSubmit,
                    isSubmitting: isSubmitting,
                    primaryTitle: primaryTitle,
                    secondaryTitle: secondaryTitle,
                    primaryDisabled: primaryDisabled,
                    circleIcon: circleIcon,
                    circleAccessibilityLabel: circleAccessibilityLabel,
                    onPrimary: handlePrimaryAction,
                    onCircle: handleCircleAction,
                    onSecondary: handleSecondaryAction
                )
            }
            .padding(.top, CoachSpace.lg)
            .onDisappear {
                recorder.cleanupRecording()
            }
        }
    }

    private var isReviewingRecording: Bool {
        if case .recorded = recorder.recordingState {
            return true
        }
        if case .playing = recorder.recordingState {
            return true
        }
        return false
    }

    private var primaryTitle: String {
        switch recorder.recordingState {
        case .idle:
            return "Start recording"
        case .recording:
            return "Stop recording"
        case .recorded, .playing:
            return "Submit redo"
        }
    }

    private var secondaryTitle: String {
        isReviewingRecording ? "Re-record" : "Back"
    }

    private var primaryDisabled: Bool {
        if isSubmitting {
            return true
        }

        if case .playing = recorder.recordingState {
            return true
        }

        if case .recorded = recorder.recordingState {
            return !recorder.canSubmit
        }

        return false
    }

    private var circleIcon: String {
        switch recorder.recordingState {
        case .idle:
            return "mic"
        case .recording:
            return "square"
        case .recorded:
            return "play.fill"
        case .playing:
            return "square"
        }
    }

    private var circleAccessibilityLabel: String {
        switch recorder.recordingState {
        case .idle:
            return "Start recording"
        case .recording:
            return "Stop recording"
        case .recorded:
            return "Play recording"
        case .playing:
            return "Stop playback"
        }
    }

    private var recordingSubtitle: String {
        switch recorder.recordingState {
        case .idle:
            return "One guided redo."
        case .recording:
            return "Recording your redo."
        case .recorded where recorder.canSubmit:
            return "Ready to submit."
        case .recorded:
            return "Record at least 2 seconds before submitting."
        case .playing:
            return "Playing back your redo."
        }
    }

    private func handlePrimaryAction() {
        switch recorder.recordingState {
        case .idle:
            Task { await attemptStartRecording() }
        case .recording:
            recorder.stopRecording()
        case .recorded:
            guard recorder.canSubmit, !isSubmitting else { return }
            Task { await submitRedo() }
        case .playing:
            break
        }
    }

    private func handleCircleAction() {
        switch recorder.recordingState {
        case .idle:
            Task { await attemptStartRecording() }
        case .recording:
            recorder.stopRecording()
        case .recorded:
            recorder.playRecording()
        case .playing:
            recorder.stopPlayback()
        }
    }

    private func handleSecondaryAction() {
        if isReviewingRecording {
            recorder.rerecord()
        } else {
            onBack()
        }
    }

    private func attemptStartRecording() async {
        if recorder.permissionState == .unknown {
            await recorder.requestPermission()
        }

        guard recorder.permissionState == .granted else {
            appModel.activeSheet = .microphonePermission
            return
        }

        await appModel.trackRecordingStarted(eventName: "redo_started")
        recorder.startRecording()
    }

    private func submitRedo() async {
        guard !isSubmitting else {
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        guard case .recorded(let url) = recorder.recordingState else {
            return
        }

        let recording = RecordedAudio(fileURL: url, durationSeconds: recorder.elapsedSeconds)
        if await onSubmit(recording) {
            recorder.cleanupRecording()
            onSubmitFinished()
        }
    }
}

private struct CompletedResultView: View {
    @Environment(AppModel.self) private var appModel

    let session: TrainingSession
    let onBackHome: () -> Void
    let onStartNext: () async -> Void

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: CoachSpace.lg) {
                TrainingNavBar(title: "Result", isDark: false, onBack: {
                    onBackHome()
                })

                Text("Practice complete")
                    .font(.coachDisplay)
                    .foregroundStyle(CoachColor.text)

                if let redoReview = session.redoReview {
                    VStack(alignment: .leading, spacing: CoachSpace.sm) {
                        Text("Redo review")
                            .font(.coachSectionTitle)
                            .foregroundStyle(CoachColor.text48)

                        Text(redoReview.status.displayName)
                            .font(.system(size: 31, weight: .bold, design: .default))
                            .foregroundStyle(CoachColor.text)

                        Text(redoReview.headline)
                            .font(.coachBody)
                            .foregroundStyle(CoachColor.text)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle()
                        .fill(CoachColor.line)
                        .frame(height: 1)

                    FeedbackSection(
                        title: "Still missing",
                        message: redoReview.stillMissing
                    )

                    FeedbackSection(
                        title: "Next attempt",
                        message: redoReview.nextAttempt
                    )

                    TrainingNoticeCard(
                        systemImage: "questionmark.circle",
                        message: "Your original feedback is saved in History.",
                        isDark: false
                    )
                } else {
                    TrainingNoticeCard(
                        systemImage: "info",
                        message: redoReviewNoticeMessage,
                        isDark: false
                    )
                }

                CoachPrimaryButton(title: "Start next") {
                    Task {
                        await startNext()
                    }
                }

                CoachSecondaryButton(title: "Back home") {
                    onBackHome()
                }
            }
            .padding(.top, CoachSpace.lg)
            .task(id: session.id) {
                await appModel.trackRedoReviewViewed()
            }
        }
    }

    private func startNext() async {
        await onStartNext()
    }

    private var redoReviewNoticeMessage: String {
        switch session.completionReason {
        case .redoReviewUnavailable:
            return "Redo review was unavailable. Your original feedback is saved in History."
        case .redoSkipped:
            return "You skipped the redo. Your original feedback is saved in History."
        case .redoReviewGenerated, nil:
            return "Your original feedback is saved in History."
        }
    }
}

private struct TerminalTrainingView: View {
    let title: String
    let message: String
    let onBackHome: () -> Void

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: CoachSpace.lg) {
                TrainingNavBar(title: "Result", isDark: false, onBack: {
                    onBackHome()
                })

                Text(title)
                    .font(.coachDisplay)
                    .foregroundStyle(CoachColor.text)

                TrainingNoticeCard(
                    systemImage: "info",
                    message: message,
                    isDark: false
                )

                CoachPrimaryButton(title: "Back home") {
                    onBackHome()
                }
            }
            .padding(.top, CoachSpace.lg)
        }
    }
}

private struct TrainingNavBar: View {
    let title: String
    var isDark = false
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isDark ? CoachColor.darkText : CoachColor.text)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isDark ? CoachColor.darkText : CoachColor.text)

            Spacer(minLength: 0)
        }
    }
}

private struct TrainingProgressBars: View {
    let activeCount: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < activeCount ? CoachColor.darkText : Color.white.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RecordingControlCard: View {
    let title: String
    let subtitle: String
    let elapsedSeconds: TimeInterval
    let state: AudioRecorder.RecordingState
    let canSubmit: Bool
    let isSubmitting: Bool
    let primaryTitle: String
    let secondaryTitle: String
    let primaryDisabled: Bool
    let circleIcon: String
    let circleAccessibilityLabel: String
    let onPrimary: () -> Void
    let onCircle: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CoachSpace.md) {
            Text(title)
                .font(.coachBodySecondary.weight(.medium))
                .foregroundStyle(CoachColor.darkMuted)

            HStack(alignment: .top) {
                Text(formatTime(elapsedSeconds))
                    .font(.system(size: 38, weight: .bold, design: .default))
                    .foregroundStyle(CoachColor.darkText)

                Spacer(minLength: CoachSpace.md)

                Button(action: onCircle) {
                    Circle()
                        .fill(circleFill)
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: circleIcon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(circleForeground)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(circleAccessibilityLabel)
            }

            Text(subtitle)
                .font(.coachBodySecondary)
                .foregroundStyle(CoachColor.darkMuted)

            if case .recorded = state, !canSubmit {
                TrainingNoticeCard(
                    systemImage: "volume.x",
                    message: "We couldn't hear enough audio. Record again when you're ready.",
                    isDark: true
                )
            }

            HStack(spacing: 12) {
                CoachPrimaryButton(
                    title: primaryTitle,
                    isLoading: isSubmitting,
                    isDisabled: primaryDisabled,
                    isDark: true,
                    action: onPrimary
                )
                .layoutPriority(1)

                CoachRecordingSecondaryButton(title: secondaryTitle, action: onSecondary)
                    .frame(width: 116)
            }
        }
        .padding(20)
        .background(CoachColor.darkPanel)
        .overlay {
            RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                .stroke(CoachColor.darkBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
    }

    private var circleFill: Color {
        switch state {
        case .idle:
            return CoachColor.blue
        case .recording:
            return CoachColor.darkText
        case .recorded:
            return CoachColor.darkText
        case .playing:
            return CoachColor.darkText
        }
    }

    private var circleForeground: Color {
        switch state {
        case .idle:
            return CoachColor.darkText
        case .recording:
            return CoachColor.dark
        case .recorded, .playing:
            return CoachColor.dark
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let remainingSeconds = total % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

private struct TrainingNoticeCard: View {
    let systemImage: String
    let message: String
    var isDark = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(isDark ? CoachColor.darkMuted : CoachColor.text48)
                .frame(width: 20, height: 20)

            Text(message)
                .font(.coachBodySecondary)
                .foregroundStyle(isDark ? CoachColor.darkMuted : CoachColor.text80)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(isDark ? CoachColor.darkPanel : CoachColor.surface)
        .overlay {
            RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                .stroke(isDark ? CoachColor.darkBorder : CoachColor.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
    }
}

private struct OriginalQuestionCard: View {
    let question: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Original question")
                .font(.coachSectionTitle)
                .foregroundStyle(CoachColor.darkMuted)

            Text(question)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CoachColor.darkText)
                .lineSpacing(2)
        }
        .padding(16)
        .background(CoachColor.darkPanel)
        .overlay {
            RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                .stroke(CoachColor.darkBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
    }
}

private struct RedoDetailsCard: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: CoachSpace.md) {
            TrainingNoticeCard(
                systemImage: "target",
                message: "Redo priority: \(redoPriority)",
                isDark: true
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Outline")
                    .font(.coachSectionTitle)
                    .foregroundStyle(CoachColor.darkMuted)

                Text(outlineText)
                    .font(.coachBodySecondary)
                    .foregroundStyle(CoachColor.darkText)
                    .lineSpacing(4)
            }
            .padding(16)
            .background(CoachColor.darkPanel)
            .overlay {
                RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                    .stroke(CoachColor.darkBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))

            OriginalQuestionCard(question: session.questionText)
        }
    }

    private var redoPriority: String {
        session.feedback?.redoPriority ?? "Focus on the decision you personally made."
    }

    private var outlineText: String {
        guard let outline = session.feedback?.redoOutline, !outline.isEmpty else {
            return "1. Context\n2. Your decision\n3. Tradeoff\n4. Result"
        }

        return outline.enumerated().map { index, item in
            "\(index + 1). \(item)"
        }.joined(separator: "\n")
    }
}

private struct FeedbackSection: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.coachSectionTitle)
                .foregroundStyle(CoachColor.text48)

            Text(message)
                .font(.coachBody)
                .foregroundStyle(CoachColor.text)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FeedbackOutlineSection: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Redo outline")
                .font(.coachSectionTitle)
                .foregroundStyle(CoachColor.text48)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Text("\(index + 1). \(item)")
                        .font(.coachBodySecondary)
                        .foregroundStyle(CoachColor.text)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(CoachColor.surface)
            .overlay {
                RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                    .stroke(CoachColor.line, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
        }
    }
}

private struct AssessmentSection: View {
    let assessments: [AssessmentLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assessment")
                .font(.coachSectionTitle)
                .foregroundStyle(CoachColor.text48)

            VStack(spacing: 10) {
                ForEach(assessments) { assessment in
                    AssessmentRow(assessment: assessment)
                }
            }
        }
    }
}

private struct AssessmentRow: View {
    let assessment: AssessmentLine

    var body: some View {
        HStack(spacing: 12) {
            Text(assessment.label)
                .font(.coachBody)
                .foregroundStyle(CoachColor.text)

            Spacer(minLength: 0)

            Text(assessment.status.rawValue)
                .font(.coachCaption.weight(.medium))
                .foregroundStyle(statusColor)
        }
        .padding(16)
        .background(CoachColor.surface)
        .overlay {
            RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                .stroke(CoachColor.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
    }

    private var statusColor: Color {
        switch assessment.status {
        case .strong:
            return CoachColor.blue
        case .mixed:
            return CoachColor.text48
        case .weak:
            return CoachColor.text
        }
    }
}

private func processingProgressCount(for status: TrainingSessionStatus) -> Int {
    switch status {
    case .questionGenerating, .waitingFirstAnswer, .firstAnswerProcessing:
        return 1
    case .followupGenerating, .waitingFollowupAnswer, .followupAnswerProcessing:
        return 2
    case .feedbackGenerating:
        return 3
    case .redoProcessing, .redoEvaluating:
        return 4
    case .redoAvailable, .completed, .abandoned, .failed:
        return 4
    }
}

private func processingTitle(for status: TrainingSessionStatus) -> String {
    switch status {
    case .questionGenerating:
        return "Preparing your personalized question"
    case .firstAnswerProcessing:
        return "Processing your answer"
    case .followupGenerating:
        return "Preparing your follow-up"
    case .waitingFollowupAnswer:
        return "Preparing your follow-up"
    case .followupAnswerProcessing:
        return "Processing your follow-up answer"
    case .feedbackGenerating:
        return "Building your feedback"
    case .redoProcessing:
        return "Processing your redo"
    case .redoEvaluating:
        return "Reviewing your redo"
    case .waitingFirstAnswer, .redoAvailable, .completed, .abandoned, .failed:
        return "Preparing your practice"
    }
}

private func processingSubtitle(for status: TrainingSessionStatus) -> String {
    switch status {
    case .questionGenerating:
        return "We're using your resume to choose a relevant prompt."
    case .firstAnswerProcessing:
        return "We're uploading and transcribing your response."
    case .followupGenerating, .waitingFollowupAnswer:
        return "We're finding the most useful gap to probe."
    case .followupAnswerProcessing:
        return "We're checking the audio before feedback."
    case .feedbackGenerating:
        return "We're turning your answers into a focused redo plan."
    case .redoProcessing:
        return "We're checking your second attempt."
    case .redoEvaluating:
        return "We're comparing it with your first answer."
    case .waitingFirstAnswer, .redoAvailable, .completed, .abandoned, .failed:
        return "We're getting everything ready."
    }
}

private extension ImprovementStatus {
    var displayName: String {
        switch self {
        case .improved:
            return "Improved"
        case .partiallyImproved:
            return "Partially improved"
        case .notImproved:
            return "Not improved"
        case .regressed:
            return "Regressed"
        }
    }
}
