# Release Readiness Gap Audit (iPhone)

Date: 2026-04-24
Branch: `codex/release-readiness-audit`
Scope: iPhone release acceptance gap audit against QA gate and current code/test evidence.

## 1. Release gate verdict

Current verdict: **Code blockers closed; release sign-off pending TestFlight sandbox evidence**.

The original audit found three blocking gaps:

1. **B1 - Missing abandon integration**: fixed in this branch.
2. **B2 - Missing analytics implementation evidence**: fixed in this branch for the required v1 client-side event pipeline and privacy guard.
3. **B3 - Missing TestFlight sandbox gate evidence**: not executable from the local workspace. A runbook and evidence template now exist, but the gate remains open until QA records 5 consecutive TestFlight sandbox passes.

This branch should not be treated as final release sign-off until B3 has real TestFlight evidence.

## 2. Fixed blockers

### B1 - Session abandon integration

Status: **Fixed and covered by unit tests**.

Implementation evidence:

1. `CoachService` now exposes `abandonSession(sessionID:)`.
2. `RemoteCoachService` posts `POST /training-sessions/{session_id}/abandon` with an `Idempotency-Key`.
3. `MockCoachService` releases the active session only for pre-feedback states and rejects abandon after feedback is available.
4. `AppModel.abandonCurrentSession()` routes the user home, clears the local active session, refreshes Home, and tracks `training_session_abandoned`.
5. Training back-home actions call the abandon path only for pre-feedback sessions; feedback, completed, abandoned, and failed states route Home without calling abandon.

Test evidence:

1. `RemoteCoachServiceTests.testAbandonSessionPostsEndpointWithIdempotencyKey`
2. `MockCoachServiceTests.testAbandonSessionBeforeFeedbackReleasesActiveSessionAndKeepsCredit`
3. `MockCoachServiceTests.testAbandonSessionAfterFeedbackIsRejected`
4. `AppModelTests.testAbandonCurrentSessionReleasesSessionAndRoutesHome`
5. `AppModelTests.testAbandonCurrentTerminalSessionRoutesHomeWithoutCallingAbandon`

### B2 - Analytics implementation evidence

Status: **Fixed for client-side v1 release evidence and covered by unit tests**.

Implementation evidence:

1. `AnalyticsService`, `AnalyticsSink`, and `AnalyticsPipeline` define a testable client event pipeline.
2. `AnalyticsPrivacyGuard` drops events containing forbidden content fields such as resume text, transcript text, feedback text, source snippets, Apple transaction payloads, or app account tokens.
3. `AppModel` emits the minimum QA-required client events for bootstrap, Home exposure, resume upload/parse outcomes, training funnel, recording starts, answer submits, feedback/redo exposure, completion, abandon, purchase, restore, deletion, and API errors.
4. Server-backed events are only emitted after service success paths in the client model.
5. Feedback and redo review viewed events are emitted from explicit view exposure hooks, not merely from API completion.

Test evidence:

1. `AI_Behavioral_Interview_CoachTests.testAnalyticsPipelineRejectsForbiddenFields`
2. `AI_Behavioral_Interview_CoachTests.testAnalyticsPipelineAcceptsAllowedEventWithSchemaVersion`
3. `AppModelTests.testBootstrapTracksHomeViewedWithPrimaryState`
4. `AppModelTests.testTrainingFunnelTracksServerBackedCompletionInOrder`
5. `AppModelTests.testFeedbackViewedIsOnlyTrackedAfterExplicitViewExposure`
6. `AppModelTests.testPurchaseVerifiedIsNotTrackedWhenPurchaseFails`

## 3. Remaining release gate

### B3 - TestFlight sandbox evidence

Status: **Still pending external execution**.

The QA plan requires the end-to-end main path to pass in TestFlight sandbox 5 consecutive times. Local simulator and unit tests cannot satisfy this gate because it depends on a signed TestFlight build, StoreKit sandbox, real network conditions, and staging backend infrastructure.

Evidence artifact:

`docs/superpowers/uat/2026-04-24-testflight-sandbox-release-gate.md`

Release sign-off rule:

1. Keep this branch as **not release-signed** until the TestFlight record has 5 consecutive passing runs.
2. If any run fails, fix the defect, reset the consecutive-pass counter, and restart the 5-run sequence.
3. Attach backend request IDs, analytics event IDs, StoreKit sandbox transaction references, and screenshots/log snippets for each run.

## 4. Verification run

Latest local verification:

```text
xcodebuild test \
  -project AI_Behavioral_Interview_Coach.xcodeproj \
  -scheme AI_Behavioral_Interview_Coach \
  -destination 'platform=iOS Simulator,id=F592A705-BDE3-495D-9F13-1134BC4F31DD' \
  -only-testing:AI_Behavioral_Interview_CoachTests
```

Result: **passed**. 72 unit tests executed, 0 failures.

```text
xcodebuild test \
  -project AI_Behavioral_Interview_Coach.xcodeproj \
  -scheme AI_Behavioral_Interview_Coach \
  -destination 'platform=iOS Simulator,id=F592A705-BDE3-495D-9F13-1134BC4F31DD' \
  -only-testing:AI_Behavioral_Interview_CoachUITests
```

Result: **passed**. 5 UI tests executed, 0 failures.

Coverage note: this validates the code-level blockers and regression tests. It does not replace the TestFlight sandbox release gate.

## 5. Release recommendation

Recommended next action: merge the code fixes after review, then execute the TestFlight sandbox gate from the runbook before tagging a release.
