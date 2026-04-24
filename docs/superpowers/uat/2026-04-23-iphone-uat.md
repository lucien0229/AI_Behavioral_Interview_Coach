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

## Automated checks

- `git diff --check` passed
- `xcrun swiftc -typecheck $(rg --files AI_Behavioral_Interview_Coach -g'*.swift')` passed
- `xcodebuild -quiet test -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,id=F592A705-BDE3-495D-9F13-1134BC4F31DD' -resultBundlePath /tmp/aibic-iphone-ui.xcresult` passed
- Result bundle summary: 40 tests passed, 0 failed, 0 skipped
- UI screenshot attachments exported to `/tmp/aibic-iphone-ui-attachments`

## Simulator validation

- Simulator: `AIBIC iPhone 17` (`F592A705-BDE3-495D-9F13-1134BC4F31DD`)
- Install and launch succeeded after rebuild
- Home header text now renders as `Interview Coach` without truncation
- Foreground UI automation successfully navigates Home -> Privacy Notice and Home -> Resume Upload
- Full-screen screenshot output now matches iPhone geometry instead of the previous card-like capture
- Microphone privacy grant path had already been verified earlier with `simctl privacy`

## Resolved issue

The previous `simctl io ... screenshot` and UI screenshot output showed the app in a card-like frame with black surrounding space. Adding a system LaunchScreen storyboard and wiring it through `UILaunchStoryboardName` resolved the non-full-screen capture. The app now launches and tests in full iPhone screen geometry.

Current local capture artifact:

- Home: `/tmp/aibic-iphone-ui-attachments/67050D01-6A30-4201-88C1-BAFC04148C9D.png`
- Privacy Notice: `/tmp/aibic-iphone-ui-attachments/FC456447-0D98-4CFE-B2BE-E2EBE3B7B334.png`
- Resume Upload: `/tmp/aibic-iphone-ui-attachments/FE841B21-5F84-4A1A-B9FE-39B652C42FC5.png`

## Recommended next action

Extend foreground UI automation to the microphone permission and first-answer recording flow, using the existing iPhone simulator permission controls to validate both allowed and denied microphone states.
