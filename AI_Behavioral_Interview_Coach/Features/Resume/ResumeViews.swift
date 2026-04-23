import SwiftUI
import UniformTypeIdentifiers

struct ResumeUploadView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isImporting = false
    @State private var uploadTask: Task<Void, Never>?

    private let importContentTypes: [UTType] = {
        var contentTypes: [UTType] = [.pdf]
        if let docxType = UTType(filenameExtension: "docx", conformingTo: .data) {
            contentTypes.append(docxType)
        }
        return contentTypes
    }()

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                FeatureNavBar(title: "Upload resume")

                VStack(alignment: .leading, spacing: 18) {
                    Text("Upload your resume")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(CoachColor.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("PDF or DOCX, up to 5 MB")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(CoachColor.text80)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    isImporting = true
                } label: {
                    ResumeUploadDropZone()
                }
                .buttonStyle(.plain)
                .fileImporter(
                    isPresented: $isImporting,
                    allowedContentTypes: importContentTypes,
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let fileURL = urls.first else { return }
                        uploadTask?.cancel()
                        uploadTask = Task {
                            await appModel.uploadResume(fileName: fileURL.lastPathComponent)
                        }
                    case .failure:
                        break
                    }
                }

                CoachPrimaryButton(title: "Choose file") {
                    isImporting = true
                }

                ResumePrivacyCard()

                CoachSecondaryButton(title: "Privacy notice") {
                    appModel.navigationPath.append(.privacyNotice)
                }
            }
        }
        .onDisappear {
            uploadTask?.cancel()
            uploadTask = nil
        }
    }
}

struct ResumeManageView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        CoachLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                FeatureNavBar(title: "Resume")

                switch appModel.homeSnapshot.activeResume {
                case .readyUsable:
                    ResumeReadyContent()
                case .readyLimited:
                    ResumeReadyContent()
                case .unusable(_, let reason):
                    ResumeBlockedContent(
                        title: "This resume needs more detail",
                        message: reason,
                        primaryTitle: "Upload another resume"
                    )
                case .failed(_, let reason):
                    ResumeBlockedContent(
                        title: "Resume upload failed",
                        message: reason,
                        primaryTitle: "Upload another resume"
                    )
                case .uploading(let fileName):
                    ResumeProcessingContent(
                        fileName: fileName,
                        message: "Uploading · usually under a minute"
                    )
                case .parsing(let fileName):
                    ResumeProcessingContent(
                        fileName: fileName,
                        message: "Parsing · usually under a minute"
                    )
                case .none:
                    ResumeBlockedContent(
                        title: "No resume available",
                        message: "Upload a PDF or DOCX resume to start personalized practice.",
                        primaryTitle: "Upload resume"
                    )
                }
            }
        }
    }
}

struct FeatureNavBar: View {
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

private struct ResumeUploadDropZone: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(CoachColor.text)

            VStack(spacing: 8) {
                Text("Choose a resume file")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(CoachColor.text)

                Text("English resumes work best in this version.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(CoachColor.text48)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 234)
        .background(CoachColor.surface)
        .overlay {
            RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [7, 6]))
                .foregroundStyle(CoachColor.line)
        }
        .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
    }
}

private struct ResumePrivacyCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.checkerboard")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(CoachColor.text48)
                .frame(width: 22, height: 22)

            Text("Your resume is used to make practice questions personal.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(CoachColor.text80)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoachColor.surface)
        .overlay {
            RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                .stroke(CoachColor.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
    }
}

private struct ResumeReadyContent: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Resume ready")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(CoachColor.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Product manager with launch, roadmap, and stakeholder alignment experience.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(CoachColor.text80)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                CoachSectionTitle(title: "Anchor experiences")

                CoachRow(
                    systemImage: "checklist",
                    title: "3 recommended practice cues",
                    detail: "Prioritization, influence, ambiguity",
                    showsChevron: false
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                CoachSectionTitle(title: "Strength signals")
                HStack(spacing: 12) {
                    CoachTag(title: "Ownership")
                    CoachTag(title: "Prioritization")
                    CoachTag(title: "Influence")
                }
            }

            ResumePrivacyCard()

            CoachPrimaryButton(title: "Start training") {
                Task { await appModel.startTraining() }
            }

            CoachSecondaryButton(title: "Upload better resume", showsBorder: true) {
                appModel.navigationPath.append(.resumeUpload)
            }

            CoachSecondaryButton(title: "Delete resume") {
                appModel.activeSheet = .deleteConfirmation(.resumeOnly)
            }
        }
    }
}

private struct ResumeBlockedContent: View {
    @Environment(AppModel.self) private var appModel
    let title: String
    let message: String
    let primaryTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(CoachColor.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(CoachColor.text80)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CoachPrimaryButton(title: primaryTitle) {
                appModel.navigationPath.append(.resumeUpload)
            }

            CoachSecondaryButton(title: "Delete resume") {
                appModel.activeSheet = .deleteConfirmation(.resumeOnly)
            }
        }
    }
}

private struct ResumeProcessingContent: View {
    @Environment(AppModel.self) private var appModel
    let fileName: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Reading your resume")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(CoachColor.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text("We'll let you know when personalized practice is ready.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(CoachColor.text80)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CoachRow(
                systemImage: "doc.text",
                title: fileName,
                detail: message,
                showsChevron: false
            )

            CoachPrimaryButton(title: "Cancel resume") {
                appModel.activeSheet = .deleteConfirmation(.resumeOnly)
            }

            CoachSecondaryButton(title: "Upload another resume") {
                appModel.navigationPath.append(.resumeUpload)
            }
        }
    }
}
