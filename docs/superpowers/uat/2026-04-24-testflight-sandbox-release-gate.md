# TestFlight Sandbox Release Gate (iPhone)

Date: 2026-04-24
Branch: `codex/release-readiness-audit`
Scope: QA-E2E and billing gate record for iPhone TestFlight sandbox release sign-off.

## 1. Gate status

Current status: **Pending execution**.

This record must be completed on a signed TestFlight build connected to staging API, StoreKit sandbox, object storage, AI provider sandbox, and analytics collection. Simulator evidence is useful regression coverage but does not satisfy this release gate.

Release sign-off requires **5 consecutive passing TestFlight sandbox runs**. If any run fails, the counter resets after the defect is fixed.

## 2. Preconditions

1. TestFlight build installed on an iPhone target device.
2. App points to staging API and sandbox services.
3. StoreKit sandbox tester account is available.
4. Fresh anonymous app state for run 1.
5. Synthetic or fully redacted English resume test data is available.
6. Backend logs, analytics sink, and StoreKit sandbox transaction history are accessible to QA.

## 3. Required evidence per run

Record these fields for each run:

1. Build number and device model.
2. Run start/end time.
3. App user ID.
4. Resume ID.
5. Training session ID.
6. Key backend request IDs.
7. Analytics event IDs for the required funnel events.
8. StoreKit sandbox transaction IDs for purchase/restore checks.
9. Screenshots or screen recording links for key checkpoints.
10. Pass/fail result and defect link if failed.

## 4. Run checklist

Each of the 5 runs must cover:

1. Bootstrap creates or restores anonymous user.
2. Home renders the correct primary state.
3. Resume upload reaches `ready` with `profile_quality_status = usable`.
4. Training session creation reserves one credit.
5. Question is visible.
6. First answer recording submits successfully.
7. Follow-up question is visible.
8. Follow-up answer recording submits successfully.
9. Feedback is visible and records `feedback_viewed`.
10. Redo recording submits successfully.
11. Redo review is visible and records `redo_review_viewed`.
12. Session completes with `completion_reason = redo_review_generated`.
13. Home no longer shows an active session.
14. Purchase verify succeeds once through StoreKit sandbox.
15. Restore purchase succeeds or returns the documented empty restore state.
16. Analytics payloads contain no forbidden resume, transcript, feedback, source snippet, Apple signed transaction, or app account token fields.

## 5. Consecutive pass record

| Run | Build | Device | App user ID | Session ID | Purchase/restore ref | Result | Evidence |
|---:|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  | Pending |  |
| 2 |  |  |  |  |  | Pending |  |
| 3 |  |  |  |  |  | Pending |  |
| 4 |  |  |  |  |  | Pending |  |
| 5 |  |  |  |  |  | Pending |  |

## 6. Sign-off criteria

Mark this gate passed only when:

1. All 5 rows above are marked `Pass`.
2. Runs are consecutive on the same release candidate or documented successor build.
3. No P0/P1 defect remains open.
4. Backend, analytics, and StoreKit evidence are attached for every run.
5. The release readiness audit is updated from pending TestFlight evidence to ready for sign-off.
