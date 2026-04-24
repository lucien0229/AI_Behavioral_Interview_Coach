import XCTest
@testable import AI_Behavioral_Interview_Coach

final class MockCoachServiceTests: XCTestCase {
    func testBootstrapStartsWithNoResumeAndTwoCredits() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)

        _ = try await service.bootstrap()
        let home = try await service.home()

        XCTAssertNil(home.activeResume)
        XCTAssertNil(home.activeSession)
        XCTAssertEqual(home.credits.availableSessionCredits, 2)
    }

    func testStartSessionBlocksWhenActiveSessionExists() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        _ = try await service.createTrainingSession(focus: .ownership)

        do {
            _ = try await service.createTrainingSession(focus: .prioritization)
            XCTFail("Expected active session error")
        } catch CoachServiceError.activeSessionExists {
            XCTAssertTrue(true)
        }
    }

    func testHappyPathConsumesOneCreditAndCreatesHistory() async throws {
        var completionDate = DateComponents()
        completionDate.calendar = Calendar(identifier: .gregorian)
        completionDate.timeZone = TimeZone(secondsFromGMT: 0)
        completionDate.year = 2026
        completionDate.month = 4
        completionDate.day = 21
        let fixedCompletionDate = try XCTUnwrap(completionDate.date)
        let service = MockCoachService(processingDelayNanoseconds: 0, now: { fixedCompletionDate })
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        var session = try await service.createTrainingSession(focus: .ownership)

        XCTAssertEqual(session.status, .waitingFirstAnswer)

        session = try await service.submitFirstAnswer(sessionID: session.id, recording: .testFixture)
        XCTAssertEqual(session.status, .waitingFollowupAnswer)

        session = try await service.submitFollowupAnswer(sessionID: session.id, recording: .testFixture)
        XCTAssertEqual(session.status, .redoAvailable)

        let homeAfterFeedback = try await service.home()
        XCTAssertEqual(homeAfterFeedback.credits.availableSessionCredits, 1)

        session = try await service.skipRedo(sessionID: session.id)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.completionReason, .redoSkipped)

        let history = try await service.history()
        XCTAssertEqual(history.count, 1)
        let summary = try XCTUnwrap(history.first)
        XCTAssertEqual(summary.title, "Ownership under ambiguity")
        XCTAssertEqual(summary.questionText, "Tell me about a time you personally took ownership of an ambiguous problem and drove it to resolution.")
        XCTAssertEqual(summary.focusLabel, "Ownership")
        XCTAssertEqual(summary.completionDateText, "Apr 21")
        XCTAssertEqual(summary.redoStatusText, "Redo skipped")
        XCTAssertEqual(summary.finalAssessmentSummary, "Original feedback saved")
        XCTAssertEqual(summary.metadataLine, "Apr 21 · Ownership · Redo skipped · Original feedback saved")
    }

    func testMockPurchaseAddsCredits() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        try await service.mockPurchaseSprintPack()

        let home = try await service.home()
        XCTAssertEqual(home.credits.availableSessionCredits, 7)
    }

    func testMockRestoreAddsCredits() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        try await service.mockRestorePurchase()

        let home = try await service.home()
        XCTAssertEqual(home.credits.availableSessionCredits, 7)
    }

    func testActiveSessionErrorWinsOverMissingResumeAndNoCredits() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")

        var session = try await service.createTrainingSession(focus: .ownership)
        session = try await service.submitFirstAnswer(sessionID: session.id, recording: .testFixture)
        session = try await service.submitFollowupAnswer(sessionID: session.id, recording: .testFixture)
        _ = try await service.skipRedo(sessionID: session.id)

        session = try await service.createTrainingSession(focus: .prioritization)
        session = try await service.submitFirstAnswer(sessionID: session.id, recording: .testFixture)
        _ = try await service.submitFollowupAnswer(sessionID: session.id, recording: .testFixture)
        _ = try await service.deleteResume(mode: .resumeOnlyRedactedHistory)

        do {
            _ = try await service.createTrainingSession(focus: .ambiguity)
            XCTFail("Expected active session error")
        } catch CoachServiceError.activeSessionExists {
            XCTAssertTrue(true)
        }
    }

    func testConcurrentCreateOnlyLeavesOneActiveSession() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 50_000_000)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")

        async let ownershipResult = createSessionResult(service: service, focus: .ownership)
        async let prioritizationResult = createSessionResult(service: service, focus: .prioritization)
        let results = await [ownershipResult, prioritizationResult]

        let successCount = results.filter { result in
            if case .success = result {
                return true
            }
            return false
        }.count
        let activeSessionErrorCount = results.filter { result in
            if case .failure(.activeSessionExists) = result {
                return true
            }
            return false
        }.count
        let home = try await service.home()

        XCTAssertEqual(successCount, 1)
        XCTAssertEqual(activeSessionErrorCount, 1)
        XCTAssertNotNil(home.activeSession)
    }

    func testCancelUploadDuringProcessingDoesNotLeaveUploadingOrParsingResume() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 50_000_000)
        _ = try await service.bootstrap()

        let uploadTask = Task {
            await uploadResumeResult(service: service, fileName: "alex_pm_resume.pdf")
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        uploadTask.cancel()

        let uploadResult = await uploadTask.value
        let home = try await service.home()

        if case .success = uploadResult {
            XCTFail("Expected canceled upload to fail")
        }
        switch home.activeResume {
        case .some(.uploading), .some(.parsing):
            XCTFail("Expected canceled upload to clear transient resume state")
        default:
            XCTAssertNil(home.activeResume)
        }
    }

    func testCancelSupersedingUploadDoesNotRestoreStaleTransientUpload() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 50_000_000)
        _ = try await service.bootstrap()

        let firstUploadTask = Task {
            await uploadResumeResult(service: service, fileName: "first_resume.pdf")
        }
        try await Task.sleep(nanoseconds: 10_000_000)

        let secondUploadTask = Task {
            await uploadResumeResult(service: service, fileName: "second_resume.pdf")
        }
        try await Task.sleep(nanoseconds: 70_000_000)
        secondUploadTask.cancel()

        let firstUploadResult = await firstUploadTask.value
        let secondUploadResult = await secondUploadTask.value
        let home = try await service.home()

        if case .success = firstUploadResult {
            XCTFail("Expected superseded upload to fail")
        }
        if case .success = secondUploadResult {
            XCTFail("Expected canceled superseding upload to fail")
        }
        switch home.activeResume {
        case .some(.uploading), .some(.parsing):
            XCTFail("Expected canceled superseding upload not to restore stale transient state")
        default:
            XCTAssertTrue(true)
        }
    }

    func testCancelCreateSessionDuringQuestionGenerationClearsActiveSession() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 50_000_000)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")

        let createTask = Task {
            await createSessionResult(service: service, focus: .ownership)
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        createTask.cancel()

        let createResult = await createTask.value
        let home = try await service.home()

        if case .success = createResult {
            XCTFail("Expected canceled session creation to fail")
        }
        XCTAssertNil(home.activeSession)
    }

    func testCancelFollowupSubmitDuringFeedbackGenerationRevertsSessionAndKeepsCredit() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 50_000_000)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        var session = try await service.createTrainingSession(focus: .ownership)
        session = try await service.submitFirstAnswer(sessionID: session.id, recording: .testFixture)

        let submitTask = Task {
            await submitFollowupResult(service: service, sessionID: session.id)
        }
        try await Task.sleep(nanoseconds: 60_000_000)
        submitTask.cancel()

        let submitResult = await submitTask.value
        let home = try await service.home()

        if case .success = submitResult {
            XCTFail("Expected canceled followup submission to fail")
        }
        XCTAssertEqual(home.activeSession?.status, .waitingFollowupAnswer)
        XCTAssertNil(home.activeSession?.feedback)
        XCTAssertEqual(home.credits.availableSessionCredits, 2)
    }

    func testDeleteAllDataDuringFollowupProcessingDoesNotResurrectSessionOrConsumeCredit() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 50_000_000)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        var session = try await service.createTrainingSession(focus: .ownership)
        session = try await service.submitFirstAnswer(sessionID: session.id, recording: .testFixture)

        let submitTask = Task {
            await submitFollowupResult(service: service, sessionID: session.id)
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await service.deleteAllData()

        let submitResult = await submitTask.value
        let home = try await service.home()

        if case .success = submitResult {
            XCTFail("Expected stale followup submission to fail")
        }
        XCTAssertNil(home.activeSession)
        XCTAssertEqual(home.credits.availableSessionCredits, 2)
    }

    func testDeleteResumeDuringUploadDoesNotRecreateResume() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 50_000_000)
        _ = try await service.bootstrap()

        let uploadTask = Task {
            await uploadResumeResult(service: service, fileName: "alex_pm_resume.pdf")
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await service.deleteResume(mode: .resumeOnlyRedactedHistory)

        let uploadResult = await uploadTask.value
        let home = try await service.home()

        if case .success = uploadResult {
            XCTFail("Expected stale upload to fail")
        }
        XCTAssertNil(home.activeResume)
    }

    func testNewUploadImmediatelyAfterDeleteResumeIsNotCanceledByDelete() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 50_000_000)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "old_resume.pdf")
        _ = try await service.deleteResume(mode: .resumeOnlyRedactedHistory)

        let resume = try await service.uploadResume(fileName: "new_resume.pdf")
        let home = try await service.home()

        XCTAssertEqual(resume, .readyUsable(fileName: "new_resume.pdf"))
        XCTAssertEqual(home.activeResume, .readyUsable(fileName: "new_resume.pdf"))
    }

    func testDeleteAllDataThenPurchaseProducesInitialPlusPackCredits() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 50_000_000)
        _ = try await service.bootstrap()
        try await service.mockPurchaseSprintPack()
        _ = try await service.deleteAllData()
        try await service.mockPurchaseSprintPack()

        let home = try await service.home()
        XCTAssertEqual(home.credits.availableSessionCredits, 7)
    }
}

private func createSessionResult(
    service: MockCoachService,
    focus: TrainingFocus
) async -> Result<TrainingSession, CoachServiceError> {
    do {
        return .success(try await service.createTrainingSession(focus: focus))
    } catch let error as CoachServiceError {
        return .failure(error)
    } catch {
        return .failure(.mockFailure(message: String(describing: error)))
    }
}

private func submitFollowupResult(
    service: MockCoachService,
    sessionID: String
) async -> Result<TrainingSession, CoachServiceError> {
    do {
        return .success(try await service.submitFollowupAnswer(sessionID: sessionID, recording: .testFixture))
    } catch let error as CoachServiceError {
        return .failure(error)
    } catch {
        return .failure(.mockFailure(message: String(describing: error)))
    }
}

private func uploadResumeResult(
    service: MockCoachService,
    fileName: String
) async -> Result<ActiveResume, CoachServiceError> {
    do {
        return .success(try await service.uploadResume(fileName: fileName))
    } catch let error as CoachServiceError {
        return .failure(error)
    } catch {
        return .failure(.mockFailure(message: String(describing: error)))
    }
}
