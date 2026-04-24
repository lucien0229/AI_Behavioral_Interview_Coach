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
- Added XCUITest foreground coverage for redo submission, completed result, and home history summary

## Automated checks

- `git diff --check` passed
- `xcrun swiftc -typecheck $(rg --files AI_Behavioral_Interview_Coach -g'*.swift')` passed
- `xcodebuild -quiet test -scheme AI_Behavioral_Interview_Coach -destination 'id=F592A705-BDE3-495D-9F13-1134BC4F31DD' -resultBundlePath /tmp/aibic-iphone-ui.xcresult` passed
- Result bundle summary: 44 tests passed, 0 failed, 0 skipped
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
- Redo path verifies feedback -> redo answer -> completed result -> home history summary
- Recording UI tests use `AIBIC_UI_TEST_FAKE_AUDIO=1` after the real permission decision so simulator host audio hardware does not make the suite flaky

## Resolved issue

The previous `simctl io ... screenshot` and UI screenshot output showed the app in a card-like frame with black surrounding space. Adding a system LaunchScreen storyboard and wiring it through `UILaunchStoryboardName` resolved the non-full-screen capture. The app now launches and tests in full iPhone screen geometry.

Current local capture artifact:

- Home: `/tmp/aibic-iphone-ui-attachments/DA4CC7DA-6BBC-48FD-A8B8-AF5A57487AB9.png`
- Privacy Notice: `/tmp/aibic-iphone-ui-attachments/232F3317-0D96-4076-AF3F-47714FB0E855.png`
- Resume Upload: `/tmp/aibic-iphone-ui-attachments/391BA537-54EF-4276-B051-E0588FE529EC.png`
- First Answer Recorded: `/tmp/aibic-iphone-ui-attachments/0753F2B0-0A7A-4464-AEEB-86FE256117B3.png`
- Follow-up Ready: `/tmp/aibic-iphone-ui-attachments/437544D9-42DC-4ACC-9FC8-3B2E10B0E4A4.png`
- Feedback Ready: `/tmp/aibic-iphone-ui-attachments/E8293763-35C4-453B-8A8B-73BC4989356C.png`
- Result Complete: `/tmp/aibic-iphone-ui-attachments/B22963ED-8C8E-42B4-AF5A-9D60E8E00A60.png`
- Home History After Redo: `/tmp/aibic-iphone-ui-attachments/B2BB0F2A-A84B-4624-B7D7-593528E4F8DC.png`
- Microphone Permission Sheet: `/tmp/aibic-iphone-ui-attachments/4B400CCD-9207-42E3-A3BC-08FDF8A890F9.png`

## Recommended next action

Run a final iPhone visual audit against the `.pen` source of truth and then prepare the branch for review. The critical training path now has foreground automation from resume-ready home through completed history.
