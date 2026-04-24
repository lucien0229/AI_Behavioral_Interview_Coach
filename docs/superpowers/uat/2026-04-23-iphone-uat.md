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

## Automated checks

- `git diff --check` passed
- `xcrun swiftc -typecheck $(rg --files AI_Behavioral_Interview_Coach -g'*.swift')` passed
- `xcodebuild -quiet test -scheme AI_Behavioral_Interview_Coach -destination 'id=F592A705-BDE3-495D-9F13-1134BC4F31DD' -resultBundlePath /tmp/aibic-iphone-ui.xcresult` passed
- Result bundle summary: 42 tests passed, 0 failed, 0 skipped
- UI screenshot attachments exported to `/tmp/aibic-iphone-ui-attachments`

## Simulator validation

- Simulator: `AIBIC iPhone 17` (`F592A705-BDE3-495D-9F13-1134BC4F31DD`)
- Install and launch succeeded after rebuild
- Home header text now renders as `Interview Coach` without truncation
- Foreground UI automation successfully navigates Home -> Privacy Notice and Home -> Resume Upload
- Full-screen screenshot output now matches iPhone geometry instead of the previous card-like capture
- Microphone allow path verifies the system permission prompt, the first-answer recording controls, and the ready-to-submit state
- Microphone deny path verifies the system permission prompt and the in-app microphone guidance sheet
- Recording UI tests use `AIBIC_UI_TEST_FAKE_AUDIO=1` after the real permission decision so simulator host audio hardware does not make the suite flaky

## Resolved issue

The previous `simctl io ... screenshot` and UI screenshot output showed the app in a card-like frame with black surrounding space. Adding a system LaunchScreen storyboard and wiring it through `UILaunchStoryboardName` resolved the non-full-screen capture. The app now launches and tests in full iPhone screen geometry.

Current local capture artifact:

- Home: `/tmp/aibic-iphone-ui-attachments/467FB9E9-1227-4845-B18A-E2E1A956C46E.png`
- Privacy Notice: `/tmp/aibic-iphone-ui-attachments/8F2B0AE8-7F21-49BF-86BF-031A5A65716E.png`
- Resume Upload: `/tmp/aibic-iphone-ui-attachments/2D86D8DB-84DC-4908-89C8-C8C6B67193CB.png`
- First Answer Recorded: `/tmp/aibic-iphone-ui-attachments/FF8DDBFC-E784-47DD-89EF-C72AD271396F.png`
- Microphone Permission Sheet: `/tmp/aibic-iphone-ui-attachments/2360CDB8-AE71-4A2E-9663-B035D634064F.png`

## Recommended next action

Extend foreground UI automation from first-answer submission into follow-up generation, follow-up answer submission, and feedback display. This is the next highest-risk user journey after microphone and recording coverage.
