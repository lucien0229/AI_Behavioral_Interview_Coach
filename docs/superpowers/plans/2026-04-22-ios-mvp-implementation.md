# iOS MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a runnable iPhone-only SwiftUI MVP for AI Behavioral Interview Coach with real local recording, an in-app mock service, and UI implemented from the Pencil `.pen` design source.

**Architecture:** Create a single SwiftUI iOS application target with feature folders, a `CoachService` protocol, an in-memory `MockCoachService`, and a root `AppModel`. Keep service logic outside views so the mock service can later be replaced with a real API client.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, AVFoundation, UniformTypeIdentifiers, XCTest, Xcode 26.3, XcodeGen as a development-only project generator.

---

## Preconditions

- Current working directory: `/Users/wxm/Desktop/workspace/AI_Behavioral_Interview_Coach_Pencil`
- Product spec: `docs/superpowers/specs/2026-04-22-ios-mvp-design.md`
- UI source of truth: `docs/design/ios_hifi_pencil_original/AI_Behavioral_Interview_Coach_iOS_HiFi_v1.pen`
- Renderer reference: `docs/design/ios_hifi_pencil_original/ai_bic_original_renderer.js`
- Review PNGs: `docs/design/ios_hifi_pencil_original/exports/named_png/`

## File Structure

Create these files and directories:

```text
.gitignore
Project.yml
AI_Behavioral_Interview_Coach/
  AI_Behavioral_Interview_CoachApp.swift
  Info.plist
  App/
    AppModel.swift
    AppRoute.swift
  Domain/
    CoachModels.swift
    HomePrimaryState.swift
  Services/
    CoachService.swift
    MockCoachService.swift
  Audio/
    AudioRecorder.swift
  Design/
    DesignTokens.swift
    SharedViews.swift
  Features/
    Launch/LaunchView.swift
    Home/HomeView.swift
    Resume/ResumeViews.swift
    Training/TrainingViews.swift
    History/HistoryViews.swift
    Billing/BillingViews.swift
    Settings/SettingsViews.swift
AI_Behavioral_Interview_CoachTests/
  HomePrimaryStateTests.swift
  MockCoachServiceTests.swift
  TrainingRoutingTests.swift
```

Responsibilities:

- `Project.yml`: reproducible Xcode project definition.
- `AppModel.swift`: root state, bootstrap, home refresh, routing, sheets, and error presentation.
- `CoachModels.swift`: stable domain types shared by service, app model, views, and tests.
- `HomePrimaryState.swift`: single source for Home primary CTA priority.
- `CoachService.swift`: async business interface.
- `MockCoachService.swift`: in-memory server-like state machine.
- `AudioRecorder.swift`: real microphone permission, recording, playback, rerecord, and temporary file lifecycle.
- `DesignTokens.swift`: colors, spacing, typography helpers, and radius values from the Pencil renderer.
- `SharedViews.swift`: reusable buttons, rows, cards, sheets, loading, and empty/error surfaces.
- Feature view files: SwiftUI rendering only; no mock state machine logic inside views.

---

## Task 1: Repository And Project Scaffold

**Files:**
- Create: `.gitignore`
- Create: `Project.yml`
- Create: `AI_Behavioral_Interview_Coach/AI_Behavioral_Interview_CoachApp.swift`
- Create: `AI_Behavioral_Interview_Coach/Info.plist`

- [ ] **Step 1: Initialize git only if the workspace is still not a repository**

Run:

```bash
git rev-parse --show-toplevel || git init
```

Expected: command prints a repo root after initialization.

- [ ] **Step 2: Create `.gitignore`**

Create `.gitignore` with:

```gitignore
.DS_Store
.build/
DerivedData/
*.xcuserdata/
*.xcuserstate
.superpowers/
AI_Behavioral_Interview_Coach.xcodeproj/
```

- [ ] **Step 3: Ensure XcodeGen is available**

Run:

```bash
command -v xcodegen || brew install xcodegen
```

Expected: `command -v xcodegen` prints a path after the command completes.

- [ ] **Step 4: Create `Project.yml`**

Create `Project.yml` with:

```yaml
name: AI_Behavioral_Interview_Coach
options:
  bundleIdPrefix: com.wxm
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    IPHONEOS_DEPLOYMENT_TARGET: "17.0"
targets:
  AI_Behavioral_Interview_Coach:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: AI_Behavioral_Interview_Coach
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.wxm.AIBehavioralInterviewCoach
        PRODUCT_NAME: AI Behavioral Interview Coach
        INFOPLIST_FILE: AI_Behavioral_Interview_Coach/Info.plist
        TARGETED_DEVICE_FAMILY: "1"
        SUPPORTS_MACCATALYST: "NO"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    scheme:
      testTargets:
        - AI_Behavioral_Interview_CoachTests
  AI_Behavioral_Interview_CoachTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: AI_Behavioral_Interview_CoachTests
    dependencies:
      - target: AI_Behavioral_Interview_Coach
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.wxm.AIBehavioralInterviewCoachTests
        GENERATE_INFOPLIST_FILE: "YES"
schemes:
  AI_Behavioral_Interview_Coach:
    build:
      targets:
        AI_Behavioral_Interview_Coach: all
    test:
      targets:
        - AI_Behavioral_Interview_CoachTests
```

- [ ] **Step 5: Create app entry point**

Create `AI_Behavioral_Interview_Coach/AI_Behavioral_Interview_CoachApp.swift` with:

```swift
import SwiftUI

@main
struct AI_Behavioral_Interview_CoachApp: App {
    @State private var appModel = AppModel(service: MockCoachService())

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environment(appModel)
        }
    }
}
```

- [ ] **Step 6: Create `Info.plist`**

Create `AI_Behavioral_Interview_Coach/Info.plist` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Interview Coach</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Interview Coach records your practice answers so you can complete a mock behavioral interview round.</string>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
  </array>
</dict>
</plist>
```

- [ ] **Step 7: Generate the Xcode project**

Run:

```bash
xcodegen generate
```

Expected: `AI_Behavioral_Interview_Coach.xcodeproj` is created.

- [ ] **Step 8: Commit scaffold**

Run:

```bash
git add .gitignore Project.yml AI_Behavioral_Interview_Coach/AI_Behavioral_Interview_CoachApp.swift AI_Behavioral_Interview_Coach/Info.plist docs/superpowers/specs/2026-04-22-ios-mvp-design.md docs/superpowers/plans/2026-04-22-ios-mvp-implementation.md
git commit -m "chore: scaffold iOS MVP project"
```

Expected: commit succeeds.

---

## Task 2: Domain Models And Home Primary State

**Files:**
- Create: `AI_Behavioral_Interview_Coach/Domain/CoachModels.swift`
- Create: `AI_Behavioral_Interview_Coach/Domain/HomePrimaryState.swift`
- Test: `AI_Behavioral_Interview_CoachTests/HomePrimaryStateTests.swift`

- [ ] **Step 1: Write failing Home priority tests**

Create `AI_Behavioral_Interview_CoachTests/HomePrimaryStateTests.swift` with:

```swift
import XCTest
@testable import AI_Behavioral_Interview_Coach

final class HomePrimaryStateTests: XCTestCase {
    func testActiveSessionWinsOverReadyResumeAndNoCredits() {
        let snapshot = HomeSnapshot(
            activeResume: .readyUsable(fileName: "alex_pm_resume.pdf"),
            activeSession: TrainingSession.fixture(status: .redoAvailable),
            credits: UsageBalance(availableSessionCredits: 0),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .activeSession)
    }

    func testNoResumeShowsUpload() {
        let snapshot = HomeSnapshot(activeResume: nil, activeSession: nil, credits: .initialFree, recentPractice: [])

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .noResume)
    }

    func testReadyResumeWithNoCreditsShowsOutOfCredits() {
        let snapshot = HomeSnapshot(
            activeResume: .readyUsable(fileName: "alex_pm_resume.pdf"),
            activeSession: nil,
            credits: UsageBalance(availableSessionCredits: 0),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .outOfCredits)
    }

    func testLimitedReadyResumeShowsReadyLimitedWhenCreditsRemain() {
        let snapshot = HomeSnapshot(
            activeResume: .readyLimited(fileName: "alex_pm_resume.pdf"),
            activeSession: nil,
            credits: UsageBalance(availableSessionCredits: 1),
            recentPractice: []
        )

        XCTAssertEqual(HomePrimaryState.derive(from: snapshot), .readyLimited)
    }
}
```

- [ ] **Step 2: Run the failing tests**

Run:

```bash
xcodegen generate
xcodebuild test -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Expected: build fails because domain types are not defined.

- [ ] **Step 3: Create domain models**

Create `AI_Behavioral_Interview_Coach/Domain/CoachModels.swift` with:

```swift
import Foundation

enum TrainingFocus: String, CaseIterable, Identifiable, Codable, Equatable {
    case ownership
    case prioritization
    case crossFunctionalInfluence = "cross_functional_influence"
    case conflictHandling = "conflict_handling"
    case failureLearning = "failure_learning"
    case ambiguity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ownership: "Ownership"
        case .prioritization: "Prioritization"
        case .crossFunctionalInfluence: "Cross-functional Influence"
        case .conflictHandling: "Conflict Handling"
        case .failureLearning: "Failure / Learning"
        case .ambiguity: "Ambiguity"
        }
    }
}

enum VisibleAssessmentStatus: String, Codable, Equatable {
    case strong = "Strong"
    case mixed = "Mixed"
    case weak = "Weak"
}

enum ImprovementStatus: String, Codable, Equatable {
    case improved
    case partiallyImproved = "partially_improved"
    case notImproved = "not_improved"
    case regressed
}

enum ActiveResume: Equatable {
    case uploading(fileName: String)
    case parsing(fileName: String)
    case readyUsable(fileName: String)
    case readyLimited(fileName: String)
    case unusable(fileName: String, reason: String)
    case failed(fileName: String, reason: String)

    var fileName: String {
        switch self {
        case .uploading(let fileName), .parsing(let fileName), .readyUsable(let fileName), .readyLimited(let fileName), .unusable(let fileName, _), .failed(let fileName, _):
            fileName
        }
    }
}

struct UsageBalance: Equatable {
    var availableSessionCredits: Int

    static let initialFree = UsageBalance(availableSessionCredits: 2)
}

enum TrainingSessionStatus: String, Codable, Equatable {
    case questionGenerating = "question_generating"
    case waitingFirstAnswer = "waiting_first_answer"
    case firstAnswerProcessing = "first_answer_processing"
    case followupGenerating = "followup_generating"
    case waitingFollowupAnswer = "waiting_followup_answer"
    case followupAnswerProcessing = "followup_answer_processing"
    case feedbackGenerating = "feedback_generating"
    case redoAvailable = "redo_available"
    case redoProcessing = "redo_processing"
    case redoEvaluating = "redo_evaluating"
    case completed
    case abandoned
    case failed
}

enum CompletionReason: String, Codable, Equatable {
    case redoReviewGenerated = "redo_review_generated"
    case redoSkipped = "redo_skipped"
    case redoReviewUnavailable = "redo_review_unavailable"
}

struct AssessmentLine: Identifiable, Equatable {
    let id: String
    let label: String
    let status: VisibleAssessmentStatus
}

struct FeedbackPayload: Equatable {
    let biggestGap: String
    let whyItMatters: String
    let redoPriority: String
    let redoOutline: [String]
    let strongestSignal: String
    let assessments: [AssessmentLine]
}

struct RedoReviewPayload: Equatable {
    let status: ImprovementStatus
    let headline: String
    let stillMissing: String
    let nextAttempt: String
}

struct TrainingSession: Identifiable, Equatable {
    let id: String
    var status: TrainingSessionStatus
    var focus: TrainingFocus
    var questionText: String
    var followupText: String?
    var feedback: FeedbackPayload?
    var redoReview: RedoReviewPayload?
    var completionReason: CompletionReason?

    var isTerminal: Bool {
        status == .completed || status == .abandoned || status == .failed
    }

    static func fixture(status: TrainingSessionStatus = .waitingFirstAnswer) -> TrainingSession {
        TrainingSession(
            id: "session_fixture",
            status: status,
            focus: .ownership,
            questionText: "Tell me about a time you had to make a high-stakes prioritization decision with incomplete information.",
            followupText: status == .waitingFollowupAnswer ? "What specific decision did you personally make at that point?" : nil,
            feedback: status == .redoAvailable ? .fixture : nil,
            redoReview: nil,
            completionReason: nil
        )
    }
}

extension FeedbackPayload {
    static let fixture = FeedbackPayload(
        biggestGap: "You still did not make your personal ownership explicit enough.",
        whyItMatters: "Interviewers must see what you personally decided or drove.",
        redoPriority: "Name your decision, tradeoff, and result before adding team context.",
        redoOutline: ["Set context in one sentence.", "State the decision you owned.", "Explain the tradeoff.", "Close with the result."],
        strongestSignal: "You picked a relevant example with real business context.",
        assessments: [
            AssessmentLine(id: "answer_fit", label: "Answer fit", status: .strong),
            AssessmentLine(id: "story", label: "Story", status: .strong),
            AssessmentLine(id: "personal_ownership", label: "Personal ownership", status: .weak),
            AssessmentLine(id: "evidence", label: "Evidence and outcome", status: .mixed)
        ]
    )
}

struct PracticeSummary: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let status: String
}

struct HomeSnapshot: Equatable {
    var activeResume: ActiveResume?
    var activeSession: TrainingSession?
    var credits: UsageBalance
    var recentPractice: [PracticeSummary]
}
```

- [ ] **Step 4: Create Home primary state derivation**

Create `AI_Behavioral_Interview_Coach/Domain/HomePrimaryState.swift` with:

```swift
enum HomePrimaryState: Equatable {
    case activeSession
    case noResume
    case resumeProcessing
    case resumeFailed
    case resumeUnusable
    case outOfCredits
    case readyLimited
    case ready

    static func derive(from snapshot: HomeSnapshot) -> HomePrimaryState {
        if snapshot.activeSession != nil {
            return .activeSession
        }

        guard let resume = snapshot.activeResume else {
            return .noResume
        }

        switch resume {
        case .uploading, .parsing:
            return .resumeProcessing
        case .failed:
            return .resumeFailed
        case .unusable:
            return .resumeUnusable
        case .readyLimited:
            if snapshot.credits.availableSessionCredits == 0 {
                return .outOfCredits
            }
            return .readyLimited
        case .readyUsable:
            if snapshot.credits.availableSessionCredits == 0 {
                return .outOfCredits
            }
            return .ready
        }
    }
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
xcodegen generate
xcodebuild test -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Expected: `HomePrimaryStateTests` passes or the next failure only concerns missing app view files.

- [ ] **Step 6: Commit domain model**

Run:

```bash
git add AI_Behavioral_Interview_Coach/Domain AI_Behavioral_Interview_CoachTests/HomePrimaryStateTests.swift
git commit -m "feat: add coach domain models"
```

Expected: commit succeeds.

---

## Task 3: CoachService Protocol And Mock State Machine

**Files:**
- Create: `AI_Behavioral_Interview_Coach/Services/CoachService.swift`
- Create: `AI_Behavioral_Interview_Coach/Services/MockCoachService.swift`
- Test: `AI_Behavioral_Interview_CoachTests/MockCoachServiceTests.swift`

- [ ] **Step 1: Write failing service tests**

Create `AI_Behavioral_Interview_CoachTests/MockCoachServiceTests.swift` with:

```swift
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
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        _ = try await service.uploadResume(fileName: "alex_pm_resume.pdf")
        var session = try await service.createTrainingSession(focus: .ownership)

        XCTAssertEqual(session.status, .waitingFirstAnswer)

        session = try await service.submitFirstAnswer(sessionID: session.id)
        XCTAssertEqual(session.status, .waitingFollowupAnswer)

        session = try await service.submitFollowupAnswer(sessionID: session.id)
        XCTAssertEqual(session.status, .redoAvailable)

        let homeAfterFeedback = try await service.home()
        XCTAssertEqual(homeAfterFeedback.credits.availableSessionCredits, 1)

        session = try await service.skipRedo(sessionID: session.id)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.completionReason, .redoSkipped)

        let history = try await service.history()
        XCTAssertEqual(history.count, 1)
    }

    func testMockPurchaseAddsCredits() async throws {
        let service = MockCoachService(processingDelayNanoseconds: 0)
        _ = try await service.bootstrap()
        try await service.mockPurchaseSprintPack()

        let home = try await service.home()
        XCTAssertEqual(home.credits.availableSessionCredits, 7)
    }
}
```

- [ ] **Step 2: Run failing service tests**

Run:

```bash
xcodegen generate
xcodebuild test -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:AI_Behavioral_Interview_CoachTests/MockCoachServiceTests
```

Expected: build fails because `CoachService` and `MockCoachService` are not defined.

- [ ] **Step 3: Create service protocol**

Create `AI_Behavioral_Interview_Coach/Services/CoachService.swift` with:

```swift
import Foundation

struct BootstrapContext: Equatable {
    let appUserID: String
    let accessToken: String
    let appAccountToken: String
}

enum CoachServiceError: Error, Equatable {
    case notBootstrapped
    case unsupportedFileType
    case fileTooLarge
    case resumeNotReady
    case noCredits
    case activeSessionExists
    case sessionNotFound
    case invalidSessionState
    case mockFailure(message: String)
}

protocol CoachService {
    func bootstrap() async throws -> BootstrapContext
    func home() async throws -> HomeSnapshot
    func uploadResume(fileName: String) async throws -> ActiveResume
    func deleteResume(mode: DeleteResumeMode) async throws -> HomeSnapshot
    func createTrainingSession(focus: TrainingFocus) async throws -> TrainingSession
    func session(id: String) async throws -> TrainingSession
    func submitFirstAnswer(sessionID: String) async throws -> TrainingSession
    func submitFollowupAnswer(sessionID: String) async throws -> TrainingSession
    func submitRedo(sessionID: String) async throws -> TrainingSession
    func skipRedo(sessionID: String) async throws -> TrainingSession
    func history() async throws -> [PracticeSummary]
    func historyDetail(id: String) async throws -> TrainingSession
    func deletePractice(id: String) async throws -> [PracticeSummary]
    func mockPurchaseSprintPack() async throws
    func mockRestorePurchase() async throws
    func deleteAllData() async throws -> BootstrapContext
}

enum DeleteResumeMode: Equatable {
    case resumeOnlyRedactedHistory
    case resumeAndLinkedTraining
}
```

- [ ] **Step 4: Create mock service**

Create `AI_Behavioral_Interview_Coach/Services/MockCoachService.swift` with:

```swift
import Foundation

actor MockCoachService: CoachService {
    private let processingDelayNanoseconds: UInt64
    private var context: BootstrapContext?
    private var resume: ActiveResume?
    private var credits = UsageBalance.initialFree
    private var activeSession: TrainingSession?
    private var completedSessions: [TrainingSession] = []

    init(processingDelayNanoseconds: UInt64 = 350_000_000) {
        self.processingDelayNanoseconds = processingDelayNanoseconds
    }

    func bootstrap() async throws -> BootstrapContext {
        if let context {
            return context
        }
        let newContext = BootstrapContext(
            appUserID: "app_user_mock_001",
            accessToken: "mock_access_token",
            appAccountToken: UUID().uuidString
        )
        context = newContext
        return newContext
    }

    func home() async throws -> HomeSnapshot {
        try requireBootstrap()
        return HomeSnapshot(activeResume: resume, activeSession: activeSession, credits: credits, recentPractice: summaries())
    }

    func uploadResume(fileName: String) async throws -> ActiveResume {
        try requireBootstrap()
        let lower = fileName.lowercased()
        guard lower.hasSuffix(".pdf") || lower.hasSuffix(".docx") else {
            throw CoachServiceError.unsupportedFileType
        }
        resume = .parsing(fileName: fileName)
        try await delay()
        resume = .readyUsable(fileName: fileName)
        return resume!
    }

    func deleteResume(mode: DeleteResumeMode) async throws -> HomeSnapshot {
        try requireBootstrap()
        resume = nil
        if mode == .resumeAndLinkedTraining {
            activeSession = nil
            completedSessions.removeAll()
        }
        return try await home()
    }

    func createTrainingSession(focus: TrainingFocus) async throws -> TrainingSession {
        try requireBootstrap()
        guard activeSession == nil else {
            throw CoachServiceError.activeSessionExists
        }
        guard let resume else {
            throw CoachServiceError.resumeNotReady
        }
        switch resume {
        case .readyUsable, .readyLimited:
            break
        case .uploading, .parsing, .unusable, .failed:
            throw CoachServiceError.resumeNotReady
        }
        guard credits.availableSessionCredits > 0 else {
            throw CoachServiceError.noCredits
        }
        var session = TrainingSession.fixture(status: .questionGenerating)
        session = TrainingSession(
            id: "session_\(Int(Date().timeIntervalSince1970))",
            status: .questionGenerating,
            focus: focus,
            questionText: "Tell me about a time you had to make a high-stakes prioritization decision with incomplete information.",
            followupText: nil,
            feedback: nil,
            redoReview: nil,
            completionReason: nil
        )
        activeSession = session
        try await delay()
        activeSession?.status = .waitingFirstAnswer
        return activeSession!
    }

    func session(id: String) async throws -> TrainingSession {
        try requireBootstrap()
        if let activeSession, activeSession.id == id {
            return activeSession
        }
        if let completed = completedSessions.first(where: { $0.id == id }) {
            return completed
        }
        throw CoachServiceError.sessionNotFound
    }

    func submitFirstAnswer(sessionID: String) async throws -> TrainingSession {
        var session = try await mutableActiveSession(id: sessionID, expected: .waitingFirstAnswer)
        session.status = .firstAnswerProcessing
        activeSession = session
        try await delay()
        session.status = .followupGenerating
        activeSession = session
        try await delay()
        session.status = .waitingFollowupAnswer
        session.followupText = "What specific decision did you personally make at that point?"
        activeSession = session
        return session
    }

    func submitFollowupAnswer(sessionID: String) async throws -> TrainingSession {
        var session = try await mutableActiveSession(id: sessionID, expected: .waitingFollowupAnswer)
        session.status = .followupAnswerProcessing
        activeSession = session
        try await delay()
        session.status = .feedbackGenerating
        activeSession = session
        try await delay()
        session.status = .redoAvailable
        session.feedback = .fixture
        credits.availableSessionCredits = max(0, credits.availableSessionCredits - 1)
        activeSession = session
        return session
    }

    func submitRedo(sessionID: String) async throws -> TrainingSession {
        var session = try await mutableActiveSession(id: sessionID, expected: .redoAvailable)
        session.status = .redoProcessing
        activeSession = session
        try await delay()
        session.status = .redoEvaluating
        activeSession = session
        try await delay()
        session.status = .completed
        session.completionReason = .redoReviewGenerated
        session.redoReview = RedoReviewPayload(
            status: .partiallyImproved,
            headline: "You made the decision clearer and reduced the team-level vagueness.",
            stillMissing: "The result needs one metric or business outcome to be fully convincing.",
            nextAttempt: "Add one measurable outcome on the next practice round."
        )
        complete(session)
        return session
    }

    func skipRedo(sessionID: String) async throws -> TrainingSession {
        var session = try await mutableActiveSession(id: sessionID, expected: .redoAvailable)
        session.status = .completed
        session.completionReason = .redoSkipped
        complete(session)
        return session
    }

    func history() async throws -> [PracticeSummary] {
        try requireBootstrap()
        return summaries()
    }

    func historyDetail(id: String) async throws -> TrainingSession {
        try await session(id: id)
    }

    func deletePractice(id: String) async throws -> [PracticeSummary] {
        try requireBootstrap()
        completedSessions.removeAll { $0.id == id }
        return summaries()
    }

    func mockPurchaseSprintPack() async throws {
        try requireBootstrap()
        credits.availableSessionCredits += 5
    }

    func mockRestorePurchase() async throws {
        try requireBootstrap()
        credits.availableSessionCredits += 5
    }

    func deleteAllData() async throws -> BootstrapContext {
        context = nil
        resume = nil
        credits = .initialFree
        activeSession = nil
        completedSessions.removeAll()
        return try await bootstrap()
    }

    private func requireBootstrap() throws {
        if context == nil {
            throw CoachServiceError.notBootstrapped
        }
    }

    private func delay() async throws {
        if processingDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: processingDelayNanoseconds)
        }
    }

    private func mutableActiveSession(id: String, expected: TrainingSessionStatus) async throws -> TrainingSession {
        try requireBootstrap()
        guard let session = activeSession, session.id == id else {
            throw CoachServiceError.sessionNotFound
        }
        guard session.status == expected else {
            throw CoachServiceError.invalidSessionState
        }
        return session
    }

    private func complete(_ session: TrainingSession) {
        activeSession = nil
        completedSessions.insert(session, at: 0)
    }

    private func summaries() -> [PracticeSummary] {
        completedSessions.map { session in
            PracticeSummary(
                id: session.id,
                title: "Prioritization decision",
                subtitle: "Apr 22 · \(session.focus.displayName)",
                status: session.completionReason == .redoSkipped ? "Redo skipped · Mixed" : "Partially improved"
            )
        }
    }
}
```

- [ ] **Step 5: Run service tests**

Run:

```bash
xcodegen generate
xcodebuild test -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:AI_Behavioral_Interview_CoachTests/MockCoachServiceTests
```

Expected: `MockCoachServiceTests` passes.

- [ ] **Step 6: Commit mock service**

Run:

```bash
git add AI_Behavioral_Interview_Coach/Services AI_Behavioral_Interview_CoachTests/MockCoachServiceTests.swift
git commit -m "feat: add mock coach service"
```

Expected: commit succeeds.

---

## Task 4: App Model And Routing

**Files:**
- Create: `AI_Behavioral_Interview_Coach/App/AppRoute.swift`
- Create: `AI_Behavioral_Interview_Coach/App/AppModel.swift`
- Test: `AI_Behavioral_Interview_CoachTests/TrainingRoutingTests.swift`

- [ ] **Step 1: Write failing routing tests**

Create `AI_Behavioral_Interview_CoachTests/TrainingRoutingTests.swift` with:

```swift
import XCTest
@testable import AI_Behavioral_Interview_Coach

final class TrainingRoutingTests: XCTestCase {
    func testWaitingFirstAnswerRoutesToFirstAnswer() {
        XCTAssertEqual(TrainingScreenState.route(for: .fixture(status: .waitingFirstAnswer)), .firstAnswer)
    }

    func testWaitingFollowupRoutesToFollowupAnswer() {
        XCTAssertEqual(TrainingScreenState.route(for: .fixture(status: .waitingFollowupAnswer)), .followupAnswer)
    }

    func testRedoAvailableRoutesToFeedback() {
        XCTAssertEqual(TrainingScreenState.route(for: .fixture(status: .redoAvailable)), .feedback)
    }

    func testCompletedRoutesToCompleted() {
        XCTAssertEqual(TrainingScreenState.route(for: .fixture(status: .completed)), .completed)
    }
}
```

- [ ] **Step 2: Run failing routing tests**

Run:

```bash
xcodebuild test -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:AI_Behavioral_Interview_CoachTests/TrainingRoutingTests
```

Expected: build fails because `TrainingScreenState` is not defined.

- [ ] **Step 3: Create routes and sheet models**

Create `AI_Behavioral_Interview_Coach/App/AppRoute.swift` with:

```swift
import Foundation

enum AppRoute: Hashable {
    case resumeUpload
    case resumeManage
    case trainingSession(sessionID: String)
    case historyList
    case historyDetail(sessionID: String)
    case settings
    case privacyNotice
}

enum AppSheet: Identifiable, Equatable {
    case focusPicker
    case paywall
    case deleteConfirmation(DeleteIntent)
    case microphonePermission
    case apiError(String)

    var id: String {
        switch self {
        case .focusPicker: "focusPicker"
        case .paywall: "paywall"
        case .deleteConfirmation(let intent): "deleteConfirmation-\(intent.id)"
        case .microphonePermission: "microphonePermission"
        case .apiError(let message): "apiError-\(message)"
        }
    }
}

enum DeleteIntent: String, Identifiable, Equatable {
    case resumeOnly
    case resumeAndTraining
    case practiceRound
    case allData

    var id: String { rawValue }
}

enum TrainingScreenState: Equatable {
    case processing
    case firstAnswer
    case followupAnswer
    case feedback
    case redo
    case completed
    case failed

    static func route(for session: TrainingSession) -> TrainingScreenState {
        switch session.status {
        case .questionGenerating, .firstAnswerProcessing, .followupGenerating, .followupAnswerProcessing, .feedbackGenerating, .redoProcessing, .redoEvaluating:
            return .processing
        case .waitingFirstAnswer:
            return .firstAnswer
        case .waitingFollowupAnswer:
            return .followupAnswer
        case .redoAvailable:
            return .feedback
        case .completed:
            return .completed
        case .abandoned, .failed:
            return .failed
        }
    }
}
```

- [ ] **Step 4: Create root app model**

Create `AI_Behavioral_Interview_Coach/App/AppModel.swift` with:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private let service: CoachService

    var isBootstrapping = true
    var homeSnapshot = HomeSnapshot(activeResume: nil, activeSession: nil, credits: .initialFree, recentPractice: [])
    var navigationPath: [AppRoute] = []
    var activeSheet: AppSheet?
    var selectedFocus: TrainingFocus = .ownership
    var currentSession: TrainingSession?
    var history: [PracticeSummary] = []

    init(service: CoachService) {
        self.service = service
    }

    var homePrimaryState: HomePrimaryState {
        HomePrimaryState.derive(from: homeSnapshot)
    }

    func bootstrap() async {
        isBootstrapping = true
        do {
            _ = try await service.bootstrap()
            homeSnapshot = try await service.home()
        } catch {
            activeSheet = .apiError("We could not prepare your practice space. Please try again.")
        }
        isBootstrapping = false
    }

    func refreshHome() async {
        do {
            homeSnapshot = try await service.home()
            history = try await service.history()
        } catch {
            activeSheet = .apiError("We could not refresh your latest practice state.")
        }
    }

    func uploadResume(fileName: String) async {
        do {
            _ = try await service.uploadResume(fileName: fileName)
            homeSnapshot = try await service.home()
            navigationPath.append(.resumeManage)
        } catch CoachServiceError.unsupportedFileType {
            activeSheet = .apiError("Only PDF or DOCX resumes are supported in this version.")
        } catch {
            activeSheet = .apiError("Resume upload failed. Please choose another file.")
        }
    }

    func startTraining() async {
        do {
            let session = try await service.createTrainingSession(focus: selectedFocus)
            currentSession = session
            navigationPath.append(.trainingSession(sessionID: session.id))
            homeSnapshot = try await service.home()
        } catch CoachServiceError.noCredits {
            activeSheet = .paywall
        } catch CoachServiceError.activeSessionExists {
            if let active = homeSnapshot.activeSession {
                navigationPath.append(.trainingSession(sessionID: active.id))
            }
        } catch {
            activeSheet = .apiError("We could not start this practice round.")
        }
    }

    func loadSession(id: String) async {
        do {
            currentSession = try await service.session(id: id)
        } catch {
            activeSheet = .apiError("We could not load this practice round.")
        }
    }

    func submitFirstAnswer() async {
        guard let currentSession else { return }
        do {
            self.currentSession = try await service.submitFirstAnswer(sessionID: currentSession.id)
        } catch {
            activeSheet = .apiError("We could not submit your answer. Please try again.")
        }
    }

    func submitFollowupAnswer() async {
        guard let currentSession else { return }
        do {
            self.currentSession = try await service.submitFollowupAnswer(sessionID: currentSession.id)
            homeSnapshot = try await service.home()
        } catch {
            activeSheet = .apiError("We could not submit your follow-up answer. Please try again.")
        }
    }

    func submitRedo() async {
        guard let currentSession else { return }
        do {
            self.currentSession = try await service.submitRedo(sessionID: currentSession.id)
            await refreshHome()
        } catch {
            activeSheet = .apiError("We could not evaluate your redo. Your original feedback is saved.")
        }
    }

    func skipRedo() async {
        guard let currentSession else { return }
        do {
            self.currentSession = try await service.skipRedo(sessionID: currentSession.id)
            await refreshHome()
        } catch {
            activeSheet = .apiError("We could not finish this round. Please try again.")
        }
    }

    func buySprintPack() async {
        do {
            try await service.mockPurchaseSprintPack()
            activeSheet = nil
            await refreshHome()
        } catch {
            activeSheet = .apiError("Purchase could not be completed.")
        }
    }

    func deleteAllData() async {
        do {
            _ = try await service.deleteAllData()
            navigationPath.removeAll()
            await refreshHome()
        } catch {
            activeSheet = .apiError("We could not delete your app data.")
        }
    }
}
```

- [ ] **Step 5: Run routing tests**

Run:

```bash
xcodegen generate
xcodebuild test -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' -only-testing:AI_Behavioral_Interview_CoachTests/TrainingRoutingTests
```

Expected: `TrainingRoutingTests` passes.

- [ ] **Step 6: Commit app model**

Run:

```bash
git add AI_Behavioral_Interview_Coach/App AI_Behavioral_Interview_CoachTests/TrainingRoutingTests.swift
git commit -m "feat: add app routing model"
```

Expected: commit succeeds.

---

## Task 5: Design Tokens And Shared SwiftUI Components

**Files:**
- Create: `AI_Behavioral_Interview_Coach/Design/DesignTokens.swift`
- Create: `AI_Behavioral_Interview_Coach/Design/SharedViews.swift`

- [ ] **Step 1: Create design tokens from the Pencil renderer**

Create `AI_Behavioral_Interview_Coach/Design/DesignTokens.swift` with:

```swift
import SwiftUI

enum CoachColor {
    static let canvas = Color(hex: 0xF5F5F7)
    static let surface = Color.white
    static let surfaceMuted = Color(hex: 0xFAFAFC)
    static let text = Color(hex: 0x1D1D1F)
    static let text80 = Color(hex: 0x4A4A4D)
    static let text48 = Color(hex: 0x7C7C80)
    static let line = Color(hex: 0xD2D2D7)
    static let blue = Color(hex: 0x0071E3)
    static let linkBlue = Color(hex: 0x0066CC)
    static let dark = Color.black
    static let darkPanel = Color(hex: 0x272729)
    static let darkPanelRaised = Color(hex: 0x2A2A2D)
    static let darkMuted = Color(hex: 0xB8B8BD)
}

enum CoachSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let screenX: CGFloat = 24
}

enum CoachRadius {
    static let small: CGFloat = 5
    static let standard: CGFloat = 8
    static let sheet: CGFloat = 24
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

extension Font {
    static var coachDisplay: Font { .system(size: 27, weight: .bold, design: .default) }
    static var coachTitle: Font { .system(size: 24, weight: .bold, design: .default) }
    static var coachCardTitle: Font { .system(size: 17, weight: .semibold, design: .default) }
    static var coachBody: Font { .system(size: 15, weight: .regular, design: .default) }
    static var coachCaption: Font { .system(size: 12, weight: .regular, design: .default) }
    static var coachButton: Font { .system(size: 17, weight: .medium, design: .default) }
}
```

- [ ] **Step 2: Create shared components**

Create `AI_Behavioral_Interview_Coach/Design/SharedViews.swift` with:

```swift
import SwiftUI

struct CoachPrimaryButton: View {
    let title: String
    var isLoading = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CoachSpace.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.coachButton)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(.white)
            .background(CoachColor.blue)
            .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
        }
        .disabled(isLoading)
    }
}

struct CoachSecondaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.coachButton)
            .foregroundStyle(CoachColor.linkBlue)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
    }
}

struct CoachRow: View {
    let systemImage: String
    let title: String
    let detail: String
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(CoachColor.text48)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CoachColor.text)
                Text(detail)
                    .font(.coachCaption)
                    .foregroundStyle(CoachColor.text48)
            }
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CoachColor.text48)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 66)
        .background(CoachColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CoachRadius.standard, style: .continuous)
                .stroke(CoachColor.line, lineWidth: 1)
        )
    }
}

struct CoachScreen<Content: View>: View {
    let background: Color
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                content
                    .padding(.horizontal, CoachSpace.screenX)
                    .padding(.top, CoachSpace.lg)
                    .padding(.bottom, 40)
            }
        }
    }
}

struct CoachLoadingView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Text(title)
                .font(.coachTitle)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.coachBody)
                .foregroundStyle(CoachColor.darkMuted)
                .multilineTextAlignment(.center)
            ProgressView()
                .tint(.white)
            Spacer()
        }
        .padding(CoachSpace.screenX)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CoachColor.dark)
        .foregroundStyle(.white)
    }
}
```

- [ ] **Step 3: Build after shared UI**

Run:

```bash
xcodegen generate
xcodebuild build -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Expected: build fails only for feature views not created yet.

- [ ] **Step 4: Commit shared UI**

Run:

```bash
git add AI_Behavioral_Interview_Coach/Design
git commit -m "feat: add coach design system"
```

Expected: commit succeeds.

---

## Task 6: Launch, Home, Resume, And Focus Picker

**Files:**
- Create: `AI_Behavioral_Interview_Coach/Features/Launch/LaunchView.swift`
- Create: `AI_Behavioral_Interview_Coach/Features/Home/HomeView.swift`
- Create: `AI_Behavioral_Interview_Coach/Features/Resume/ResumeViews.swift`

- [ ] **Step 1: Create Launch view**

Create `AI_Behavioral_Interview_Coach/Features/Launch/LaunchView.swift` with:

```swift
import SwiftUI

struct LaunchView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if appModel.isBootstrapping {
                CoachLoadingView(
                    title: "Interview Coach",
                    subtitle: "Preparing your practice space"
                )
                .task {
                    await appModel.bootstrap()
                }
            } else {
                HomeRootView()
            }
        }
    }
}
```

- [ ] **Step 2: Create Home root navigation**

Create `AI_Behavioral_Interview_Coach/Features/Home/HomeView.swift` with:

```swift
import SwiftUI

struct HomeRootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        NavigationStack(path: $appModel.navigationPath) {
            HomeView()
                .navigationBarHidden(true)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .resumeUpload:
                        ResumeUploadView()
                    case .resumeManage:
                        ResumeManageView()
                    case .trainingSession(let sessionID):
                        TrainingSessionView(sessionID: sessionID)
                    case .historyList:
                        HistoryListView()
                    case .historyDetail(let sessionID):
                        HistoryDetailView(sessionID: sessionID)
                    case .settings:
                        SettingsView()
                    case .privacyNotice:
                        PrivacyNoticeView()
                    }
                }
                .sheet(item: $appModel.activeSheet) { sheet in
                    switch sheet {
                    case .focusPicker:
                        FocusPickerSheet()
                    case .paywall:
                        PaywallSheet()
                    case .deleteConfirmation(let intent):
                        DeleteConfirmationSheet(intent: intent)
                    case .microphonePermission:
                        MicrophonePermissionSheet()
                    case .apiError(let message):
                        APIErrorSheet(message: message)
                    }
                }
        }
    }
}

struct HomeView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        CoachScreen(background: CoachColor.canvas) {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Interview Coach")
                            .font(.coachDisplay)
                        Text(homeSubtitle)
                            .font(.coachCaption)
                            .foregroundStyle(CoachColor.text48)
                    }
                    Spacer()
                    Button {
                        appModel.navigationPath.append(.settings)
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(CoachColor.text)
                            .frame(width: 36, height: 36)
                            .background(CoachColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard))
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(headline)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(CoachColor.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(bodyCopy)
                        .font(.coachBody)
                        .foregroundStyle(CoachColor.text80)
                }

                CoachPrimaryButton(title: primaryButtonTitle) {
                    handlePrimaryAction()
                }

                if appModel.homePrimaryState == .ready {
                    CoachSecondaryButton(title: "Choose focus") {
                        appModel.activeSheet = .focusPicker
                    }
                }

                homeRows
            }
        }
        .task {
            await appModel.refreshHome()
        }
    }

    private var homeSubtitle: String {
        switch appModel.homePrimaryState {
        case .noResume: "Resume required to begin"
        case .activeSession: "Continue where you left off"
        case .resumeProcessing: "Resume preparation"
        case .outOfCredits: "Personalized practice is ready"
        default: "Your next round is ready"
        }
    }

    private var headline: String {
        switch appModel.homePrimaryState {
        case .activeSession: "Practice in progress"
        case .noResume: "Upload your resume to start"
        case .resumeProcessing: "Reading your resume"
        case .resumeFailed, .resumeUnusable: "This resume needs more detail"
        case .outOfCredits: "You're out of practice credits"
        case .readyLimited, .ready: "Ready for a practice round"
        }
    }

    private var bodyCopy: String {
        switch appModel.homePrimaryState {
        case .activeSession: "Feedback is ready. Complete the redo step or skip it to finish."
        case .noResume: "Your practice questions will be based on your real experience."
        case .resumeProcessing: "We'll let you know when personalized practice is ready."
        case .resumeFailed, .resumeUnusable: "We couldn't find enough concrete experience to build useful practice."
        case .outOfCredits: "Buy a Sprint Pack to continue personalized practice."
        case .readyLimited, .ready: "One question, one follow-up, and focused feedback."
        }
    }

    private var primaryButtonTitle: String {
        switch appModel.homePrimaryState {
        case .activeSession: "Continue session"
        case .noResume: "Upload resume"
        case .resumeProcessing: "View status"
        case .resumeFailed, .resumeUnusable: "Upload another resume"
        case .outOfCredits: "Buy Sprint Pack"
        case .readyLimited, .ready: "Start training"
        }
    }

    @ViewBuilder private var homeRows: some View {
        VStack(spacing: 8) {
            if let resume = appModel.homeSnapshot.activeResume {
                CoachRow(systemImage: "doc.text", title: resume.fileName, detail: resumeDetail(for: resume))
            } else {
                CoachRow(systemImage: "doc.text", title: "Resume", detail: "No active resume", showsChevron: false)
            }
            CoachRow(systemImage: "creditcard", title: "Practice credits", detail: "\(appModel.homeSnapshot.credits.availableSessionCredits) rounds available", showsChevron: false)
            if let recent = appModel.homeSnapshot.recentPractice.first {
                Button {
                    appModel.navigationPath.append(.historyDetail(sessionID: recent.id))
                } label: {
                    CoachRow(systemImage: "bubble.left", title: "Last practice", detail: recent.status)
                }
                .buttonStyle(.plain)
            }
            Button {
                appModel.navigationPath.append(.historyList)
            } label: {
                CoachRow(systemImage: "clock.arrow.circlepath", title: "View all history", detail: "Recent practice summaries")
            }
            .buttonStyle(.plain)
        }
    }

    private func resumeDetail(for resume: ActiveResume) -> String {
        switch resume {
        case .readyUsable: "Ready · 3 anchor experiences"
        case .readyLimited: "Limited · practice is available"
        case .parsing: "Parsing"
        case .uploading: "Uploading"
        case .unusable: "Needs more detail"
        case .failed: "Upload failed"
        }
    }

    private func handlePrimaryAction() {
        switch appModel.homePrimaryState {
        case .activeSession:
            if let session = appModel.homeSnapshot.activeSession {
                appModel.navigationPath.append(.trainingSession(sessionID: session.id))
            }
        case .noResume, .resumeFailed, .resumeUnusable:
            appModel.navigationPath.append(.resumeUpload)
        case .resumeProcessing:
            appModel.navigationPath.append(.resumeManage)
        case .outOfCredits:
            appModel.activeSheet = .paywall
        case .readyLimited, .ready:
            Task { await appModel.startTraining() }
        }
    }
}
```

- [ ] **Step 3: Create resume views and focus picker**

Create `AI_Behavioral_Interview_Coach/Features/Resume/ResumeViews.swift` with:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct ResumeUploadView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isImporterPresented = false

    var body: some View {
        CoachScreen(background: CoachColor.canvas) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Upload resume")
                    .font(.coachCardTitle)
                Text("Upload your resume")
                    .font(.coachTitle)
                Text("PDF or DOCX, up to 5 MB")
                    .font(.coachBody)
                    .foregroundStyle(CoachColor.text80)

                Button {
                    isImporterPresented = true
                } label: {
                    VStack(spacing: 14) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 34))
                        Text("Choose a resume file")
                            .font(.coachCardTitle)
                        Text("English resumes work best in this version.")
                            .font(.coachCaption)
                            .foregroundStyle(CoachColor.text48)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .background(CoachColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard))
                    .overlay(RoundedRectangle(cornerRadius: CoachRadius.standard).stroke(CoachColor.line))
                }
                .buttonStyle(.plain)

                CoachPrimaryButton(title: "Choose file") {
                    isImporterPresented = true
                }
            }
        }
        .navigationTitle("Upload resume")
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.pdf, .item]) { result in
            if case .success(let url) = result {
                Task { await appModel.uploadResume(fileName: url.lastPathComponent) }
            }
        }
    }
}

struct ResumeManageView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        CoachScreen(background: CoachColor.canvas) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Resume ready")
                    .font(.coachTitle)
                Text("Product manager with launch, roadmap, and stakeholder alignment experience.")
                    .font(.coachBody)
                    .foregroundStyle(CoachColor.text80)
                CoachRow(systemImage: "checklist", title: "3 recommended practice cues", detail: "Prioritization, influence, ambiguity", showsChevron: false)
                CoachPrimaryButton(title: "Start training") {
                    Task { await appModel.startTraining() }
                }
                CoachSecondaryButton(title: "Upload better resume") {
                    appModel.navigationPath.append(.resumeUpload)
                }
                CoachSecondaryButton(title: "Delete resume") {
                    appModel.activeSheet = .deleteConfirmation(.resumeOnly)
                }
            }
        }
        .navigationTitle("Resume")
    }
}

struct FocusPickerSheet: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(CoachColor.line)
                .frame(width: 48, height: 4)
                .frame(maxWidth: .infinity)
            Text("Choose a practice focus")
                .font(.coachTitle)
            Text("Pick one signal to guide the question, or start without a focus.")
                .font(.coachBody)
                .foregroundStyle(CoachColor.text80)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(TrainingFocus.allCases) { focus in
                    Button {
                        appModel.selectedFocus = focus
                    } label: {
                        Text(focus.displayName)
                            .font(.coachCaption)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .foregroundStyle(appModel.selectedFocus == focus ? CoachColor.blue : CoachColor.text80)
                            .overlay(RoundedRectangle(cornerRadius: CoachRadius.small).stroke(appModel.selectedFocus == focus ? CoachColor.blue : CoachColor.line))
                    }
                }
            }
            CoachPrimaryButton(title: "Start training") {
                appModel.activeSheet = nil
                Task { await appModel.startTraining() }
            }
            CoachSecondaryButton(title: "Start without a focus") {
                appModel.activeSheet = nil
                Task { await appModel.startTraining() }
            }
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}
```

- [ ] **Step 4: Build Home and Resume flow**

Run:

```bash
xcodegen generate
xcodebuild build -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Expected: build fails only for training, history, billing, and settings views not created yet.

- [ ] **Step 5: Commit Home and Resume**

Run:

```bash
git add AI_Behavioral_Interview_Coach/Features/Launch AI_Behavioral_Interview_Coach/Features/Home AI_Behavioral_Interview_Coach/Features/Resume
git commit -m "feat: add launch home and resume flows"
```

Expected: commit succeeds.

---

## Task 7: Real Audio Recorder

**Files:**
- Create: `AI_Behavioral_Interview_Coach/Audio/AudioRecorder.swift`

- [ ] **Step 1: Create audio recorder**

Create `AI_Behavioral_Interview_Coach/Audio/AudioRecorder.swift` with:

```swift
import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AudioRecorder {
    enum PermissionState: Equatable {
        case unknown
        case granted
        case denied
    }

    enum RecordingState: Equatable {
        case idle
        case recording
        case recorded(URL)
        case playing
    }

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private let minimumDuration: TimeInterval = 2

    var permissionState: PermissionState = .unknown
    var recordingState: RecordingState = .idle
    var elapsedSeconds: TimeInterval = 0

    var canSubmit: Bool {
        if case .recorded = recordingState {
            return elapsedSeconds >= minimumDuration
        }
        return false
    }

    func requestPermission() async {
        if #available(iOS 17.0, *) {
            let granted = await AVAudioApplication.requestRecordPermission()
            permissionState = granted ? .granted : .denied
        } else {
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            permissionState = granted ? .granted : .denied
        }
    }

    func startRecording() {
        guard permissionState == .granted else { return }
        stopPlayback()
        elapsedSeconds = 0
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("practice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            recordingState = .recording
            startTimer()
        } catch {
            recordingState = .idle
        }
    }

    func stopRecording() {
        guard recordingState == .recording else { return }
        recorder?.stop()
        let url = recorder?.url
        recorder = nil
        stopTimer()
        if let url {
            recordingState = .recorded(url)
        } else {
            recordingState = .idle
        }
    }

    func playRecording() {
        guard case .recorded(let url) = recordingState else { return }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            recordingState = .playing
        } catch {
            recordingState = .recorded(url)
        }
    }

    func stopPlayback() {
        if case .playing = recordingState {
            player?.stop()
            if let url = player?.url {
                recordingState = .recorded(url)
            } else {
                recordingState = .idle
            }
        }
        player = nil
    }

    func rerecord() {
        cleanupRecording()
        elapsedSeconds = 0
        recordingState = .idle
    }

    func cleanupRecording() {
        stopPlayback()
        if case .recorded(let url) = recordingState {
            try? FileManager.default.removeItem(at: url)
        }
        recordingState = .idle
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 0.2
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
```

- [ ] **Step 2: Build audio recorder**

Run:

```bash
xcodegen generate
xcodebuild build -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Expected: build still fails only for uncreated feature views.

- [ ] **Step 3: Commit audio recorder**

Run:

```bash
git add AI_Behavioral_Interview_Coach/Audio/AudioRecorder.swift
git commit -m "feat: add local audio recorder"
```

Expected: commit succeeds.

---

## Task 8: Training Flow Views

**Files:**
- Create: `AI_Behavioral_Interview_Coach/Features/Training/TrainingViews.swift`

- [ ] **Step 1: Create training session shell**

Create `AI_Behavioral_Interview_Coach/Features/Training/TrainingViews.swift` with:

```swift
import SwiftUI

struct TrainingSessionView: View {
    @Environment(AppModel.self) private var appModel
    let sessionID: String

    var body: some View {
        Group {
            if let session = appModel.currentSession {
                switch TrainingScreenState.route(for: session) {
                case .processing:
                    CoachLoadingView(title: processingTitle(for: session.status), subtitle: "We're using your resume to keep this round personalized.")
                case .firstAnswer:
                    RecordingPromptView(
                        title: "Question",
                        focus: session.focus,
                        eyebrow: "Based on your launch work,",
                        question: session.questionText,
                        submitTitle: "Submit answer",
                        onSubmit: { await appModel.submitFirstAnswer() }
                    )
                case .followupAnswer:
                    RecordingPromptView(
                        title: "Follow-up",
                        focus: session.focus,
                        eyebrow: "Original question",
                        question: session.followupText ?? "What specific decision did you personally make at that point?",
                        submitTitle: "Submit follow-up",
                        onSubmit: { await appModel.submitFollowupAnswer() }
                    )
                case .feedback:
                    FeedbackRedoDecisionView(session: session)
                case .redo:
                    RedoAnswerView(session: session)
                case .completed:
                    CompletedResultView(session: session)
                case .failed:
                    TrainingFailedView()
                }
            } else {
                CoachLoadingView(title: "Loading practice", subtitle: "Restoring your current round.")
            }
        }
        .navigationBarBackButtonHidden(false)
        .task {
            await appModel.loadSession(id: sessionID)
        }
    }

    private func processingTitle(for status: TrainingSessionStatus) -> String {
        switch status {
        case .questionGenerating:
            return "Preparing your personalized question"
        case .firstAnswerProcessing, .followupGenerating:
            return "Reading your answer"
        case .followupAnswerProcessing, .feedbackGenerating:
            return "Preparing focused feedback"
        case .redoProcessing, .redoEvaluating:
            return "Reviewing your redo"
        default:
            return "Preparing practice"
        }
    }
}

struct RecordingPromptView: View {
    let title: String
    let focus: TrainingFocus
    let eyebrow: String
    let question: String
    let submitTitle: String
    let onSubmit: () async -> Void

    @Environment(AppModel.self) private var appModel
    @State private var recorder = AudioRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.coachCardTitle)
                .foregroundStyle(.white)
            Text(focus.displayName)
                .font(.coachCaption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(CoachColor.darkPanel)
                .clipShape(RoundedRectangle(cornerRadius: CoachRadius.small))
            Text(eyebrow)
                .font(.coachBody)
                .foregroundStyle(CoachColor.darkMuted)
            Text(question)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            recordingPanel
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CoachColor.dark)
        .task {
            if recorder.permissionState == .unknown {
                appModel.activeSheet = .microphonePermission
            }
        }
    }

    private var recordingPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(panelTitle)
                .font(.coachCaption)
                .foregroundStyle(CoachColor.darkMuted)
            HStack(alignment: .bottom) {
                Text(timeString)
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    handleMicButton()
                } label: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(CoachColor.blue)
                        .clipShape(Circle())
                }
            }
            HStack(spacing: 8) {
                Button(primaryRecordingTitle) {
                    handlePrimaryRecordingAction()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.white)
                .foregroundStyle(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard))

                Button(secondaryRecordingTitle) {
                    handleSecondaryRecordingAction()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(CoachColor.darkPanelRaised)
                .foregroundStyle(Color(hex: 0x2997FF))
                .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard))
            }
            if case .recorded = recorder.recordingState, !recorder.canSubmit {
                Text("We couldn't hear enough audio. Record again when you're ready.")
                    .font(.coachCaption)
                    .foregroundStyle(CoachColor.darkMuted)
            }
        }
        .padding(16)
        .background(CoachColor.darkPanel)
        .clipShape(RoundedRectangle(cornerRadius: CoachRadius.standard))
    }

    private var panelTitle: String {
        switch recorder.recordingState {
        case .idle: "Start when you're ready."
        case .recording: "Recording"
        case .recorded: recorder.canSubmit ? "Ready to submit" : "Record again"
        case .playing: "Playing"
        }
    }

    private var timeString: String {
        let seconds = Int(recorder.elapsedSeconds.rounded(.down))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var primaryRecordingTitle: String {
        switch recorder.recordingState {
        case .idle: "Start recording"
        case .recording: "Stop recording"
        case .recorded: submitTitle
        case .playing: "Stop playback"
        }
    }

    private var secondaryRecordingTitle: String {
        switch recorder.recordingState {
        case .idle, .recording: "Back"
        case .recorded: "Re-record"
        case .playing: "Back"
        }
    }

    private func handleMicButton() {
        handlePrimaryRecordingAction()
    }

    private func handlePrimaryRecordingAction() {
        switch recorder.recordingState {
        case .idle:
            Task {
                if recorder.permissionState == .unknown {
                    await recorder.requestPermission()
                }
                if recorder.permissionState == .granted {
                    recorder.startRecording()
                } else {
                    appModel.activeSheet = .microphonePermission
                }
            }
        case .recording:
            recorder.stopRecording()
        case .recorded:
            guard recorder.canSubmit else { return }
            Task {
                await onSubmit()
                recorder.cleanupRecording()
            }
        case .playing:
            recorder.stopPlayback()
        }
    }

    private func handleSecondaryRecordingAction() {
        switch recorder.recordingState {
        case .recorded:
            recorder.rerecord()
        default:
            break
        }
    }
}
```

- [ ] **Step 2: Add feedback, redo, completed, and failure views to the same file**

Append to `AI_Behavioral_Interview_Coach/Features/Training/TrainingViews.swift`:

```swift
struct FeedbackRedoDecisionView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isRedoPresented = false
    let session: TrainingSession

    var body: some View {
        CoachScreen(background: CoachColor.canvas) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Feedback")
                    .font(.coachCardTitle)
                Text(session.feedback?.biggestGap ?? "Your answer needs clearer personal ownership.")
                    .font(.coachTitle)
                Divider()
                feedbackSection("Why it matters", session.feedback?.whyItMatters ?? "")
                feedbackSection("Redo priority", session.feedback?.redoPriority ?? "")
                if let outline = session.feedback?.redoOutline {
                    feedbackSection("Redo outline", outline.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
                }
                feedbackSection("Strongest signal", session.feedback?.strongestSignal ?? "")
                if let assessments = session.feedback?.assessments {
                    ForEach(assessments) { assessment in
                        HStack {
                            Text(assessment.label)
                                .font(.coachCaption)
                            Spacer()
                            Text(assessment.status.rawValue)
                                .font(.coachCaption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(assessment.status == .strong ? CoachColor.text : CoachColor.surface)
                                .foregroundStyle(assessment.status == .strong ? Color.white : CoachColor.text)
                                .clipShape(RoundedRectangle(cornerRadius: CoachRadius.small))
                        }
                    }
                }
                HStack(spacing: 12) {
                    CoachPrimaryButton(title: "Redo this answer") {
                        isRedoPresented = true
                    }
                    CoachSecondaryButton(title: "Skip redo") {
                        Task { await appModel.skipRedo() }
                    }
                }
            }
        }
        .navigationTitle("Feedback")
        .sheet(isPresented: $isRedoPresented) {
            RedoAnswerView(session: session)
        }
    }

    private func feedbackSection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.coachCaption)
                .foregroundStyle(CoachColor.text48)
            Text(text)
                .font(.coachBody)
                .foregroundStyle(CoachColor.text)
        }
    }
}

struct RedoAnswerView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    let session: TrainingSession

    var body: some View {
        RecordingPromptView(
            title: "Redo",
            focus: session.focus,
            eyebrow: "Redo priority",
            question: session.feedback?.redoPriority ?? "Focus on the decision you personally made.",
            submitTitle: "Submit redo",
            onSubmit: {
                await appModel.submitRedo()
                dismiss()
            }
        )
    }
}

struct CompletedResultView: View {
    @Environment(AppModel.self) private var appModel
    let session: TrainingSession

    var body: some View {
        CoachScreen(background: CoachColor.canvas) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Practice complete")
                    .font(.coachTitle)
                if let review = session.redoReview {
                    Text(review.headline)
                        .font(.coachCardTitle)
                    feedbackLine("Still missing", review.stillMissing)
                    feedbackLine("Next attempt", review.nextAttempt)
                } else {
                    Text("Redo review is unavailable. Your original feedback is saved.")
                        .font(.coachBody)
                }
                CoachPrimaryButton(title: "Start next") {
                    Task { await appModel.startTraining() }
                }
                CoachSecondaryButton(title: "Back home") {
                    appModel.navigationPath.removeAll()
                }
            }
        }
        .navigationTitle("Result")
    }

    private func feedbackLine(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.coachCaption)
                .foregroundStyle(CoachColor.text48)
            Text(body)
                .font(.coachBody)
        }
    }
}

struct TrainingFailedView: View {
    var body: some View {
        CoachScreen(background: CoachColor.canvas) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Practice could not continue")
                    .font(.coachTitle)
                Text("Your saved state is still available from Home.")
                    .font(.coachBody)
                    .foregroundStyle(CoachColor.text80)
            }
        }
    }
}
```

- [ ] **Step 3: Build training flow**

Run:

```bash
xcodegen generate
xcodebuild build -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Expected: build fails only for history, billing, settings, and sheet views not created yet.

- [ ] **Step 4: Commit training flow**

Run:

```bash
git add AI_Behavioral_Interview_Coach/Features/Training
git commit -m "feat: add training recording flow"
```

Expected: commit succeeds.

---

## Task 9: History, Billing, Settings, And Global Sheets

**Files:**
- Create: `AI_Behavioral_Interview_Coach/Features/History/HistoryViews.swift`
- Create: `AI_Behavioral_Interview_Coach/Features/Billing/BillingViews.swift`
- Create: `AI_Behavioral_Interview_Coach/Features/Settings/SettingsViews.swift`

- [ ] **Step 1: Create history views**

Create `AI_Behavioral_Interview_Coach/Features/History/HistoryViews.swift` with:

```swift
import SwiftUI

struct HistoryListView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        CoachScreen(background: CoachColor.canvas) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Recent practice")
                    .font(.coachTitle)
                ForEach(appModel.homeSnapshot.recentPractice) { item in
                    Button {
                        appModel.navigationPath.append(.historyDetail(sessionID: item.id))
                    } label: {
                        CoachRow(systemImage: "bubble.left", title: item.title, detail: "\(item.subtitle) · \(item.status)")
                    }
                    .buttonStyle(.plain)
                }
                CoachPrimaryButton(title: "Start training") {
                    Task { await appModel.startTraining() }
                }
            }
        }
        .navigationTitle("History")
        .task {
            await appModel.refreshHome()
        }
    }
}

struct HistoryDetailView: View {
    @Environment(AppModel.self) private var appModel
    let sessionID: String

    var body: some View {
        CoachScreen(background: CoachColor.canvas) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Prioritization decision")
                    .font(.coachTitle)
                Text("Question")
                    .font(.coachCaption)
                    .foregroundStyle(CoachColor.text48)
                Text(appModel.currentSession?.questionText ?? "Tell me about a difficult prioritization decision with multiple stakeholders.")
                    .font(.coachBody)
                Text("Feedback")
                    .font(.coachCaption)
                    .foregroundStyle(CoachColor.text48)
                Text(appModel.currentSession?.feedback?.biggestGap ?? "Biggest gap: personal ownership was not explicit enough.")
                    .font(.coachBody)
                Text("Redo review")
                    .font(.coachCaption)
                    .foregroundStyle(CoachColor.text48)
                Text(appModel.currentSession?.redoReview?.headline ?? "Partially improved. Still missing one concrete metric.")
                    .font(.coachBody)
                CoachSecondaryButton(title: "Delete practice round") {
                    appModel.activeSheet = .deleteConfirmation(.practiceRound)
                }
            }
        }
        .navigationTitle("Practice detail")
        .task {
            await appModel.loadSession(id: sessionID)
        }
    }
}
```

- [ ] **Step 2: Create billing and global utility sheets**

Create `AI_Behavioral_Interview_Coach/Features/Billing/BillingViews.swift` with:

```swift
import SwiftUI

struct PaywallSheet: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(CoachColor.line)
                .frame(width: 48, height: 4)
                .frame(maxWidth: .infinity)
            Text("Continue personalized practice")
                .font(.coachTitle)
            Text("You have no practice credits.")
                .font(.coachBody)
                .foregroundStyle(CoachColor.text80)
            CoachRow(systemImage: "bolt", title: "Sprint Pack", detail: "5 personalized practice rounds", showsChevron: false)
            CoachPrimaryButton(title: "Buy Sprint Pack") {
                Task { await appModel.buySprintPack() }
            }
            CoachSecondaryButton(title: "Restore purchase") {
                Task { await appModel.buySprintPack() }
            }
            Text("Purchases are verified before credits appear.")
                .font(.coachCaption)
                .foregroundStyle(CoachColor.text48)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}

struct APIErrorSheet: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(CoachColor.line)
                .frame(width: 48, height: 4)
            Text("Something went wrong")
                .font(.coachTitle)
            Text(message)
                .font(.coachBody)
                .foregroundStyle(CoachColor.text80)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .presentationDetents([.height(260)])
    }
}

struct MicrophonePermissionSheet: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(CoachColor.line)
                .frame(width: 48, height: 4)
            Image(systemName: "mic")
                .font(.system(size: 28))
            Text("Allow microphone access")
                .font(.coachTitle)
            Text("Answer out loud for this version. Text input is not the main path.")
                .font(.coachBody)
                .foregroundStyle(CoachColor.text80)
                .multilineTextAlignment(.center)
            CoachPrimaryButton(title: "Continue") {
                appModel.activeSheet = nil
            }
        }
        .padding(24)
        .presentationDetents([.height(330)])
    }
}

struct DeleteConfirmationSheet: View {
    @Environment(AppModel.self) private var appModel
    let intent: DeleteIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(CoachColor.line)
                .frame(width: 48, height: 4)
                .frame(maxWidth: .infinity)
            Text(title)
                .font(.coachTitle)
            Text(bodyText)
                .font(.coachBody)
                .foregroundStyle(CoachColor.text80)
            CoachPrimaryButton(title: primaryTitle) {
                Task {
                    if intent == .allData {
                        await appModel.deleteAllData()
                    }
                    appModel.activeSheet = nil
                }
            }
            CoachSecondaryButton(title: "Cancel") {
                appModel.activeSheet = nil
            }
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    private var title: String {
        switch intent {
        case .resumeOnly, .resumeAndTraining: "Delete resume"
        case .practiceRound: "Delete practice round"
        case .allData: "Delete all app data"
        }
    }

    private var bodyText: String {
        switch intent {
        case .resumeOnly: "Your original resume will be removed. Redacted history summaries can remain."
        case .resumeAndTraining: "Your resume and linked practice rounds will be removed."
        case .practiceRound: "This practice detail will be removed from history."
        case .allData: "Resume, practice rounds, transcripts, feedback, and local state will be reset."
        }
    }

    private var primaryTitle: String {
        switch intent {
        case .resumeOnly: "Delete resume only"
        case .resumeAndTraining: "Delete resume and linked training"
        case .practiceRound: "Delete practice round"
        case .allData: "Delete all data"
        }
    }
}
```

- [ ] **Step 3: Create settings and privacy views**

Create `AI_Behavioral_Interview_Coach/Features/Settings/SettingsViews.swift` with:

```swift
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        CoachScreen(background: CoachColor.canvas) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Data & privacy")
                    .font(.coachTitle)
                Text("Practice data")
                    .font(.coachCaption)
                    .foregroundStyle(CoachColor.text48)
                Button {
                    appModel.navigationPath.append(.resumeManage)
                } label: {
                    CoachRow(systemImage: "doc.text", title: "Manage resume", detail: appModel.homeSnapshot.activeResume?.fileName ?? "No active resume")
                }
                .buttonStyle(.plain)
                Button {
                    appModel.activeSheet = .paywall
                } label: {
                    CoachRow(systemImage: "arrow.clockwise", title: "Restore purchase", detail: "Refresh Sprint Pack credits")
                }
                .buttonStyle(.plain)
                Text("Privacy and deletion")
                    .font(.coachCaption)
                    .foregroundStyle(CoachColor.text48)
                Button {
                    appModel.navigationPath.append(.privacyNotice)
                } label: {
                    CoachRow(systemImage: "shield", title: "Privacy notice", detail: "How v1 uses training data")
                }
                .buttonStyle(.plain)
                Button {
                    appModel.activeSheet = .deleteConfirmation(.allData)
                } label: {
                    CoachRow(systemImage: "trash", title: "Delete all app data", detail: "Resume, audio, transcripts, feedback, history")
                }
                .buttonStyle(.plain)
                Text("App version\n1.0.0 validation build")
                    .font(.coachCaption)
                    .foregroundStyle(CoachColor.text48)
                    .padding(.top, 30)
            }
        }
        .navigationTitle("Settings")
    }
}

struct PrivacyNoticeView: View {
    var body: some View {
        CoachScreen(background: CoachColor.canvas) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Privacy notice")
                    .font(.coachTitle)
                privacyBlock("What we use", "Resume file, practice audio, transcripts, AI feedback, and purchase entitlement.")
                privacyBlock("Why we use it", "To create resume-based practice and manage credits.")
                privacyBlock("What we do not do in v1", "No public profile, no resume rewriting product, and no required account signup before practice.")
                privacyBlock("Your controls", "Delete resume, delete a practice round, or delete all app data.")
            }
        }
        .navigationTitle("Privacy")
    }

    private func privacyBlock(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.coachCaption)
                .foregroundStyle(CoachColor.text48)
            Text(body)
                .font(.coachBody)
                .foregroundStyle(CoachColor.text)
            Divider()
        }
    }
}
```

- [ ] **Step 4: Build all views**

Run:

```bash
xcodegen generate
xcodebuild build -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Expected: build succeeds.

- [ ] **Step 5: Run full unit test suite**

Run:

```bash
xcodebuild test -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Expected: all tests pass.

- [ ] **Step 6: Commit remaining UI**

Run:

```bash
git add AI_Behavioral_Interview_Coach/Features
git commit -m "feat: add history billing settings and sheets"
```

Expected: commit succeeds.

---

## Task 10: Manual Run, Visual Pass, And Final Fixes

**Files:**
- Modify files from earlier tasks only when manual verification identifies a concrete mismatch.

- [ ] **Step 1: Build for simulator**

Run:

```bash
xcodebuild build -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Expected: build succeeds.

- [ ] **Step 2: Launch simulator and app from Xcode**

Open:

```bash
open AI_Behavioral_Interview_Coach.xcodeproj
```

Select an iPhone simulator, run the app, and complete:

```text
Launch -> Upload resume -> Start training -> Record first answer -> Submit -> Record follow-up -> Submit -> Feedback -> Redo -> Complete -> History
```

Expected: flow completes without a crash.

- [ ] **Step 3: Verify skip-redo flow**

Reset app data from Settings, repeat:

```text
Launch -> Upload resume -> Start training -> Record first answer -> Submit -> Record follow-up -> Submit -> Feedback -> Skip redo -> Complete -> History
```

Expected: completed session appears in History with redo skipped.

- [ ] **Step 4: Verify out-of-credits and mock purchase**

Complete two practice rounds, then start a third.

Expected:

```text
Home -> You're out of practice credits -> Buy Sprint Pack -> credits increase -> Start training works
```

- [ ] **Step 5: Verify microphone permission paths**

On simulator, reset microphone permission:

```bash
xcrun simctl privacy booted reset microphone com.wxm.AIBehavioralInterviewCoach
```

Run the recording screen.

Expected: microphone explanation sheet appears before recording, and the system permission path is reachable.

- [ ] **Step 6: Visual compare against Pencil design**

Compare app screens against:

```text
docs/design/ios_hifi_pencil_original/AI_Behavioral_Interview_Coach_iOS_HiFi_v1.pen
docs/design/ios_hifi_pencil_original/exports/named_png/01_home_no_resume.png
docs/design/ios_hifi_pencil_original/exports/named_png/02_home_ready.png
docs/design/ios_hifi_pencil_original/exports/named_png/11_first_answer_idle.png
docs/design/ios_hifi_pencil_original/exports/named_png/15_feedback_redo_decision.png
docs/design/ios_hifi_pencil_original/exports/named_png/17_completed_redo_review.png
docs/design/ios_hifi_pencil_original/exports/named_png/21_paywall_sheet.png
docs/design/ios_hifi_pencil_original/exports/named_png/22_settings_data.png
```

Expected:

```text
Background rhythm matches.
Primary CTA placement matches.
Training screens use dark immersive layout.
Feedback screen puts biggest gap and redo priority first.
Sheets use bottom presentation and clear action hierarchy.
No bottom tab bar exists.
```

- [ ] **Step 7: Apply concrete visual fixes**

If the visual pass finds mismatches, change only the files responsible for the mismatched screen or shared token. Run:

```bash
xcodebuild build -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Expected: build succeeds after each fix.

- [ ] **Step 8: Run final tests**

Run:

```bash
xcodebuild test -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Expected: all tests pass.

- [ ] **Step 9: Commit final pass**

Run:

```bash
git add AI_Behavioral_Interview_Coach AI_Behavioral_Interview_CoachTests Project.yml .gitignore
git commit -m "test: verify iOS MVP flow"
```

Expected: commit succeeds if final verification changed files. If no files changed, record the final test output in the implementation handoff instead of creating an empty commit.

---

## Coverage Map

- New iPhone-only SwiftUI project: Task 1.
- UI source from `.pen` and renderer tokens: Tasks 5 and 10.
- Home primary state priority: Tasks 2 and 6.
- App-owned navigation and sheets: Tasks 4, 6, 9.
- In-app `MockCoachService`: Task 3.
- Real microphone recording: Task 7 and Task 8.
- Full practice flow: Tasks 6, 8, 9, 10.
- Feedback and redo loop: Tasks 3, 8, 10.
- History: Task 9.
- Mock paywall and credits: Tasks 3, 9, 10.
- Settings, privacy, deletion entry points: Task 9.
- Tests and simulator verification: Tasks 2, 3, 4, 9, 10.
