import Foundation
import XCTest
@testable import AI_Behavioral_Interview_Coach

final class RemoteCoachServiceTests: XCTestCase {
    func testBootstrapSendsExpectedPayloadAndAuthorizesHome() async throws {
        let transport = RecordingAPITransport(responses: [
            .json(bootstrapResponseJSON),
            .json(homeResponseJSON)
        ])
        let service = RemoteCoachService(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test")),
            installationID: "install-123",
            localeIdentifier: "en-US",
            appVersion: "1.0",
            idempotencyKey: { "idem-bootstrap" },
            transport: transport
        )

        let context = try await service.bootstrap()
        let home = try await service.home()
        let requests = await transport.requests()

        XCTAssertEqual(context.appUserID, "usr_123")
        XCTAssertEqual(context.accessToken, "opaque-token")
        XCTAssertEqual(home.activeResume, .readyUsable(fileName: "alex_resume.pdf"))
        XCTAssertEqual(home.credits.availableSessionCredits, 3)
        XCTAssertEqual(home.recentPractice.first?.id, "ses_done")
        XCTAssertEqual(requests.map(\.method), ["POST", "GET"])
        XCTAssertEqual(requests.map(\.path), ["/api/v1/app-users/bootstrap", "/api/v1/home"])
        XCTAssertNil(requests[0].headers["Authorization"])
        XCTAssertEqual(requests[0].headers["Idempotency-Key"], "idem-bootstrap")
        XCTAssertEqual(requests[0].jsonBody["installation_id"] as? String, "install-123")
        XCTAssertEqual(requests[0].jsonBody["platform"] as? String, "ios")
        XCTAssertEqual(requests[0].jsonBody["locale"] as? String, "en-US")
        XCTAssertEqual(requests[0].jsonBody["app_version"] as? String, "1.0")
        XCTAssertEqual(requests[1].headers["Authorization"], "Bearer opaque-token")
    }

    func testCreateTrainingSessionSendsFocusWithIdempotencyKey() async throws {
        let transport = RecordingAPITransport(responses: [
            .json(bootstrapResponseJSON),
            .json(createSessionResponseJSON)
        ])
        let service = RemoteCoachService(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test/api/v1")),
            installationID: "install-123",
            localeIdentifier: "en-US",
            appVersion: "1.0",
            idempotencyKey: { "idem-create-session" },
            transport: transport
        )

        _ = try await service.bootstrap()
        let session = try await service.createTrainingSession(focus: .conflictHandling)
        let requests = await transport.requests()

        XCTAssertEqual(session.id, "ses_new")
        XCTAssertEqual(session.status, .questionGenerating)
        XCTAssertEqual(session.focus, .conflictHandling)
        XCTAssertEqual(requests[1].method, "POST")
        XCTAssertEqual(requests[1].path, "/api/v1/training-sessions")
        XCTAssertEqual(requests[1].headers["Authorization"], "Bearer opaque-token")
        XCTAssertEqual(requests[1].headers["Idempotency-Key"], "idem-create-session")
        XCTAssertEqual(requests[1].jsonBody["training_focus"] as? String, "conflict_handling")
    }

    func testKnownApiErrorCodesMapToCoachServiceErrors() async throws {
        let transport = RecordingAPITransport(responses: [
            .json(bootstrapResponseJSON),
            .json(insufficientCreditsResponseJSON, statusCode: 402)
        ])
        let service = RemoteCoachService(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test")),
            installationID: "install-123",
            localeIdentifier: "en-US",
            appVersion: "1.0",
            idempotencyKey: { "idem-create-session" },
            transport: transport
        )

        _ = try await service.bootstrap()

        do {
            _ = try await service.createTrainingSession(focus: .ownership)
            XCTFail("Expected no credits error")
        } catch CoachServiceError.noCredits {
            XCTAssertTrue(true)
        }
    }

    func testUnauthorizedWriteBootstrapsAndRetriesWithSameIdempotencyKey() async throws {
        let keys = LockedKeySequence([
            "idem-bootstrap-1",
            "idem-create-session",
            "idem-bootstrap-2"
        ])
        let transport = RecordingAPITransport(responses: [
            .json(bootstrapResponseJSON),
            .json(unauthorizedResponseJSON, statusCode: 401),
            .json(refreshedBootstrapResponseJSON),
            .json(createSessionResponseJSON)
        ])
        let service = RemoteCoachService(
            baseURL: try XCTUnwrap(URL(string: "https://api.example.test")),
            installationID: "install-123",
            localeIdentifier: "en-US",
            appVersion: "1.0",
            idempotencyKey: { keys.next() },
            transport: transport
        )

        _ = try await service.bootstrap()
        let session = try await service.createTrainingSession(focus: .ownership)
        let requests = await transport.requests()

        XCTAssertEqual(session.id, "ses_new")
        XCTAssertEqual(requests.map(\.path), [
            "/api/v1/app-users/bootstrap",
            "/api/v1/training-sessions",
            "/api/v1/app-users/bootstrap",
            "/api/v1/training-sessions"
        ])
        XCTAssertEqual(requests[1].headers["Authorization"], "Bearer opaque-token")
        XCTAssertEqual(requests[1].headers["Idempotency-Key"], "idem-create-session")
        XCTAssertEqual(requests[3].headers["Authorization"], "Bearer refreshed-token")
        XCTAssertEqual(requests[3].headers["Idempotency-Key"], "idem-create-session")
    }
}

private actor RecordingAPITransport: APITransport {
    private var responses: [RecordingAPIResponse]
    private var capturedRequests: [CapturedAPIRequest] = []

    init(responses: [RecordingAPIResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequests.append(CapturedAPIRequest(request: request))
        let response = responses.removeFirst()
        let httpResponse = try XCTUnwrap(
            HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: response.statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
        )
        return (Data(response.body.utf8), httpResponse)
    }

    func requests() -> [CapturedAPIRequest] {
        capturedRequests
    }
}

private struct RecordingAPIResponse: Sendable {
    let body: String
    let statusCode: Int

    static func json(_ body: String, statusCode: Int = 200) -> RecordingAPIResponse {
        RecordingAPIResponse(body: body, statusCode: statusCode)
    }
}

private struct CapturedAPIRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data?

    init(request: URLRequest) {
        method = request.httpMethod ?? ""
        path = request.url?.path ?? ""
        headers = request.allHTTPHeaderFields ?? [:]
        body = request.httpBody
    }

    var jsonBody: [String: Any] {
        guard let body,
              let object = try? JSONSerialization.jsonObject(with: body),
              let dictionary = object as? [String: Any] else {
            return [:]
        }
        return dictionary
    }
}

private final class LockedKeySequence: @unchecked Sendable {
    private let lock = NSLock()
    private var keys: [String]

    init(_ keys: [String]) {
        self.keys = keys
    }

    func next() -> String {
        lock.lock()
        defer { lock.unlock() }
        return keys.removeFirst()
    }
}

private let bootstrapResponseJSON = """
{
  "request_id": "req_boot",
  "data": {
    "app_user_id": "usr_123",
    "access_token": "opaque-token",
    "expires_at": "2026-05-21T10:00:00Z",
    "app_account_token": "00000000-0000-4000-8000-000000000000",
    "usage_balance": {
      "free_session_credits_remaining": 2,
      "paid_session_credits_remaining": 1,
      "reserved_session_credits": 0
    },
    "active_resume": null,
    "active_session": null
  },
  "error": null
}
"""

private let homeResponseJSON = """
{
  "request_id": "req_home",
  "data": {
    "app_user_id": "usr_123",
    "usage_balance": {
      "free_session_credits_remaining": 2,
      "paid_session_credits_remaining": 1,
      "reserved_session_credits": 0
    },
    "active_resume": {
      "resume_id": "res_123",
      "status": "ready",
      "profile_quality_status": "usable",
      "file_name": "alex_resume.pdf"
    },
    "active_session": null,
    "last_training_summary": {
      "session_id": "ses_done",
      "question_text": "Tell me about a time you owned an ambiguous launch.",
      "completed_at": "2026-04-21T10:08:13Z",
      "training_focus": "ownership",
      "completion_reason": "redo_skipped",
      "redo_submitted": false
    }
  },
  "error": null
}
"""

private let createSessionResponseJSON = """
{
  "request_id": "req_create",
  "data": {
    "session_id": "ses_new",
    "status": "question_generating",
    "billing_source": "free",
    "credit_state": "reserved"
  },
  "error": null
}
"""

private let insufficientCreditsResponseJSON = """
{
  "request_id": "req_error",
  "data": null,
  "error": {
    "code": "INSUFFICIENT_SESSION_CREDITS",
    "message": "No credits remain.",
    "details": {}
  }
}
"""

private let unauthorizedResponseJSON = """
{
  "request_id": "req_unauthorized",
  "data": null,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Token expired.",
    "details": {}
  }
}
"""

private let refreshedBootstrapResponseJSON = """
{
  "request_id": "req_boot_refreshed",
  "data": {
    "app_user_id": "usr_123",
    "access_token": "refreshed-token",
    "expires_at": "2026-05-21T11:00:00Z",
    "app_account_token": "00000000-0000-4000-8000-000000000000",
    "usage_balance": {
      "free_session_credits_remaining": 2,
      "paid_session_credits_remaining": 1,
      "reserved_session_credits": 0
    },
    "active_resume": null,
    "active_session": null
  },
  "error": null
}
"""
