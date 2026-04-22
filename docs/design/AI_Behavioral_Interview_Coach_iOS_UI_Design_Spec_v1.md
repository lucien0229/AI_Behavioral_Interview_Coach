# AI Behavioral Interview Coach iOS UI Design / Wireframe Spec v1

## 1. 文档信息

- 文档名称：AI Behavioral Interview Coach iOS UI Design / Wireframe Spec
- 版本：v1
- 日期：2026-04-21
- 适用范围：iOS 首版、收费验证版、英语、PM / Program Manager、简历个性化行为面试训练
- 视觉系统来源：`docs/design/DESIGN.md`
- 主要读者：产品设计、iOS 客户端、QA、产品、后端
- 文档目的：在不做高保真 Figma 的前提下，定义首版 iOS 页面布局、视觉 token、核心组件、状态样式和低保真 wireframe，供 SwiftUI mock 与实现直接使用

相关文档：

- `docs/design/DESIGN.md`
- `docs/ios/AI_Behavioral_Interview_Coach_iOS_Client_Screen_Spec_v1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_Client_UX_State_Error_Handling_Spec_v1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_Data_API_Spec_v1.1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_PRD_v1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_QA_Acceptance_Test_Plan_v1.md`

---

## 2. 设计目标

### 2.1 推荐方向

首版 iOS UI 采用 **Apple-inspired, practice-first, action-led** 方向：

- 视觉克制，使用黑 / 浅灰 / 近黑 / 白的高对比节奏。
- Apple Blue 只用于可点击行动。
- 页面重心永远是“下一步训练动作”，不是信息面板。
- 训练流程可以使用暗色沉浸背景，Home / History / Settings 使用浅灰信息背景。
- Feedback 页面优先让用户看到最大缺口和下一轮怎么改。

### 2.2 不做什么

- 不做聊天 App 风格。
- 不做招聘平台 / 求职管理后台风格。
- 不做彩色标签堆叠。
- 不做复杂 dashboard。
- 不做营销型首屏。
- 不用渐变、纹理、插画背景、装饰性大色块。
- 不把所有内容放进卡片；只给重复 item、sheet、关键工具区使用卡片。

---

## 3. DESIGN.md 到 iOS 的适配规则

`DESIGN.md` 是 Apple website inspiration。iOS app 不能机械照搬网页 hero 和 hover 模式，必须做以下适配。

| DESIGN.md 规则 | iOS 适配 |
|---|---|
| SF Pro Display / Text | 使用 SwiftUI system font；20pt 及以上按 Display 语义，19pt 以下按 Text 语义 |
| 负 letter-spacing | iOS 不手动设置 tracking；依赖 SF Pro / Dynamic Type 原生 optical sizing |
| 黑 / 浅灰 section rhythm | App 使用浅灰 Home / History / Settings，训练流程使用黑色或近黑沉浸背景 |
| Apple Blue only accent | 所有主操作、链接、focus ring 使用 `#0071e3` / `#0066cc` / `#2997ff` |
| 8px radius standard | iOS cards、buttons、panels 默认 8pt radius；pill CTA 只用于轻量 link / segmented chips |
| 少阴影 | 首版默认不用阴影；sheet、浮层遵循系统 elevation |
| full-width section | iOS 使用 full-screen band / grouped section，不做网页式大 hero |
| nav glass | iOS 使用系统 navigation material，不自定义网页黑色 nav |

硬规则：

- 不新增第二个 accent color。
- 不用自定义负字距。
- 不用大圆角卡片；矩形容器最大 8pt，系统 sheet 遵循 iOS 默认。
- 不在卡片里嵌套卡片。
- 不用边框堆层级，优先用背景色、留白、字号、字重建立层级。

---

## 4. 视觉 Tokens

### 4.1 Color tokens

| Token | Value | 用途 |
|---|---|---|
| `Color.canvasLight` | `#f5f5f7` | Home、History、Settings、Resume 页面背景 |
| `Color.canvasDark` | `#000000` | 训练问题、录音、processing 沉浸背景 |
| `Color.textPrimary` | `#1d1d1f` | 浅色背景主文本 |
| `Color.textOnDark` | `#ffffff` | 暗色背景主文本 |
| `Color.textSecondary` | `rgba(0, 0, 0, 0.8)` | 浅色背景次级文本 |
| `Color.textTertiary` | `rgba(0, 0, 0, 0.48)` | 辅助说明、disabled |
| `Color.interactiveBlue` | `#0071e3` | 主按钮、focus ring、关键链接 |
| `Color.linkBlue` | `#0066cc` | 浅色背景文字链接 |
| `Color.linkBlueOnDark` | `#2997ff` | 暗色背景文字链接 |
| `Color.surfaceLight` | `#ffffff` | 浅色页面中的内容块 |
| `Color.surfaceMuted` | `#fafafc` | filter、选择项、轻量控件背景 |
| `Color.surfaceDark` | `#272729` | 暗色训练页中的录音 / 状态面板 |
| `Color.surfaceDarkRaised` | `#2a2a2d` | 暗色页中最高层级面板 |
| `Color.overlay` | `rgba(210, 210, 215, 0.64)` | 录音控制辅助背景 |
| `Color.destructive` | `#1d1d1f` | 破坏操作不引入红色 accent，使用文本警告 + 系统 destructive role |

说明：

- iOS 可以用系统 destructive button role 触发系统红色确认样式，但 app 主 UI 不使用红色作为常驻品牌色。
- Assessment badge 不使用彩色语义底色，使用黑白灰层级表达 Strong / Mixed / Weak。

### 4.2 Typography tokens

使用 SF Pro system typography，并保留 `DESIGN.md` 的层级精神。

| Token | SwiftUI 建议 | Size | Weight | 用途 |
|---|---|---:|---|---|
| `Type.display` | `.system(size: 34, weight: .semibold)` | 34 | 600 | Home primary headline、训练题目短标题 |
| `Type.sectionTitle` | `.system(size: 28, weight: .semibold)` | 28 | 600 | Feedback 大段标题、Paywall 标题 |
| `Type.cardTitle` | `.system(size: 21, weight: .semibold)` | 21 | 600 | 内容块标题、history item title |
| `Type.body` | `.system(size: 17, weight: .regular)` | 17 | 400 | 正文、问题文本、反馈正文 |
| `Type.bodyEmphasis` | `.system(size: 17, weight: .semibold)` | 17 | 600 | 重点句、按钮旁标签 |
| `Type.button` | `.system(size: 17, weight: .regular)` | 17 | 400 | 主按钮 |
| `Type.caption` | `.system(size: 14, weight: .regular)` | 14 | 400 | 次级说明 |
| `Type.captionBold` | `.system(size: 14, weight: .semibold)` | 14 | 600 | badge、metadata |
| `Type.micro` | `.system(size: 12, weight: .regular)` | 12 | 400 | footnote、legal、timestamp |

Dynamic Type：

- 所有文本必须支持 Dynamic Type。
- Wireframe 中的固定 size 是视觉基准，不是禁用无障碍缩放。
- 小屏和大字体下，按钮文字允许换行；不得截断关键 CTA。

### 4.3 Spacing tokens

基于 `DESIGN.md` 的 8px unit。

| Token | Value | 用途 |
|---|---:|---|
| `Space.xs` | 4 | icon 与文字间距 |
| `Space.sm` | 8 | 紧密元素 |
| `Space.md` | 16 | 默认组内间距 |
| `Space.lg` | 24 | section 内间距 |
| `Space.xl` | 32 | screen 主区块间距 |
| `Space.screenX` | 20 | iPhone 横向安全边距 |
| `Space.screenTop` | 24 | navigation 下首个内容间距 |
| `Space.screenBottom` | 24 | home indicator 上方 |

### 4.4 Radius tokens

| Token | Value | 用途 |
|---|---:|---|
| `Radius.small` | 5 | 小标签 |
| `Radius.standard` | 8 | card、button、panel |
| `Radius.comfortable` | 11 | input、segmented chip |
| `Radius.pill` | full | link pill、focus chip |
| `Radius.circle` | 50% | 录音按钮、icon button |

### 4.5 Layout tokens

| Token | Value |
|---|---:|
| Minimum tap target | 44 x 44 |
| Primary button height | 48 |
| Bottom CTA height | 52 |
| Max readable line width on iPhone | full width minus 40pt |
| iPad content max width | 680 |
| Sheet content max width on iPad | 560 |

---

## 5. App Layout Model

### 5.1 Shell

```text
LaunchGate
  -> HomeNavigationStack
       Home
       HistoryList
       HistoryDetail
       Settings
```

Home 是唯一业务根页面。History 和 Settings 是 Home 的一跳 pushed screens，不使用底部 TabView，也不自定义网页式 sticky nav。

### 5.2 Page background rhythm

| Area | Background | Rationale |
|---|---|---|
| Launch | `canvasDark` | 初始化有安静、集中感 |
| Home | `canvasLight` | 信息与下一步行动 |
| Resume | `canvasLight` | 文件操作、状态说明 |
| Training question / answer | `canvasDark` | 沉浸式训练 |
| Feedback | `canvasLight` | 阅读和行动计划 |
| Redo | `canvasDark` | 回到训练模式 |
| Completed | `canvasLight` | 总结和下一步 |
| History | `canvasLight` | 扫描列表 |
| Paywall | `surfaceLight` sheet | 购买动作，克制 |
| Settings / Privacy | `canvasLight` | 信息管理 |

### 5.3 Primary action placement

- Home：primary CTA 在首屏上半区。
- Training：录音 / 提交 CTA 固定在内容下方，但不遮挡题目。
- Feedback：Redo / Skip redo 在阅读内容后出现；长反馈页底部可重复 sticky CTA。
- Paywall：Buy Sprint Pack 固定在 sheet 下方。
- Delete confirmation：破坏性按钮放在 sheet / dialog 底部。

---

## 6. Core Components

### 6.1 PrimaryActionButton

Visual:

- background：`interactiveBlue`
- text：white
- height：48-52
- radius：8
- horizontal padding：15+
- font：17 regular

States:

| State | Treatment |
|---|---|
| enabled | blue fill |
| pressed | slightly darker system press state |
| loading | disabled + inline spinner or progress label |
| disabled | `textTertiary` on `surfaceMuted` |
| focus | 2pt blue focus ring |

Use:

- Start training
- Continue session
- Upload resume
- Submit answer
- Redo this answer
- Buy Sprint Pack

### 6.2 SecondaryActionButton

Visual:

- text：`linkBlue` on light, `linkBlueOnDark` on dark
- background：transparent or subtle surface
- radius：pill only if standalone chip
- minimum height：44

Use:

- Privacy
- Restore purchase
- Skip redo
- Upload better resume
- Back home

### 6.3 HomePrimaryPanel

Purpose: one screen, one dominant next action.

Visual:

- full-width unframed section, not nested card
- background inherits page
- headline 34 semibold
- body 17 regular
- CTA directly below body
- supplemental metadata below CTA

Do not put multiple competing buttons in the primary panel.

### 6.4 StatusBanner

Visual:

- surface：`surfaceLight` on light page, `surfaceDark` on dark page
- radius：8
- icon：SF Symbol
- title：14 semibold
- body：14 regular
- no colored background except blue links

Use:

- offline
- long processing
- transcript quality failure
- redo review unavailable
- delete failure

### 6.5 RecordingControl

Visual:

- central circular button, minimum 72 x 72
- idle：dark surface + white microphone icon on dark pages
- recording：filled white circle with black stop icon; use timer text, not red color
- review：play / re-record / submit row
- uploading：disabled controls + progress label

Do not use waveform as required MVP component. A simple timer is enough.

### 6.6 AssessmentBadge

Visual tokens:

| Status | Treatment |
|---|---|
| Strong | near-black fill, white text |
| Mixed | `surfaceMuted` fill, near-black text |
| Weak | white fill, near-black text, subtle gray separator if needed |

Rationale:

- Avoid adding green / yellow / red semantic palette.
- Preserve DESIGN.md single accent principle.
- Use ordering and wording to communicate severity.

### 6.7 FeedbackSection

Visual:

- section title 21 semibold
- body 17 regular
- generous vertical spacing
- no card nesting
- strongest signal can appear after biggest gap, not as top hero

Sections:

1. Biggest gap
2. Why it matters
3. Redo priority
4. Redo outline
5. Strongest signal
6. Assessment summary

### 6.8 ProcessingStateView

Visual:

- dark background for training processing
- centered title
- short body
- small progress indicator
- after 90s, show status banner with `You can come back later.`

Do not use a naked spinner.

### 6.9 PaywallProductRow

Visual:

- one product row only
- no subscription comparison
- title：Sprint Pack
- body：number of practice credits
- CTA：Buy Sprint Pack
- restore link below

### 6.10 DeleteConfirmation

Visual:

- use system confirmation dialog for simple deletion
- use sheet for resume delete mode selection
- destructive copy must be explicit
- button role can be destructive, but page visuals do not introduce permanent red accent

---

## 7. Wireframe Notation

Symbols:

```text
[Button]        tappable button
(link)          text link / secondary CTA
{status}        system or data state
| card |        repeated item or framed tool
---             section divider / spacing
```

All wireframes are low fidelity. They define hierarchy and placement, not pixel-perfect sizes.

---

## 8. IOS-SCR-00 Launch / Bootstrap

Background: `canvasDark`

```text
┌─────────────────────────────┐
│                             │
│                             │
│        Interview Coach       │
│   Preparing your practice    │
│            space             │
│                             │
│          [progress]          │
│                             │
│                             │
└─────────────────────────────┘
```

Rules:

- Center content vertically.
- Do not mention auth, anonymous identity, token, or account.
- If bootstrap fails, keep dark background and replace progress with `[Retry]`.

---

## 9. IOS-SCR-01 Home

Background: `canvasLight`

### 9.1 Home layout shell

```text
┌─────────────────────────────┐
│ Interview Coach          ⚙︎  │
│                             │
│ {Primary state panel}        │
│ Title                        │
│ Body                         │
│ [Primary CTA]                │
│ (Secondary CTA)              │
│                             │
│ Resume                       │
│ file/status row              │
│                             │
│ Credits                      │
│ available practice rounds    │
│                             │
│ Last practice                │
│ | question summary        > |│
│                             │
│ View all history          >  │
└─────────────────────────────┘
```

### 9.2 Primary state variants

No resume:

```text
Title: Upload your resume to start
Body: Your practice questions will be based on your real experience.
[Upload resume]
(Privacy)
```

Resume processing:

```text
Title: Reading your resume
Body: We'll let you know when personalized practice is ready.
[View status]
(Cancel resume)
```

Active session:

```text
Title: Practice in progress
Body: Continue where you left off.
[Continue session]
```

Out of credits:

```text
Title: You're out of practice credits
Body: Buy a Sprint Pack to continue personalized practice.
[Buy Sprint Pack]
(Restore purchase)
```

Ready:

```text
Title: Ready for a practice round
Body: One question, one follow-up, and focused feedback.
[Start training]
(Choose focus)
```

Rules:

- Use Screen Spec `homePrimaryState` priority. Do not visually promote last training over primary state.
- `Last practice` is supplemental only.
- Home primary panel is not a card.
- Settings is an icon button in the top-right of Home.
- History is a row entry below Last practice, not a bottom tab.

---

## 10. IOS-SCR-02 Resume Upload

Background: `canvasLight`

```text
┌─────────────────────────────┐
│ < Back                      │
│ Upload your resume           │
│ PDF or DOCX, up to 5 MB      │
│                             │
│ ┌─────────────────────────┐ │
│ │                         │ │
│ │        document icon      │ │
│ │   Choose a resume file    │ │
│ │                         │ │
│ └─────────────────────────┘ │
│                             │
│ Your resume is used to make │
│ practice questions personal.│
│ (Privacy)                   │
│                             │
│ [Choose file]               │
└─────────────────────────────┘
```

Rules:

- Upload drop zone can be a framed tool card because it is the primary file picker.
- Do not show file contents or filename in analytics.
- Pending state changes CTA to disabled `Uploading`.

---

## 11. IOS-SCR-03 Resume Status / Manage

Background: `canvasLight`

Ready usable:

```text
┌─────────────────────────────┐
│ < Back                      │
│ Resume ready                 │
│ Product manager with...      │
│                             │
│ Anchor experiences           │
│ 3 recommended practice cues  │
│                             │
│ Strength signals             │
│ [Ownership] [Prioritization] │
│                             │
│ [Start training]             │
│ (Delete resume)              │
└─────────────────────────────┘
```

Unusable / failed:

```text
Title: This resume needs more detail
Body: We couldn't find enough concrete experience to build useful practice.
[Upload another resume]
(Delete resume)
```

Rules:

- Do not show raw resume text or source snippets.
- Use neutral tags, not colorful skill chips.

---

## 12. IOS-SCR-04 Training Focus Picker

Sheet background: `surfaceLight`

```text
┌─────────────────────────────┐
│ Choose a practice focus      │
│                             │
│ ○ Ownership                  │
│ ○ Prioritization             │
│ ○ Cross-functional Influence │
│ ○ Conflict Handling          │
│ ○ Failure / Learning         │
│ ○ Ambiguity                  │
│                             │
│ [Start training]             │
│ (Start without a focus)      │
└─────────────────────────────┘
```

Rules:

- Use single-selection list.
- Selected item uses blue check / radio; do not color every option.
- Sheet owns its dismiss behavior.

---

## 13. IOS-SCR-05 Training Processing States

Background: `canvasDark`

```text
┌─────────────────────────────┐
│                             │
│ Preparing your personalized  │
│ question                     │
│                             │
│ We're using your resume to   │
│ choose a relevant prompt.    │
│                             │
│          [progress]          │
│                             │
│ (Back home)                  │
└─────────────────────────────┘
```

Long processing:

```text
| This is taking longer than usual. |
| You can come back later.          |
```

Rules:

- Every processing state names the specific task.
- Dark background reinforces focused practice mode.
- Back home is secondary and never blue filled.

---

## 14. IOS-SCR-06 First Answer

Background: `canvasDark`

```text
┌─────────────────────────────┐
│ < Home              Question │
│                             │
│ Based on your launch work,   │
│                             │
│ Tell me about a time when    │
│ you had to make a high-      │
│ stakes prioritization        │
│ decision with incomplete     │
│ information.                 │
│                             │
│              00:00           │
│          ( mic button )      │
│                             │
│ Start when you're ready.     │
└─────────────────────────────┘
```

Review recorded answer:

```text
│              01:42           │
│ [Submit answer]              │
│ (Re-record)                  │
```

Rules:

- Question text is the visual center.
- Recording button is circular and at least 72pt.
- Timer is text, not decorative waveform.
- Transcript quality failure appears as `StatusBanner` above controls.

---

## 15. IOS-SCR-07 Follow-up Answer

Background: `canvasDark`

```text
┌─────────────────────────────┐
│ < Home             Follow-up │
│                             │
│ Original question            │
│ Tell me about a time...      │
│                             │
│ What specific decision did   │
│ you personally make at that  │
│ point?                       │
│                             │
│              00:00           │
│          ( mic button )      │
│                             │
└─────────────────────────────┘
```

Rules:

- Original question is visually secondary.
- Follow-up question is one sentence, prominent.
- No chat input and no multi-turn thread UI.

---

## 16. IOS-SCR-08 Feedback / Redo Decision

Background: `canvasLight`

```text
┌─────────────────────────────┐
│ Feedback                     │
│                             │
│ Biggest gap                  │
│ You still did not make your  │
│ personal ownership explicit  │
│ enough.                      │
│                             │
│ Why it matters               │
│ In a behavioral interview... │
│                             │
│ Redo priority                │
│ Spend one sentence on...     │
│                             │
│ Redo outline                 │
│ 1. Set context               │
│ 2. State your decision       │
│ 3. Explain the tradeoff      │
│ 4. Close with the result     │
│                             │
│ Strongest signal             │
│ You picked a relevant...     │
│                             │
│ Assessment                   │
│ Answered       [Strong]      │
│ Story fit      [Strong]      │
│ Ownership      [Weak]        │
│ Evidence       [Mixed]       │
│ Follow-up      [Weak]        │
│                             │
│ [Redo this answer]           │
│ (Skip redo)                  │
└─────────────────────────────┘
```

Rules:

- Biggest gap appears first.
- Assessment badges are low-chroma black / gray / white.
- No total score.
- Do not put every feedback section inside separate cards.

---

## 17. IOS-SCR-09 Redo Answer

Background: `canvasDark`

```text
┌─────────────────────────────┐
│ < Feedback             Redo  │
│                             │
│ Redo priority                │
│ Focus on the decision you    │
│ personally made.             │
│                             │
│ Outline                      │
│ 1. Context                   │
│ 2. Your decision             │
│ 3. Tradeoff                  │
│ 4. Result                    │
│                             │
│ Original question            │
│ Tell me about a time...      │
│                             │
│              00:00           │
│          ( mic button )      │
│                             │
└─────────────────────────────┘
```

Rules:

- Redo guidance stays visible above the recording control.
- Redo is one retry, not a second interview loop.

---

## 18. IOS-SCR-10 Completed Result

Background: `canvasLight`

Redo review generated:

```text
┌─────────────────────────────┐
│ Practice complete            │
│                             │
│ Redo review                  │
│ Partially improved           │
│                             │
│ What improved                │
│ Your decision was clearer... │
│                             │
│ Still missing                │
│ The result needs a metric... │
│                             │
│ Next attempt                 │
│ Add one measurable outcome.  │
│                             │
│ Original feedback            │
│ Biggest gap...               │
│                             │
│ [Start next]                 │
│ (Back home)                  │
└─────────────────────────────┘
```

Redo review unavailable:

```text
| Redo review is temporarily unavailable. |
| Your original feedback is saved, and    |
| this practice round is complete.        |
```

Rules:

- Unavailable is a light banner, not a failure page.
- Start next follows Home / Paywall logic.

---

## 19. IOS-SCR-11 History List

Background: `canvasLight`

```text
┌─────────────────────────────┐
│ < Back       History         │
│                             │
│ | Tell me about a time... > |│
│ | Ownership · Apr 21        |│
│ | Redo: Partially improved  |│
│                             │
│ | Tell me about a conflict >│
│ | Conflict · Apr 20         |│
│ | Redo skipped              |│
│                             │
└─────────────────────────────┘
```

Empty:

```text
Title: No practice history yet
Body: Complete a practice round to see it here.
[Start training]
```

Rules:

- History list items may be cards because they are repeated items.
- Do not show transcript or full feedback in list.
- Empty-state Start training returns to Home first, then follows Home primary state.

---

## 20. IOS-SCR-12 History Detail

Background: `canvasLight`

```text
┌─────────────────────────────┐
│ < History                    │
│ Ownership                    │
│ Tell me about a time...      │
│                             │
│ Follow-up                    │
│ What specific decision...    │
│                             │
│ Feedback                     │
│ Biggest gap...               │
│ Why it matters...            │
│                             │
│ Redo review                  │
│ Partially improved           │
│                             │
│ (Delete practice round)      │
└─────────────────────────────┘
```

Rules:

- Read-only.
- If session is active, route to Training Session instead of history detail.

---

## 21. IOS-SCR-13 Paywall / Billing

Sheet background: `surfaceLight`

```text
┌─────────────────────────────┐
│ Continue personalized        │
│ practice                     │
│                             │
│ You have 0 practice credits. │
│                             │
│ Sprint Pack                  │
│ 5 personalized practice      │
│ rounds                       │
│                             │
│ [Buy Sprint Pack]            │
│ (Restore purchase)           │
│                             │
│ Purchases are verified with  │
│ Apple before credits appear. │
└─────────────────────────────┘
```

Rules:

- One product only.
- No countdown, discount badge, or pressure copy.
- Verify failure keeps the sheet open and shows Retry verification.

---

## 22. IOS-SCR-14 Settings / Data

Background: `canvasLight`

```text
┌─────────────────────────────┐
│ < Back       Settings        │
│                             │
│ Practice data                │
│ Manage resume             >  │
│ Restore purchase          >  │
│                             │
│ Privacy and deletion         │
│ Privacy                   >  │
│ Delete all data           >  │
│                             │
│ App version                  │
│ 1.0.0                        │
└─────────────────────────────┘
```

Rules:

- No account login / signup row.
- Delete all data row uses destructive role, but no permanent red accent in normal state.
- Settings Back returns to the previous screen in the navigation stack: Home when entered from Home, Privacy Notice when entered from Manage data.

---

## 23. IOS-SCR-15 Delete Confirmation

Resume delete mode sheet:

```text
┌─────────────────────────────┐
│ Delete resume                │
│                             │
│ Your original resume will be │
│ removed. Choose what happens │
│ to linked practice content.  │
│                             │
│ [Delete resume only]         │
│ [Delete resume and training] │
│ (Cancel)                     │
└─────────────────────────────┘
```

Cancel parsing resume:

```text
Title: Cancel resume processing?
Body: This stops using the current resume for practice. You can upload another resume afterward.
[Cancel resume processing]
(Keep waiting)
```

Delete all data:

```text
Title: Delete all app data?
Body: This deletes your resume, audio, transcripts, feedback, and history. Your local app profile will be reset.
[Delete all app data]
(Cancel)
```

Rules:

- Destructive copy must name the consequence.
- Delete pending disables all destructive buttons.
- Failure keeps the current data visible.

---

## 24. IOS-SCR-16 Offline / Fatal Recovery

Offline with cache:

```text
┌─────────────────────────────┐
│ You're offline               │
│ You can view the latest      │
│ saved state, but new actions │
│ need a connection.           │
│                             │
│ [Retry]                      │
└─────────────────────────────┘
```

Fatal blocked:

```text
Title: We couldn't prepare the app
[Retry app setup]
```

Rules:

- Disable upload, submit, purchase, and delete actions while offline.
- Do not queue destructive actions silently.

---

## 25. IOS-SCR-17 Privacy Notice

Background: `canvasLight`

```text
┌─────────────────────────────┐
│ < Back       Privacy         │
│                             │
│ What we use                  │
│ Resume file, practice audio, │
│ transcripts, AI feedback,    │
│ and purchase entitlement.    │
│                             │
│ Why we use it                │
│ To create resume-based       │
│ practice and manage credits. │
│                             │
│ Your controls                │
│ Delete resume, delete a      │
│ practice round, or delete    │
│ all app data.                │
│                             │
│ [Manage data]                │
└─────────────────────────────┘
```

Rules:

- In-app notice is short and operational.
- Do not show sensitive user content.

---

## 26. Responsive / Device Rules

### 26.1 iPhone

- Use single-column layout.
- Horizontal margins: 20pt.
- Bottom CTA must clear the home indicator.
- Long question / feedback text scrolls; recording controls remain below content when possible.

### 26.2 Small iPhone

- Reduce large headings from 34 to 28 if necessary through Dynamic Type / layout priority.
- Do not shrink body below 17 baseline.
- CTA text may wrap to two lines if localized later.

### 26.3 iPad

- Center content with max width 680pt.
- Do not stretch feedback paragraphs across full screen.
- Sheets max width 560pt.
- Keep the same Home-first navigation on iPad; do not introduce a sidebar or TabView for v1.

---

## 27. Accessibility Requirements

- Minimum tap target: 44 x 44.
- Every icon-only button needs VoiceOver label.
- Recording control labels:
  - `Start recording`
  - `Stop recording`
  - `Submit answer`
  - `Record again`
- Processing states must announce state changes.
- Assessment badges must expose label and value, e.g. `Personal ownership, Weak`.
- Blue links must not be the only signifier; use button shape, underline, or row chevron where needed.
- Dynamic Type must not overlap recording controls or bottom CTAs.
- Destructive confirmation must be reachable and understandable with VoiceOver.

---

## 28. Implementation Handoff

### 28.1 Required SwiftUI components

| Component | Source section |
|---|---|
| `PrimaryActionButton` | 6.1 |
| `SecondaryActionButton` | 6.2 |
| `HomePrimaryPanel` | 6.3 |
| `StatusBanner` | 6.4 |
| `RecordingControl` | 6.5 |
| `AssessmentBadge` | 6.6 |
| `FeedbackSection` | 6.7 |
| `ProcessingStateView` | 6.8 |
| `PaywallProductRow` | 6.9 |
| `DeleteConfirmationView` | 6.10 |

### 28.2 Preview requirements

Create previews for:

- Home all primary states.
- Resume Upload idle / uploading / failed.
- Training question idle / recording / review / transcript failure.
- Processing normal / long processing.
- Feedback with Strong / Mixed / Weak badges.
- Completed with redo review generated / unavailable.
- History empty / populated.
- Paywall default / verifying / verify failed.
- Delete confirmations.
- Privacy Notice.

### 28.3 Design QA checklist

- Apple Blue appears only on interactive elements.
- No additional accent colors are introduced.
- Cards use 8pt radius or less.
- No card inside card.
- No decorative gradients or textures.
- Home has exactly one primary CTA.
- Last practice is supplemental only.
- Training answer screens use dark immersive background.
- Feedback is readable on light background and starts with biggest gap.
- Paywall is one product, no pressure marketing.
- Delete flows state consequences before confirmation.
- All screens support Dynamic Type without overlap.

---

## 29. 最小验收标准

iOS UI Design / Wireframe Spec v1 满足以下条件才可进入 SwiftUI mock：

1. 视觉 token 明确来自 `DESIGN.md`，并说明 iOS 适配差异。
2. 每个 Screen Spec 中的 IOS-SCR-00 至 IOS-SCR-17 都有 wireframe 或明确布局规则。
3. Home 的所有 primary states 都有视觉落点，且 last training 只作为 supplemental card。
4. Training question、follow-up、redo 使用暗色沉浸背景。
5. Feedback 使用浅色阅读背景，并按 biggest gap 优先展示。
6. Paywall 保持单商品、克制展示，不做订阅比较。
7. Delete confirmation 明确展示删除后果。
8. Privacy Notice 有独立页面。
9. 核心组件可以直接映射到 SwiftUI reusable views。
10. Accessibility、Dynamic Type、tap target 有明确规则。

---

## 30. 一句话收束

iOS UI Design / Wireframe Spec v1 的目标，是把 `DESIGN.md` 的 Apple-inspired 视觉系统压缩成适合 iOS 训练产品的低保真设计蓝图：浅色页面负责信息与管理，暗色页面负责沉浸训练，Apple Blue 只负责行动，让用户始终清楚下一步该做什么。
