# 2026-04-23 iPhone UAT

## Scope

- Device target: iPhone only (`TARGETED_DEVICE_FAMILY = 1`)
- Design source of truth: `docs/design/ios_hifi_pencil_original/AI_Behavioral_Interview_Coach_iOS_HiFi_v1.pen`
- Visual references used in this pass: `docs/design/ios_hifi_pencil_original/exports/named_png/01_home_no_resume.png`, `11_first_answer_idle.png`, `12_first_answer_review.png`, `14_followup_answer.png`, `15_feedback_redo_decision.png`, `17_completed_redo_review.png`

## Changes verified in this pass

- Fixed home header truncation for `Interview Coach`
- Added `UIRequiresFullScreen = YES` for the iPhone-only target
- Added `UILaunchStoryboardName = LaunchScreen` so the app runs in full-screen iPhone geometry
- Tightened root screen sizing so launch/home containers request full-window layout
- Added XCUITest foreground coverage for Home, Privacy Notice, and Resume Upload entry screens
- Added XCUITest foreground coverage for microphone allow/deny states
- Added XCUITest foreground coverage for first-answer recording reaching the ready-to-submit state
- Added XCUITest foreground coverage for first-answer submission, follow-up answering, and feedback display
- Added XCUITest foreground coverage for redo submission, completed result, and home history summary
- Restored the recorded-answer and follow-up answer cards to the `.pen` horizontal primary/secondary action row
- Aligned the completed result screen to the `.pen` summary-first hierarchy, with redo review, still-missing guidance, next attempt, history notice, and first-viewport CTAs
- Removed the duplicated system navigation back layer from routed pages while keeping the custom `.pen` back row
- Added XCUITest assertions that Settings, Privacy Notice, and Resume Upload expose exactly one `Back` button

## Automated checks

- `git diff --check` passed
- `xcrun swiftc -typecheck $(rg --files AI_Behavioral_Interview_Coach -g'*.swift')` passed
- `xcodebuild -quiet test -scheme AI_Behavioral_Interview_Coach -destination 'id=F592A705-BDE3-495D-9F13-1134BC4F31DD' -resultBundlePath /tmp/aibic-iphone-ui.xcresult` passed
- Final cleanup re-run: `xcodebuild -quiet test -scheme AI_Behavioral_Interview_Coach -destination 'id=F592A705-BDE3-495D-9F13-1134BC4F31DD'` passed
- Route back-layer regression check: `xcodebuild -quiet test -scheme AI_Behavioral_Interview_Coach -destination 'id=F592A705-BDE3-495D-9F13-1134BC4F31DD' -only-testing:AI_Behavioral_Interview_CoachUITests/HomeVisualSmokeTests/testHomePrivacyAndResumeEntryRenderOnIPhone -resultBundlePath /tmp/aibic-back-nav.xcresult` passed
- Full route cleanup re-run: `xcodebuild -quiet test -scheme AI_Behavioral_Interview_Coach -destination 'id=F592A705-BDE3-495D-9F13-1134BC4F31DD'` passed
- Result bundle summary: 44 tests passed, 0 failed, 0 skipped
- UI screenshot attachments exported to `/tmp/aibic-iphone-ui-attachments`

## Simulator validation

- Simulator: `AIBIC iPhone 17` (`F592A705-BDE3-495D-9F13-1134BC4F31DD`)
- Install and launch succeeded after rebuild
- Home header text now renders as `Interview Coach` without truncation
- Foreground UI automation successfully navigates Home -> Privacy Notice and Home -> Resume Upload
- Foreground UI automation successfully navigates Home -> Settings and confirms the custom back row is the only exposed back control
- Full-screen screenshot output now matches iPhone geometry instead of the previous card-like capture
- Microphone allow path verifies the system permission prompt, the first-answer recording controls, and the ready-to-submit state
- Microphone deny path verifies the system permission prompt and the in-app microphone guidance sheet
- Follow-up path verifies first-answer submit -> follow-up screen -> follow-up answer submit -> feedback screen
- Redo path verifies feedback -> redo answer -> completed result -> home history summary
- Recording UI tests use `AIBIC_UI_TEST_FAKE_AUDIO=1` after the real permission decision so simulator host audio hardware does not make the suite flaky

## Resolved issue

The previous `simctl io ... screenshot` and UI screenshot output showed the app in a card-like frame with black surrounding space. Adding a system LaunchScreen storyboard and wiring it through `UILaunchStoryboardName` resolved the non-full-screen capture. The app now launches and tests in full iPhone screen geometry.

Current local capture artifact:

- Home: `/tmp/aibic-iphone-ui-attachments/F7249716-E033-4DCE-970D-100F3664D60A.png`
- Settings: `/tmp/aibic-back-nav-attachments/BAAE3CF1-4FA6-4AEC-9B5F-F6E8EC4DB7A8.png`
- Privacy Notice: `/tmp/aibic-iphone-ui-attachments/EA99F584-BB13-4B1D-9BDA-3BBB3A8B2AAD.png`
- Resume Upload: `/tmp/aibic-iphone-ui-attachments/E68A0B06-91DC-4F83-A3BA-118E7E442203.png`
- First Answer Recorded: `/tmp/aibic-iphone-ui-attachments/A2291D43-4C8C-4DD3-B0AD-B8D5AA962CB6.png`
- Follow-up Ready: `/tmp/aibic-iphone-ui-attachments/C5516149-8C72-4A5E-8734-0BBF8552EECA.png`
- Feedback Ready: `/tmp/aibic-iphone-ui-attachments/897F83E6-44B7-4427-917B-04B6054883F0.png`
- Result Complete: `/tmp/aibic-iphone-ui-attachments/D58B553A-6327-4695-89FB-30288D2EEDE9.png`
- Home History After Redo: `/tmp/aibic-iphone-ui-attachments/E2C4A44E-4C28-4759-9EA2-7CD78E89D192.png`
- Microphone Permission Sheet: `/tmp/aibic-iphone-ui-attachments/1D64524A-3176-4337-A5DB-844B65AE6EB9.png`

## Final visual audit

- Opened `.pen` source of truth in Pencil MCP and compared the iPhone training-path screenshots against the high-fidelity screen structure.
- Fixed the clear structural mismatch where recording cards stacked `Submit answer`/`Re-record` and `Start recording`/`Back` vertically instead of using the `.pen` horizontal action row.
- Fixed the completed result page so it no longer pushes the result CTA below a full original-feedback dump; the first viewport now follows the `.pen` hierarchy: redo status, headline, still-missing guidance, next-attempt guidance, history notice, `Start next`, and `Back home`.
- Accepted seeded copy/focus differences between the automated test flow and exported PNG examples because the native UI structure, visual hierarchy, and interaction states now match the `.pen` intent.

## Recommended next action

Prepare the branch for review. The critical iPhone training path now has foreground automation from resume-ready home through completed history, and the final visual audit against the `.pen` source of truth is complete.
