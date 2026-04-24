import Foundation

protocol APITransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionAPITransport: APITransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoachServiceError.mockFailure(message: "The server returned a non-HTTP response.")
        }
        return (data, httpResponse)
    }
}

actor RemoteCoachService: CoachService {
    private let apiBaseURL: URL
    private let installationID: String
    private let localeIdentifier: String
    private let appVersion: String
    private let idempotencyKey: @Sendable () -> String
    private let transport: any APITransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var bootstrapContext: BootstrapContext?

    init(
        baseURL: URL,
        installationID: String,
        localeIdentifier: String = Locale.current.identifier,
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
        idempotencyKey: @escaping @Sendable () -> String = { UUID().uuidString },
        transport: any APITransport = URLSessionAPITransport()
    ) {
        self.apiBaseURL = Self.normalizedAPIBaseURL(from: baseURL)
        self.installationID = installationID
        self.localeIdentifier = localeIdentifier
        self.appVersion = appVersion
        self.idempotencyKey = idempotencyKey
        self.transport = transport

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func bootstrap() async throws -> BootstrapContext {
        let payload = BootstrapRequest(
            installationID: installationID,
            platform: "ios",
            locale: localeIdentifier,
            appVersion: appVersion
        )
        let data: BootstrapData = try await sendJSON(
            path: "/app-users/bootstrap",
            method: "POST",
            body: payload,
            requiresAuthorization: false,
            requiresIdempotencyKey: true
        )
        let context = BootstrapContext(
            appUserID: data.appUserId,
            accessToken: data.accessToken,
            appAccountToken: data.appAccountToken
        )
        bootstrapContext = context
        return context
    }

    func home() async throws -> HomeSnapshot {
        let data: HomeData = try await send(path: "/home", method: "GET")
        return data.domainHomeSnapshot()
    }

    func uploadResume(fileName: String) async throws -> ActiveResume {
        let body = multipartBody(
            fields: ["source_language": "en"],
            fileFieldName: "file",
            fileName: fileName,
            mimeType: mimeType(for: fileName),
            fileData: Data()
        )
        let data: ResumeUploadData = try await send(
            path: "/resumes",
            method: "POST",
            body: body.data,
            contentType: body.contentType,
            requiresIdempotencyKey: true
        )
        return data.domainActiveResume(fileName: fileName)
    }

    func deleteResume(mode: DeleteResumeMode) async throws -> HomeSnapshot {
        let payload = DeleteResumeRequest(deleteMode: mode.apiValue)
        let _: DeleteResumeData = try await sendJSON(
            path: "/resumes/active",
            method: "DELETE",
            body: payload,
            requiresIdempotencyKey: true
        )
        return try await home()
    }

    func createTrainingSession(focus: TrainingFocus?) async throws -> TrainingSession {
        let resolvedFocus = focus ?? .ownership
        let payload = CreateTrainingSessionRequest(trainingFocus: resolvedFocus.rawValue)
        let data: SessionMutationData = try await sendJSON(
            path: "/training-sessions",
            method: "POST",
            body: payload,
            requiresIdempotencyKey: true
        )
        return data.domainTrainingSession(fallbackFocus: resolvedFocus)
    }

    func session(id: String) async throws -> TrainingSession {
        let data: SessionDetailData = try await send(path: "/training-sessions/\(id)", method: "GET")
        return data.domainTrainingSession()
    }

    func submitFirstAnswer(sessionID: String) async throws -> TrainingSession {
        try await submitAudio(path: "/training-sessions/\(sessionID)/first-answer", fallbackSessionID: sessionID)
    }

    func submitFollowupAnswer(sessionID: String) async throws -> TrainingSession {
        try await submitAudio(path: "/training-sessions/\(sessionID)/follow-up-answer", fallbackSessionID: sessionID)
    }

    func submitRedo(sessionID: String) async throws -> TrainingSession {
        try await submitAudio(path: "/training-sessions/\(sessionID)/redo", fallbackSessionID: sessionID)
    }

    func skipRedo(sessionID: String) async throws -> TrainingSession {
        let data: SessionMutationData = try await send(
            path: "/training-sessions/\(sessionID)/skip-redo",
            method: "POST",
            requiresIdempotencyKey: true
        )
        return data.domainTrainingSession(fallbackFocus: .ownership)
    }

    func history() async throws -> [PracticeSummary] {
        let data: HistoryData = try await send(path: "/training-sessions/history", method: "GET", queryItems: [URLQueryItem(name: "limit", value: "10")])
        return data.items.map { $0.domainPracticeSummary() }
    }

    func historyDetail(id: String) async throws -> TrainingSession {
        try await session(id: id)
    }

    func deletePractice(id: String) async throws -> [PracticeSummary] {
        let _: DeletePracticeData = try await send(
            path: "/training-sessions/\(id)",
            method: "DELETE",
            requiresIdempotencyKey: true
        )
        return try await history()
    }

    func mockPurchaseSprintPack() async throws {
        throw CoachServiceError.mockFailure(message: "Remote purchase verification requires StoreKit transaction integration.")
    }

    func mockRestorePurchase() async throws {
        throw CoachServiceError.mockFailure(message: "Remote purchase restore requires StoreKit transaction integration.")
    }

    func deleteAllData() async throws -> BootstrapContext {
        let _: DeleteAllDataResponse = try await send(
            path: "/app-users/me/data",
            method: "DELETE",
            requiresIdempotencyKey: true
        )
        bootstrapContext = nil
        return try await bootstrap()
    }
}

private extension RemoteCoachService {
    static func normalizedAPIBaseURL(from baseURL: URL) -> URL {
        let trimmed = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.hasSuffix("/api/v1"), let url = URL(string: trimmed) {
            return url
        }
        return URL(string: "\(trimmed)/api/v1") ?? baseURL
    }

    func submitAudio(path: String, fallbackSessionID: String) async throws -> TrainingSession {
        let body = multipartBody(
            fields: ["duration_seconds": "0"],
            fileFieldName: "audio_file",
            fileName: "\(fallbackSessionID).m4a",
            mimeType: "audio/mp4",
            fileData: Data()
        )
        let data: SessionMutationData = try await send(
            path: path,
            method: "POST",
            body: body.data,
            contentType: body.contentType,
            requiresIdempotencyKey: true
        )
        return data.domainTrainingSession(fallbackFocus: .ownership)
    }

    func sendJSON<Body: Encodable, Payload: Decodable>(
        path: String,
        method: String,
        body: Body,
        requiresAuthorization: Bool = true,
        requiresIdempotencyKey: Bool = false
    ) async throws -> Payload {
        try await send(
            path: path,
            method: method,
            body: encoder.encode(body),
            contentType: "application/json",
            requiresAuthorization: requiresAuthorization,
            requiresIdempotencyKey: requiresIdempotencyKey
        )
    }

    func send<Payload: Decodable>(
        path: String,
        method: String,
        body: Data? = nil,
        contentType: String? = nil,
        requiresAuthorization: Bool = true,
        requiresIdempotencyKey: Bool = false,
        queryItems: [URLQueryItem] = [],
        idempotencyKeyOverride: String? = nil,
        allowsUnauthorizedRetry: Bool = true
    ) async throws -> Payload {
        var request = URLRequest(url: url(path: path, queryItems: queryItems))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let requestIdempotencyKey = requiresIdempotencyKey ? (idempotencyKeyOverride ?? idempotencyKey()) : nil

        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        if let body {
            request.httpBody = body
        }

        if let requestIdempotencyKey {
            request.setValue(requestIdempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }

        if requiresAuthorization {
            guard let accessToken = bootstrapContext?.accessToken else {
                throw CoachServiceError.notBootstrapped
            }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await transport.data(for: request)
        let envelope = try decoder.decode(APIEnvelope<Payload>.self, from: data)

        if let error = envelope.error {
            if error.code == "UNAUTHORIZED", requiresAuthorization, allowsUnauthorizedRetry {
                bootstrapContext = nil
                _ = try await bootstrap()
                return try await send(
                    path: path,
                    method: method,
                    body: body,
                    contentType: contentType,
                    requiresAuthorization: requiresAuthorization,
                    requiresIdempotencyKey: requiresIdempotencyKey,
                    queryItems: queryItems,
                    idempotencyKeyOverride: requestIdempotencyKey,
                    allowsUnauthorizedRetry: false
                )
            }
            throw mapAPIError(error)
        }

        guard (200..<300).contains(response.statusCode) else {
            throw CoachServiceError.mockFailure(message: "Unexpected API status \(response.statusCode).")
        }

        guard let payload = envelope.data else {
            throw CoachServiceError.mockFailure(message: "API response did not include data.")
        }

        return payload
    }

    func url(path: String, queryItems: [URLQueryItem]) -> URL {
        var url = apiBaseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        if !queryItems.isEmpty, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = queryItems
            url = components.url ?? url
        }
        return url
    }

    func multipartBody(
        fields: [String: String],
        fileFieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data
    ) -> (data: Data, contentType: String) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var data = Data()

        for (name, value) in fields {
            data.appendUTF8("--\(boundary)\r\n")
            data.appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            data.appendUTF8("\(value)\r\n")
        }

        data.appendUTF8("--\(boundary)\r\n")
        data.appendUTF8("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n")
        data.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        data.appendUTF8("\r\n--\(boundary)--\r\n")

        return (data, "multipart/form-data; boundary=\(boundary)")
    }

    func mimeType(for fileName: String) -> String {
        switch URL(fileURLWithPath: fileName).pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        default:
            return "application/octet-stream"
        }
    }

    func mapAPIError(_ error: APIErrorPayload) -> CoachServiceError {
        switch error.code {
        case "UNSUPPORTED_FILE_TYPE":
            return .unsupportedFileType
        case "RESUME_NOT_READY", "ACTIVE_RESUME_REQUIRED", "RESUME_PROFILE_UNUSABLE":
            return .resumeNotReady
        case "INSUFFICIENT_SESSION_CREDITS":
            return .noCredits
        case "ACTIVE_SESSION_EXISTS":
            return .activeSessionExists
        case "TRAINING_SESSION_NOT_FOUND":
            return .sessionNotFound
        case "TRAINING_SESSION_NOT_READY":
            return .invalidSessionState
        default:
            return .mockFailure(message: error.message)
        }
    }
}

private struct APIEnvelope<Payload: Decodable>: Decodable {
    let requestId: String
    let data: Payload?
    let error: APIErrorPayload?
}

private struct APIErrorPayload: Decodable {
    let code: String
    let message: String
}

private struct BootstrapRequest: Encodable {
    let installationID: String
    let platform: String
    let locale: String
    let appVersion: String

    enum CodingKeys: String, CodingKey {
        case installationID = "installation_id"
        case platform
        case locale
        case appVersion = "app_version"
    }
}

private struct BootstrapData: Decodable {
    let appUserId: String
    let accessToken: String
    let appAccountToken: String
}

private struct HomeData: Decodable {
    let usageBalance: UsageBalanceData
    let activeResume: ActiveResumeData?
    let activeSession: SessionSummaryData?
    let lastTrainingSummary: HistoryItemData?

    func domainHomeSnapshot() -> HomeSnapshot {
        HomeSnapshot(
            activeResume: activeResume?.domainActiveResume(),
            activeSession: activeSession?.domainTrainingSession(),
            credits: usageBalance.domainUsageBalance(),
            recentPractice: lastTrainingSummary.map { [$0.domainPracticeSummary()] } ?? []
        )
    }
}

private struct UsageBalanceData: Decodable {
    let freeSessionCreditsRemaining: Int
    let paidSessionCreditsRemaining: Int

    func domainUsageBalance() -> UsageBalance {
        UsageBalance(availableSessionCredits: freeSessionCreditsRemaining + paidSessionCreditsRemaining)
    }
}

private struct ActiveResumeData: Decodable {
    let status: String
    let profileQualityStatus: String?
    let fileName: String?

    func domainActiveResume() -> ActiveResume {
        let resolvedFileName = fileName ?? "Resume"
        switch (status, profileQualityStatus) {
        case ("uploading", _):
            return .uploading(fileName: resolvedFileName)
        case ("parsing", _):
            return .parsing(fileName: resolvedFileName)
        case ("ready", "limited"):
            return .readyLimited(fileName: resolvedFileName)
        case ("ready", "usable"), ("ready", nil):
            return .readyUsable(fileName: resolvedFileName)
        case ("ready", "unusable"), ("unusable", _):
            return .unusable(fileName: resolvedFileName, reason: "Resume profile is not trainable yet.")
        case ("failed", _):
            return .failed(fileName: resolvedFileName, reason: "Resume parsing failed.")
        default:
            return .failed(fileName: resolvedFileName, reason: "Unknown resume status.")
        }
    }
}

private struct ResumeUploadData: Decodable {
    let status: String

    func domainActiveResume(fileName: String) -> ActiveResume {
        switch status {
        case "parsing":
            return .parsing(fileName: fileName)
        case "ready":
            return .readyUsable(fileName: fileName)
        default:
            return .uploading(fileName: fileName)
        }
    }
}

private struct DeleteResumeRequest: Encodable {
    let deleteMode: String
}

private struct DeleteResumeData: Decodable {
    let deleted: Bool
}

private struct CreateTrainingSessionRequest: Encodable {
    let trainingFocus: String
}

private struct SessionMutationData: Decodable {
    let sessionId: String
    let status: TrainingSessionStatus
    let completionReason: CompletionReason?
    let trainingFocus: TrainingFocus?
    let questionText: String?

    func domainTrainingSession(fallbackFocus: TrainingFocus) -> TrainingSession {
        TrainingSession(
            id: sessionId,
            status: status,
            focus: trainingFocus ?? fallbackFocus,
            questionText: questionText ?? "",
            followupText: nil,
            feedback: nil,
            redoReview: nil,
            completionReason: completionReason,
            completedAt: nil
        )
    }
}

private struct SessionSummaryData: Decodable {
    let sessionId: String
    let status: TrainingSessionStatus
    let questionText: String?
    let trainingFocus: TrainingFocus?

    func domainTrainingSession() -> TrainingSession {
        TrainingSession(
            id: sessionId,
            status: status,
            focus: trainingFocus ?? .ownership,
            questionText: questionText ?? "",
            followupText: nil,
            feedback: nil,
            redoReview: nil,
            completionReason: nil,
            completedAt: nil
        )
    }
}

private struct SessionDetailData: Decodable {
    let sessionId: String
    let status: TrainingSessionStatus
    let completionReason: CompletionReason?
    let trainingFocus: TrainingFocus?
    let question: QuestionData?
    let followUp: FollowUpData?
    let feedback: FeedbackData?
    let redoReview: RedoReviewData?

    func domainTrainingSession() -> TrainingSession {
        TrainingSession(
            id: sessionId,
            status: status,
            focus: trainingFocus ?? question?.trainingFocus ?? .ownership,
            questionText: question?.questionText ?? "",
            followupText: followUp?.followUpText,
            feedback: feedback?.domainFeedback(),
            redoReview: redoReview?.domainRedoReview(),
            completionReason: completionReason,
            completedAt: nil
        )
    }
}

private struct QuestionData: Decodable {
    let questionText: String
    let trainingFocus: TrainingFocus?
}

private struct FollowUpData: Decodable {
    let followUpText: String
}

private struct FeedbackData: Decodable {
    let visibleAssessments: [String: VisibleAssessmentStatus]
    let strongestSignal: String
    let biggestGap: String
    let whyItMatters: String
    let redoPriority: String
    let redoOutline: [String]

    func domainFeedback() -> FeedbackPayload {
        FeedbackPayload(
            biggestGap: biggestGap,
            whyItMatters: whyItMatters,
            redoPriority: redoPriority,
            redoOutline: redoOutline,
            strongestSignal: strongestSignal,
            assessments: visibleAssessments.mapAssessmentLines()
        )
    }
}

private struct RedoReviewData: Decodable {
    let improvementStatus: ImprovementStatus
    let headline: String
    let stillMissing: String
    let nextAttempt: String

    func domainRedoReview() -> RedoReviewPayload {
        RedoReviewPayload(
            status: improvementStatus,
            headline: headline,
            stillMissing: stillMissing,
            nextAttempt: nextAttempt
        )
    }
}

private struct HistoryData: Decodable {
    let items: [HistoryItemData]
}

private struct HistoryItemData: Decodable {
    let sessionId: String
    let completedAt: Date?
    let trainingFocus: TrainingFocus?
    let questionText: String
    let completionReason: CompletionReason?
    let redoSubmitted: Bool?
    let redoImprovementStatus: ImprovementStatus?
    let finalVisibleAssessments: [String: VisibleAssessmentStatus]?

    func domainPracticeSummary() -> PracticeSummary {
        let focus = trainingFocus ?? .ownership
        return PracticeSummary(
            id: sessionId,
            title: focus.historyTitle,
            questionText: questionText,
            focusLabel: focus.displayName,
            completionDateText: completedAt?.monthDayText ?? "Recent",
            redoStatusText: redoStatusText,
            finalAssessmentSummary: finalAssessmentSummary
        )
    }

    private var redoStatusText: String {
        if redoSubmitted == true {
            return redoImprovementStatus?.displayName ?? "Redo submitted"
        }
        if completionReason == .redoSkipped {
            return "Redo skipped"
        }
        return "Original feedback saved"
    }

    private var finalAssessmentSummary: String {
        guard let finalVisibleAssessments, !finalVisibleAssessments.isEmpty else {
            return redoSubmitted == true ? "Redo review saved" : "Original feedback saved"
        }
        let strongCount = finalVisibleAssessments.values.filter { $0 == .strong }.count
        return "\(strongCount)/\(finalVisibleAssessments.count) strong signals"
    }
}

private struct DeletePracticeData: Decodable {
    let deleted: Bool
}

private struct DeleteAllDataResponse: Decodable {
    let deleted: Bool?
}

private extension DeleteResumeMode {
    var apiValue: String {
        switch self {
        case .resumeOnlyRedactedHistory:
            return "resume_only_redacted_history"
        case .resumeAndLinkedTraining:
            return "resume_and_linked_training"
        }
    }
}

private extension Dictionary where Key == String, Value == VisibleAssessmentStatus {
    func mapAssessmentLines() -> [AssessmentLine] {
        assessmentOrder.compactMap { key, label in
            guard let status = self[key] else { return nil }
            return AssessmentLine(id: key, label: label, status: status)
        }
    }

    private var assessmentOrder: [(String, String)] {
        [
            ("answered_the_question", "Answered the question"),
            ("story_fit", "Story fit"),
            ("personal_ownership", "Personal ownership"),
            ("evidence_and_outcome", "Evidence and outcome"),
            ("holds_up_under_follow_up", "Holds up under follow-up")
        ]
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

private extension Date {
    var monthDayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}
