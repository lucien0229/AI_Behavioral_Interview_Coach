# AI Behavioral Interview Coach iOS MVP Design

Date: 2026-04-22

## Purpose

Build the first runnable iPhone MVP for AI Behavioral Interview Coach from the existing product documents and Pencil high-fidelity design.

The MVP validates the core product loop: a user uploads a resume, starts one resume-grounded behavioral interview round, answers by voice, receives structured feedback, completes or skips redo, and can view the completed practice in history.

## Source Documents

- `docs/ios/AI_Behavioral_Interview_Coach_PRD_v1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_Data_API_Spec_v1.1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_Prompt_Content_Spec_v1.1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_Client_UX_State_Error_Handling_Spec_v1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_iOS_Client_Screen_Spec_v1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_QA_Acceptance_Test_Plan_v1.md`
- `docs/design/AI_Behavioral_Interview_Coach_iOS_UI_Design_Spec_v1.md`
- `docs/design/ios_hifi_pencil_original/AI_Behavioral_Interview_Coach_iOS_HiFi_v1.pen`
- `docs/design/ios_hifi_pencil_original/ai_bic_original_renderer.js`

## Confirmed Scope

The implementation target is a new iPhone-only SwiftUI iOS app created in the current project directory.

The app will use real local microphone permission and recording behavior. Recorded audio is used to validate the oral-answer experience, but submitted audio is handled by the in-app mock service rather than real ASR or AI.

The app will use an in-process `MockCoachService` as the service implementation. No separate backend, database, object storage, real AI provider, or real StoreKit integration is included in this MVP.

The app is iPhone-only. iPad-specific layouts are out of scope.

## UI Source Of Truth

The UI source of truth is the Pencil source file:

`docs/design/ios_hifi_pencil_original/AI_Behavioral_Interview_Coach_iOS_HiFi_v1.pen`

The SwiftUI implementation should use the `.pen` file and `ai_bic_original_renderer.js` as the authoritative reference for screen structure, color values, typography, spacing, corner radius, and visual hierarchy.

PNG and PDF exports are review aids only. If the `.pen` file and Markdown UI spec disagree visually, the `.pen` file wins. Product behavior, state transitions, and data rules still follow the PRD, Data/API, Client UX, Prompt, and QA specs.

The MVP should not render exported PNGs directly in the app. It should recreate the design with native SwiftUI components.

## Recommended Architecture

Use one SwiftUI app target with no third-party dependencies for the MVP.

Core modules:

- `AppShell`: launch gate, bootstrap, and root navigation.
- `AppModel`: root-owned observable state for bootstrap, home refresh, active session routing, global sheets, and global errors.
- `CoachService`: protocol defining business operations for bootstrap, home, resume, training, history, billing, and deletion.
- `MockCoachService`: in-memory implementation of `CoachService`.
- `AudioRecorder`: local recording, microphone permission, start, stop, playback, rerecord, and temporary audio file handling.
- `HomeFeature`: Home states and primary action derivation.
- `ResumeFeature`: resume upload, parsing, ready, limited, unusable, and deletion states.
- `TrainingFeature`: question, first answer, follow-up answer, feedback, redo, and completion screens.
- `HistoryFeature`: recent practice list and detail.
- `BillingFeature`: mock paywall, mock purchase, and restore.
- `SettingsFeature`: data and privacy actions.
- `SharedUI`: reusable buttons, rows, panels, sheets, loading surfaces, error surfaces, and recording controls.

UI views should not contain mock business logic. They call `CoachService` through feature models or the root app model.

## Navigation

Use a Home-first navigation structure:

- Launch / Bootstrap gate
- Home as the single business root
- Resume Upload and Resume Manage pushed from Home
- Training Session pushed from Home or active session continuation
- History List and History Detail pushed from Home
- Settings and Privacy Notice pushed from Home or Settings
- Focus Picker, Paywall, Delete Confirmation, API Error, and Microphone Permission as sheets or dialogs

Do not use a bottom tab bar. History, Settings, and Billing are secondary flows.

## Home Primary State

Home must derive exactly one primary state before rendering.

Priority:

1. Active session exists: show `Continue session`.
2. No active resume: show `Upload resume`.
3. Resume uploaded or parsing: show `View status`.
4. Resume failed: show `Upload another resume`.
5. Resume unusable: show `Upload another resume`.
6. Resume ready and no available credits: show `Buy Sprint Pack`.
7. Resume ready but limited: show `Start training` with a limited-resume warning.
8. Resume ready and usable: show `Start training`.

Recent practice and history remain supplemental. They must not override the primary state.

## Main User Flow

1. App launches and calls mock bootstrap.
2. Home shows the current aggregate state.
3. User uploads a PDF or DOCX resume.
4. Mock service simulates upload and parsing.
5. Home moves to resume-ready state.
6. User starts training and may choose a training focus.
7. Mock service creates a session and generates one personalized question.
8. User records the first answer with real local audio recording.
9. User can play back, rerecord, or submit.
10. Mock service simulates first-answer processing and generates one follow-up.
11. User records and submits the follow-up answer.
12. Mock service generates structured feedback and consumes one practice credit.
13. User can redo or skip redo.
14. Redo path records one more answer and mock service generates a lightweight redo review.
15. Skip path completes the session without redo.
16. Completed session appears in recent practice and history.

## Training State Machine

`MockCoachService` should simulate the server-owned training state machine:

```text
question_generating
-> waiting_first_answer
-> first_answer_processing
-> followup_generating
-> waiting_followup_answer
-> followup_answer_processing
-> feedback_generating
-> redo_available
-> redo_processing
-> redo_evaluating
-> completed
```

The skip-redo path goes from `redo_available` to `completed`.

Short delays may be used to make processing states visible. The UI must render from service state rather than locally assuming the next screen.

## Mock Data

The mock service maintains in-memory state for:

- Anonymous user identity: `app_user_id`, `access_token`, and `app_account_token`.
- Resume state: none, uploading, parsing, ready usable, ready limited, unusable, and failed.
- Usage balance: 2 initial free credits; one credit consumed when feedback is generated.
- Active session: at most one non-terminal session at a time.
- History: completed sessions become recent practice entries.
- Billing: mock Sprint Pack purchase and restore add credits.
- Deletion: active resume, single practice round, and all app data deletion.

Mock question, follow-up, feedback, redo guidance, redo review, and history detail content must be in English and should read like PM or Program Manager behavioral interview material. It should be resume-grounded in tone, not generic interview advice.

## Recording Behavior

The MVP uses real local recording.

Requirements:

- Show the microphone permission explanation before requesting permission.
- Request system microphone permission.
- Support start, stop, playback, rerecord, and submit.
- Block submission when the recording is shorter than the configured minimum duration.
- Show an actionable microphone-denied state.
- Treat submitted audio as temporary MVP data.
- Do not persist full audio long term.

The mock service does not transcribe the audio. It uses successful submission as the signal to advance the state machine.

## Error And Edge States

The MVP includes these edge states:

- Unsupported resume file type.
- Resume file larger than 5 MB.
- Resume parsing state.
- Resume unusable state.
- Microphone permission denied.
- Recording too short.
- Mock API error with retry.
- Active session continuation.
- Out of credits and mock paywall.
- Delete resume.
- Delete practice round.
- Delete all data.

The MVP does not include complex production retry policies, real offline persistence, real token expiry, or real payment verification.

## Billing

Paywall uses mock behavior only.

When credits reach zero, Home shows `Buy Sprint Pack`. Buying or restoring in the mock paywall increases available credits. Do not use real StoreKit in this MVP.

The UI should still match the `.pen` paywall sheet so StoreKit can replace the mock behavior later without redesigning the flow.

## Out Of Scope

This MVP does not implement:

- Real backend API.
- Real OpenAI or AI provider calls.
- Real resume text extraction.
- Real ASR transcription.
- Real Apple IAP or StoreKit sandbox.
- Account login.
- Text-answer main path.
- JD personalization.
- Multi-resume management.
- iPad layout.
- Production analytics pipeline.
- Production persistence of full feedback, transcript, or audio.

## Testing Plan

Unit tests should cover:

- `HomePrimaryState` priority derivation.
- Training status to screen routing.
- One active session limit.
- Credit consumption after feedback generation.
- Skip redo completion.
- Redo review completion.
- Resume deletion behavior.
- Practice deletion behavior.
- Delete all data reset.

Smoke or UI tests should cover:

- No resume to completed session with redo.
- No resume to completed session with skip redo.
- Active session continuation.
- Out of credits to mock purchase and next training.
- History list and history detail after completion.

Manual simulator checks should cover:

- iPhone small and standard screen sizes.
- Microphone permission allowed.
- Microphone permission denied.
- Recording file creation.
- Recording too short.
- Visual comparison against the `.pen` design and PNG exports.

## Acceptance Criteria

The MVP is complete when:

- The new SwiftUI iPhone app compiles and runs in an iPhone Simulator.
- A user can complete the full mock flow: upload resume, choose focus, record first answer, record follow-up, view feedback, redo or skip, complete the session, and view history.
- Home correctly renders no resume, resume processing, ready, active session, and out-of-credits states.
- Recording uses real local microphone permission and produces local audio during the session.
- The app uses native SwiftUI components that visually follow the `.pen` design.
- No real backend, AI, ASR, or IAP is required to use the MVP.
- Service boundaries are clear enough that a real API implementation can later replace `MockCoachService` without rewriting the UI.

## Implementation Preference

Implement the MVP with the smallest set of files that keeps responsibilities clear. Avoid speculative abstractions beyond the `CoachService` boundary, feature models, and shared UI needed by multiple screens.

Keep the app focused on the confirmed v1 validation path: resume-grounded behavioral interview practice with one question, one follow-up, structured feedback, and one redo opportunity.
