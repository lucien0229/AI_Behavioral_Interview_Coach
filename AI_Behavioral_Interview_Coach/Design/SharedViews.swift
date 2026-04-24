import SwiftUI

struct CoachPrimaryButton: View {
    let title: String
    var isLoading = false
    var isDisabled = false
    var isDark = false
    var action: () -> Void

    private var backgroundColor: Color {
        if isDisabled && !isLoading {
            return isDark ? CoachColor.darkText.opacity(0.35) : CoachColor.blue.opacity(0.35)
        }
        return isDark ? CoachColor.darkText : CoachColor.blue
    }

    private var foregroundColor: Color {
        isDark ? CoachColor.dark : CoachColor.darkText
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CoachSpace.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                }
                Text(title)
                    .font(.coachButton)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: CoachSize.primaryButtonHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading || isDisabled)
    }
}

struct CoachSecondaryButton: View {
    let title: String
    var isDark = false
    var showsBorder = false
    var action: () -> Void

    private var textColor: Color {
        isDark ? CoachColor.darkLinkBlue : CoachColor.linkBlue
    }

    private var borderColor: Color? {
        guard showsBorder else { return nil }
        return isDark ? CoachColor.darkBorderStrong : CoachColor.blue
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.coachButton)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: CoachSize.secondaryButtonHeight)
                .background(CoachColor.transparent)
                .overlay {
                    if let borderColor {
                        RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct CoachRecordingSecondaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.coachButton)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(CoachColor.darkLinkBlue)
                .frame(maxWidth: .infinity)
                .frame(height: CoachSize.primaryButtonHeight)
                .background(CoachColor.recordingPanel)
                .overlay {
                    RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                        .stroke(CoachColor.darkBorderStrong, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct CoachRow: View {
    var systemImage: String?
    let title: String
    var detail: String?
    var showsChevron = true
    var isDark = false

    private var backgroundColor: Color {
        isDark ? CoachColor.darkPanelRaised : CoachColor.surface
    }

    private var borderColor: Color {
        isDark ? CoachColor.darkBorder : CoachColor.line
    }

    private var titleColor: Color {
        isDark ? CoachColor.darkText : CoachColor.text
    }

    private var detailColor: Color {
        isDark ? CoachColor.darkMuted : CoachColor.text48
    }

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(detailColor)
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(detailColor)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: CoachSpace.sm)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(detailColor)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: CoachSize.rowHeight)
        .background(backgroundColor)
        .overlay {
            RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
    }
}

struct CoachTag: View {
    let title: String
    var isSelected = false
    var isDark = false

    private var backgroundColor: Color {
        if isDark {
            return isSelected ? CoachColor.darkText : CoachColor.darkPanel
        }
        return isSelected ? CoachColor.surface : CoachColor.surfaceMuted
    }

    private var foregroundColor: Color {
        if isDark {
            return isSelected ? CoachColor.dark : CoachColor.darkText
        }
        return isSelected ? CoachColor.blue : CoachColor.text80
    }

    private var borderColor: Color {
        if isDark {
            return isSelected ? CoachColor.darkText : CoachColor.darkBorder
        }
        return isSelected ? CoachColor.blue : CoachColor.line
    }

    var body: some View {
        Text(title)
            .font(.coachCaption.weight(.medium))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: CoachSize.tagHeight)
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
    }
}

struct CoachSectionTitle: View {
    let title: String
    var isDark = false

    var body: some View {
        Text(title)
            .font(.coachSectionTitle)
            .foregroundStyle(isDark ? CoachColor.darkMuted : CoachColor.text48)
            .lineLimit(1)
    }
}

struct CoachScreen<Content: View>: View {
    let background: Color
    let content: Content

    init(background: Color, @ViewBuilder content: () -> Content) {
        self.background = background
        self.content = content()
    }

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            ScrollView {
                content
                    .padding(.horizontal, CoachSpace.screenHorizontal)
                    .padding(.top, CoachSpace.lg)
                    .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CoachLightScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        CoachScreen(background: CoachColor.canvas) {
            content
        }
    }
}

struct CoachDarkScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        CoachScreen(background: CoachColor.dark) {
            content
        }
    }
}

struct CoachLoadingView: View {
    let title: String
    let subtitle: String
    var isDark = false

    private var titleColor: Color {
        isDark ? CoachColor.darkText : CoachColor.text
    }

    private var subtitleColor: Color {
        isDark ? CoachColor.darkMuted : CoachColor.text80
    }

    var body: some View {
        ZStack {
            (isDark ? CoachColor.dark : CoachColor.canvas)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .tint(isDark ? CoachColor.darkText : CoachColor.blue)
                Text(title)
                    .font(.coachTitle)
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.coachBody)
                    .foregroundStyle(subtitleColor)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, CoachSpace.screenHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
