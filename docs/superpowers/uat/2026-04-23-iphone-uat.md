# 2026-04-23 iPhone UAT

## Scope

- Device target: iPhone only (`TARGETED_DEVICE_FAMILY = 1`)
- Design source of truth: `docs/design/ios_hifi_pencil_original/AI_Behavioral_Interview_Coach_iOS_HiFi_v1.pen`
- Visual reference used in this pass: `docs/design/ios_hifi_pencil_original/exports/named_png/01_home_no_resume.png`

## Changes verified in this pass

- Fixed home header truncation for `Interview Coach`
- Added `UIRequiresFullScreen = YES` for the iPhone-only target
- Tightened root screen sizing so launch/home containers request full-window layout

## Automated checks

- `git diff --check` passed
- `xcrun swiftc -typecheck $(rg --files AI_Behavioral_Interview_Coach -g'*.swift')` passed
- `xcodebuild -quiet test -project AI_Behavioral_Interview_Coach.xcodeproj -scheme AI_Behavioral_Interview_Coach -destination 'platform=iOS Simulator,id=F592A705-BDE3-495D-9F13-1134BC4F31DD'` passed

## Simulator validation

- Simulator: `AIBIC iPhone 17` (`F592A705-BDE3-495D-9F13-1134BC4F31DD`)
- Install and launch succeeded after rebuild
- Home header text now renders as `Interview Coach` without truncation
- Microphone privacy grant path had already been verified earlier with `simctl privacy`

## Open issue

`simctl io ... screenshot` is still capturing the launched app in a windowed/card-like presentation instead of a full-screen frame that matches the `.pen` export. The code-level full-screen fixes above did not change that capture result, which suggests the remaining gap is likely in simulator/window state rather than the immediate home layout.

Current local capture artifact:

- `/tmp/aibic-iphone17-after-fullscreen-key.png`

## Recommended next action

Use a foreground-capable iOS UI control surface for the final visual pass on the iPhone simulator, then compare the home screen against `01_home_no_resume.png` and continue through resume upload, privacy notice, and microphone permission flows.
