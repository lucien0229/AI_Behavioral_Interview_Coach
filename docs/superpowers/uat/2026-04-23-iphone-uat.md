# 2026-04-23 iPhone UAT

## Scope

- Device target: iPhone only (`TARGETED_DEVICE_FAMILY = 1`)
- Design source of truth: `docs/design/ios_hifi_pencil_original/AI_Behavioral_Interview_Coach_iOS_HiFi_v1.pen`
- Visual reference used in this pass: `docs/design/ios_hifi_pencil_original/exports/named_png/01_home_no_resume.png`

## Changes verified in this pass

- Fixed home header truncation for `Interview Coach`
- Added `UIRequiresFullScreen = YES` for the iPhone-only target
- Added `UILaunchStoryboardName = LaunchScreen` so the app runs in full-screen iPhone geometry
- Tightened root screen sizing so launch/home containers request full-window layout
- Added XCUITest foreground coverage for Home, Privacy Notice, and Resume Upload entry screens
- Added XCUITest foreground coverage for microphone allow/deny states
- Added XCUITest foreground coverage for first-answer recording reaching the ready-to-submit state
- Added XCUITest foreground coverage for first-answer submission, follow-up answering, and feedback display

## Automated checks

- `git diff --check` passed
- `xcrun swiftc -typecheck $(rg --files AI_Behavioral_Interview_Coach -g'*.swift')` passed
- `xcodebuild -quiet test -scheme AI_Behavioral_Interview_Coach -destination 'id=F592A705-BDE3-495D-9F13-1134BC4F31DD' -resultBundlePath /tmp/aibic-iphone-ui.xcresult` passed
- Result bundle summary: 43 tests passed, 0 failed, 0 skipped
- UI screenshot attachments exported to `/tmp/aibic-iphone-ui-attachments`

## Simulator validation

- Simulator: `AIBIC iPhone 17` (`F592A705-BDE3-495D-9F13-1134BC4F31DD`)
- Install and launch succeeded after rebuild
- Home header text now renders as `Interview Coach` without truncation
- Foreground UI automation successfully navigates Home -> Privacy Notice and Home -> Resume Upload
- Full-screen screenshot output now matches iPhone geometry instead of the previous card-like capture
- Microphone allow path verifies the system permission prompt, the first-answer recording controls, and the ready-to-submit state
- Microphone deny path verifies the system permission prompt and the in-app microphone guidance sheet
- Follow-up path verifies first-answer submit -> follow-up screen -> follow-up answer submit -> feedback screen
- Recording UI tests use `AIBIC_UI_TEST_FAKE_AUDIO=1` after the real permission decision so simulator host audio hardware does not make the suite flaky

## Resolved issue

The previous `simctl io ... screenshot` and UI screenshot output showed the app in a card-like frame with black surrounding space. Adding a system LaunchScreen storyboard and wiring it through `UILaunchStoryboardName` resolved the non-full-screen capture. The app now launches and tests in full iPhone screen geometry.

Current local capture artifact:

- Home: `/tmp/aibic-iphone-ui-attachments/ED26AD09-3313-4C06-877E-574679E5200D.png`
- Privacy Notice: `/tmp/aibic-iphone-ui-attachments/B5FE9CD9-9D17-4F06-B630-D7FAD8D45B63.png`
- Resume Upload: `/tmp/aibic-iphone-ui-attachments/3992612E-7C38-4786-8405-6F55494AA15D.png`
- First Answer Recorded: `/tmp/aibic-iphone-ui-attachments/23A0096E-0297-494A-A586-C7459751D99A.png`
- Follow-up Ready: `/tmp/aibic-iphone-ui-attachments/349EBEA1-EAA4-43E3-A4D8-AE1EE0638C8A.png`
- Feedback Ready: `/tmp/aibic-iphone-ui-attachments/F972CFBA-500B-41EC-A679-4A82D92E22AA.png`
- Microphone Permission Sheet: `/tmp/aibic-iphone-ui-attachments/B04FB10B-1FA3-4C01-949E-60B2723F0DD0.png`

## Recommended next action

Extend foreground UI automation through redo and completion: tap `Redo this answer`, submit the redo recording, verify completed result, then verify the practice appears in history. This is now the highest-risk remaining end-to-end training path.
