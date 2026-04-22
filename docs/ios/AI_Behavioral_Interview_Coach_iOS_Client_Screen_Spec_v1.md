# AI Behavioral Interview Coach iOS Client Screen Spec v1

## 1. 文档信息

- 文档名称：AI Behavioral Interview Coach iOS Client Screen Spec
- 版本：v1
- 日期：2026-04-21
- 适用范围：iOS 首版、收费验证版、英语、PM / Program Manager、简历个性化行为面试训练
- 主要读者：iOS 客户端、产品设计、后端、QA、数据
- 文档目的：把 PRD、Data / API、Prompt、Client UX、Analytics 和 QA 文档落到 iOS 页面、导航、状态和操作规格，供 SwiftUI 开发直接执行

相关文档：

- `docs/ios/AI_Behavioral_Interview_Coach_PRD_v1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_Data_API_Spec_v1.1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_Prompt_Content_Spec_v1.1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_Client_UX_State_Error_Handling_Spec_v1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_Analytics_Event_Spec_v1.md`
- `docs/ios/AI_Behavioral_Interview_Coach_QA_Acceptance_Test_Plan_v1.md`
- `docs/design/AI_Behavioral_Interview_Coach_iOS_UI_Design_Spec_v1.md`

---

## 2. 本文档解决什么问题

本文档只解决 iOS 客户端“屏幕怎么组织、每屏展示什么、用户点击后调用什么、状态如何落页”的问题。

本文档不重新定义：

- 产品定位
- Prompt 内容
- API 字段语义
- 服务端状态机
- analytics 事件 schema
- QA 用例

这些内容分别以上述源文档为准。

---

## 3. iOS 首版推荐信息架构

### 3.1 推荐结论

iOS 首版使用以下结构：

```text
AppShell
  -> Launch / Bootstrap Gate
  -> HomeNavigationStack
       -> Home
       -> Resume Upload
       -> Resume Status / Manage
       -> Training Session
       -> History List
       -> History Detail
       -> Settings / Data
       -> Privacy Notice

Global sheets / covers
  -> Training Focus Sheet
  -> Paywall Sheet
  -> Delete Confirmation Sheet
  -> Microphone Permission Sheet
  -> API Error Sheet
```

推荐使用 SwiftUI：

- Home 是唯一业务根页面，App 启动和业务返回都回到 Home。
- History 和 Settings 不是顶层 tab，只能从 Home 的一跳入口进入。
- 训练流程从 Home push 进入 `TrainingSessionScreen`。
- Paywall 使用 sheet，而不是 push 到导航栈。
- 删除确认、训练重心选择、错误恢复使用 enum-driven `.sheet(item:)` 或 `.confirmationDialog`。
- 全局状态使用 root-owned `@Observable` app model；页面局部状态使用 `@State`。

### 3.2 为什么这样拆

首版产品的核心不是内容浏览，而是“从 Home 进入一次完整训练”。因此 Home 必须是启动后的第一业务屏和唯一根页面；History 和 Settings 是辅助入口，不能被提升为并列一级模块。训练流程是强任务流，应该由 Home 或 History detail 进入，不应该平铺成顶层导航。

### 3.3 不推荐做法

- 不做独立 Marketing / Landing 页。
- 不做强制登录页。
- 不把 Paywall 放在首屏之前。
- 不使用底部 TabView。
- 不把 Training、History 或 Settings 拆成顶层 tab。
- 不在本地自建训练状态机来覆盖服务端状态。
- 不用多个 boolean 控制互斥 sheet。

---

## 4. 全局屏幕原则

### 4.1 用户可见语言

iOS 用户可见文案使用英文。本文档使用中文说明开发规则，示例 UI copy 使用英文。

### 4.2 首屏原则

bootstrap 成功后直接进入 Home。Home 必须展示用户下一步该做什么：

- 没有简历：Upload resume
- 简历解析中：Preparing your resume
- 可训练：Start training
- 有 active session：Continue session
- 无额度：Buy Sprint Pack

### 4.3 数据来源原则

每个 screen 必须从指定 API 或本地状态读取数据：

| 数据 | Source of truth |
|---|---|
| Home 聚合状态 | `GET /home` |
| 当前训练状态 | `GET /training-sessions/{session_id}` |
| 简历解析状态 | `GET /resumes/{resume_id}` 或 `GET /home` |
| 额度与商品 | `GET /billing/entitlement` |
| 历史列表 | `GET /training-sessions/history?limit=10` |
| 历史详情 | `GET /training-sessions/{session_id}` |
| 错误码 | API envelope `error.code` |

客户端可以缓存最近一次成功数据，但渲染 active session、余额和删除状态时必须以最新 API 返回为准。

### 4.4 状态呈现原则

- 任何加载状态都必须说明正在做什么，不允许只展示裸 spinner。
- 写请求 pending 时，触发按钮必须禁用。
- 所有写请求必须有稳定 `Idempotency-Key`。
- 用户重新执行同一动作但 payload 已变化时，必须生成新的 `Idempotency-Key`。
- `UNAUTHORIZED` 先自动 bootstrap 恢复，再重试原请求一次。
- API 返回 `error != null` 时必须记录 `api_error_received`。

### 4.5 隐私原则

iOS 客户端不得长期缓存：

- 原始简历全文
- 完整转写文本
- 完整 AI feedback
- Apple signed transaction payload

允许短期缓存：

- `app_user_id`
- `access_token` 与过期时间
- `app_account_token`
- 最近一次成功的 Home response
- 最近 5 条 history summary
- 当前 active session id
- 未完成写请求的 idempotency record

---

## 5. Screen 清单

| Screen ID | Screen | 类型 | 主要职责 |
|---|---|---|---|
| IOS-SCR-00 | Launch / Bootstrap | Gate | 创建或恢复匿名身份 |
| IOS-SCR-01 | Home | Root | 展示下一步、简历、余额、active session、最近训练 |
| IOS-SCR-02 | Resume Upload | Push | 选择、校验、上传简历 |
| IOS-SCR-03 | Resume Status / Manage | Push | 展示解析状态、不可训练原因、删除入口 |
| IOS-SCR-04 | Training Focus Picker | Sheet | 选择训练重心 |
| IOS-SCR-05 | Training Session Shell | Push | 根据 session status 路由训练子状态 |
| IOS-SCR-06 | First Answer | Session state | 展示问题并录制首轮回答 |
| IOS-SCR-07 | Follow-up Answer | Session state | 展示追问并录制追问回答 |
| IOS-SCR-08 | Feedback / Redo Decision | Session state | 展示 feedback，进入 redo 或 skip |
| IOS-SCR-09 | Redo Answer | Session state | 录制重答 |
| IOS-SCR-10 | Completed Result | Session state | 展示最终结果和下一次训练入口 |
| IOS-SCR-11 | History List | Push | 展示最近训练摘要 |
| IOS-SCR-12 | History Detail | Push | 查看历史训练 feedback / redo review |
| IOS-SCR-13 | Paywall / Billing | Sheet | 购买 Sprint Pack、restore |
| IOS-SCR-14 | Settings / Data | Push | 数据管理、隐私、删除全部数据 |
| IOS-SCR-15 | Delete Confirmation | Dialog / Sheet | 简历、训练、全部数据删除确认 |
| IOS-SCR-16 | Offline / Fatal Recovery | Gate / Overlay | 网络、bootstrap、不可恢复状态 |
| IOS-SCR-17 | Privacy Notice | Push | 展示首版数据使用、存储与删除说明 |

---

## 6. 导航规格

### 6.1 Home-first 结构

Home 是唯一 root screen。History 和 Settings 不做 tab，不常驻底部导航。

Home 必须提供以下一跳入口：

| Home entry | Icon 建议 | Target |
|---|---|---|
| Settings icon | gearshape | IOS-SCR-14 |
| View all history row | clock.arrow.circlepath | IOS-SCR-11 |
| Last practice card | chevron.right | IOS-SCR-12 |

训练从以下入口进入：

- Home 的 Start training
- Home 的 Continue session
- Home 的 last training summary
- History list item 进入历史详情；如果用户从历史空态开始训练，必须先回到 Home 再走 Home primary state

### 6.2 Route enum

iOS 推荐使用明确的 route enum：

```swift
enum AppRoute: Hashable {
    case resumeUpload
    case resumeManage(resumeID: String)
    case trainingSession(sessionID: String)
    case historyList
    case historyDetail(sessionID: String)
    case settings
    case privacyNotice
}
```

Settings 和 History 都是普通 `AppRoute`，不得通过底部导航选择状态管理。Privacy Notice 的 `Manage data` 直接 push `AppRoute.settings`。

### 6.3 Sheet enum

推荐使用单一 sheet enum：

```swift
enum AppSheet: Identifiable {
    case trainingFocus(current: TrainingFocus?)
    case paywall(reason: PaywallReason)
    case deleteResume(reason: DeleteResumeReason)
    case deleteSession(sessionID: String)
    case deleteAllData
    case microphonePermission
    case apiError(APIErrorPresentation)
}
```

```swift
enum DeleteResumeReason: Hashable {
    case userManage
    case parsingCancel
}
```

互斥 modal 不得使用多个 boolean。

### 6.4 返回规则

| 当前页面 | 返回行为 |
|---|---|
| Resume Upload 上传前 | 返回 Home |
| Resume Upload 上传 pending | 禁止返回或返回前确认取消 |
| Training feedback 前 | 允许返回 Home，但 Home 必须显示 Continue session |
| Training `redo_available` | 允许返回 Home，但 Home 必须显示 Continue session |
| Training `completed` | Back home 或 Start next |
| History List | 返回 Home |
| History Detail | 返回 History List |
| Settings / Data | 返回 Home 或触发来源 |
| Paywall | 关闭后回到触发来源 |
| Privacy Notice | 返回触发来源 |
| Delete all data 成功 | 清空本地状态，回到 Launch |

### 6.5 全局 CTA 硬映射

任何用户可点击 CTA 都必须落到本表定义的 route、sheet 或 API。新增 CTA 时必须先补本表，避免出现“界面文案有入口，但导航和行为没有闭环”的实现漂移。

| Surface | CTA | 条件 | Route / Sheet | API | Analytics |
|---|---|---|---|---|---|
| Home | Upload resume | `homePrimaryState = noResume` | push IOS-SCR-02 | 无 | 无 |
| Home | Privacy | 无简历或用户主动查看隐私说明 | push IOS-SCR-17 | 无 | 无 |
| Home | View status | `homePrimaryState = resumeProcessing` | push IOS-SCR-03 | `GET /resumes/{resume_id}` | 无 |
| Home | Cancel resume | `homePrimaryState = resumeProcessing` | present IOS-SCR-15, `.deleteResume(reason: .parsingCancel)` | 确认后 `DELETE /resumes/active`，`delete_mode = resume_only_redacted_history` | 失败时 `api_error_received`；成功由 server 发 `resume_delete_completed` |
| Home | Start training | `homePrimaryState = ready` 或 `readyLimited` | present IOS-SCR-04 | focus 确认后 `POST /training-sessions` | `training_session_create_started`；失败时 `training_session_create_failed` |
| Home | Choose focus | 可开始训练 | present IOS-SCR-04 | 无 | `training_focus_selected` |
| Home | Continue session | `homePrimaryState = activeSession` | push IOS-SCR-05 | `GET /training-sessions/{session_id}` | 无 |
| Home | Upload better resume | `homePrimaryState = readyLimited` | push IOS-SCR-02 | 无 | 无 |
| Home | Upload another resume | `homePrimaryState = resumeFailed` 或 `resumeUnusable` | push IOS-SCR-02 | 无 | 无 |
| Home | View reason | `homePrimaryState = resumeFailed` 或 `resumeUnusable` | push IOS-SCR-03 | `GET /resumes/{resume_id}` | 无 |
| Home | Buy Sprint Pack | `homePrimaryState = outOfCredits` | present IOS-SCR-13, `reason = insufficient_credits` | `GET /billing/entitlement` | `paywall_viewed` |
| Home | Restore purchase | `homePrimaryState = outOfCredits` | present IOS-SCR-13 | `POST /billing/apple/restore` after user action | `purchase_restored` 由 server 发 |
| Home | View last training | `last_training_summary != null` supplemental card | push IOS-SCR-12 | `GET /training-sessions/{session_id}` | 无 |
| Home | Manage resume | `active_resume != null` supplemental card | push IOS-SCR-03 | `GET /resumes/active` 或 `GET /resumes/{resume_id}` | 无 |
| Home | View all history | always; empty history is handled by IOS-SCR-11 empty state | push IOS-SCR-11 | `GET /training-sessions/history?limit=10` | 无 |
| Home | Settings icon | always | push IOS-SCR-14 | 无 | 无 |
| Resume Upload | Choose file | idle | system file picker | 无 | 无 |
| Resume Upload | Privacy note | user taps privacy note | push IOS-SCR-17 | 无 | 无 |
| Resume Upload | Upload selected file | valid PDF / DOCX | stay on IOS-SCR-02 then push IOS-SCR-03 | `POST /resumes` | `resume_upload_started`；成功由 server 发 `resume_upload_completed` |
| Resume Upload | Retry upload | upload request failed and same file retained | stay on IOS-SCR-02 | retry `POST /resumes` with same idempotency key | 失败时 `api_error_received` |
| Resume Manage | Start training | ready usable / limited and has credit | present IOS-SCR-04 | focus 确认后 `POST /training-sessions` | `training_session_create_started` |
| Resume Manage | Upload better resume | ready limited | push IOS-SCR-02 | 无 | 无 |
| Resume Manage | Delete resume | active resume exists | present IOS-SCR-15, `.deleteResume(reason: .userManage)` | 确认后 `DELETE /resumes/active` | 失败时 `api_error_received`；成功由 server 发 `resume_delete_completed` |
| Training Focus | Start training | focus selected or skipped | push IOS-SCR-05 on success | `POST /training-sessions` | `training_session_create_started`；失败时 `training_session_create_failed` |
| Training Focus | Start without a focus | no focus selected | push IOS-SCR-05 on success | `POST /training-sessions` without `training_focus` | `training_session_create_started` |
| First Answer | Start recording | microphone granted | stay on IOS-SCR-06 | 无 | `first_answer_recording_started` |
| First Answer | Submit answer | recorded audio ready | session processing state | `POST /training-sessions/{session_id}/first-answer` | server 发 `first_answer_submitted` 或 `first_answer_transcription_failed` |
| First Answer | Back home | any non-pending state | pop to Home | `GET /home` | 无 |
| Follow-up Answer | Start recording | microphone granted | stay on IOS-SCR-07 | 无 | `follow_up_answer_recording_started` |
| Follow-up Answer | Submit answer | recorded audio ready | session processing state | `POST /training-sessions/{session_id}/follow-up-answer` | server 发 `follow_up_answer_submitted` 或 `follow_up_answer_transcription_failed` |
| Follow-up Answer | Back home | any non-pending state | pop to Home | `GET /home` | 无 |
| Feedback | Redo this answer | `status = redo_available` | show IOS-SCR-09 state | 无 | `redo_started` when recording starts |
| Feedback | Skip redo | `status = redo_available` | IOS-SCR-10 on success | `POST /training-sessions/{session_id}/skip-redo` | server 发 `redo_skipped` 和 `training_session_completed` |
| Redo | Submit redo | recorded audio ready | session processing state | `POST /training-sessions/{session_id}/redo` | server 发 `redo_submitted` 或 `redo_transcription_failed` |
| Completed Result | Back home | `status = completed` | pop to Home | `GET /home` | 无 |
| Completed Result | Start next | `status = completed` | Home then IOS-SCR-04 or IOS-SCR-13 | `GET /home`; then `POST /training-sessions` or billing APIs | 按后续动作发送 |
| History List | Start training | empty history and user wants new round | pop Home; then present IOS-SCR-04 or IOS-SCR-13 according to `homePrimaryState` | `GET /home`; then `POST /training-sessions` or billing APIs | `training_session_create_started` |
| History List | History item | item selected | push IOS-SCR-12 | `GET /training-sessions/{session_id}` | 无 |
| History Detail | Delete training entry | completed / failed / abandoned detail | present IOS-SCR-15 | 确认后 `DELETE /training-sessions/{session_id}` | 成功由 server 发 `training_session_delete_completed` |
| Paywall | Buy Sprint Pack | entitlement loaded | stay in IOS-SCR-13 | StoreKit 2 then `POST /billing/apple/verify` | `purchase_started`; verify 成功由 server 发 `purchase_verified` |
| Paywall | Restore purchase | user taps restore | stay in IOS-SCR-13 | `POST /billing/apple/restore` | 成功由 server 发 `purchase_restored` |
| Paywall | Retry verification | StoreKit succeeded but server verify failed or network failed | stay in IOS-SCR-13 | retry `POST /billing/apple/verify` with same idempotency key and transaction payload | 失败时 `purchase_failed` |
| Settings | Manage resume | active resume exists or cached resume state exists | push IOS-SCR-03 | `GET /resumes/active` | 无 |
| Settings | Restore purchase | user taps restore | present IOS-SCR-13 | `POST /billing/apple/restore` after user action | 成功由 server 发 `purchase_restored` |
| Settings | Privacy | always | push IOS-SCR-17 | 无 | 无 |
| Settings | Delete all data | always | present IOS-SCR-15 | 确认后 `DELETE /app-users/me/data` | 成功由 server 发 `user_data_delete_completed` |
| Privacy Notice | Manage data | always | push IOS-SCR-14 | 无 | 无 |
| Privacy Notice | Back | always | pop to source | 无 | 无 |
| Delete Confirmation | Confirm delete | destructive action confirmed | return according to source | 对应 DELETE API | 失败时 `api_error_received` |
| Delete Confirmation | Cancel | user cancels | dismiss | 无 | 无 |
| Offline / Fatal | Retry | network or bootstrap failure | stay on current gate / overlay | retry failed read or bootstrap | 对应失败事件 |
| Microphone Permission | Open Settings | permission denied | iOS Settings app | 无 | 无 |

---

## 7. IOS-SCR-00 Launch / Bootstrap

### 7.1 进入条件

- App 首次启动
- 本地没有有效 `access_token`
- 删除全部数据成功后
- 任意 API 返回 `UNAUTHORIZED` 且需要恢复身份

### 7.2 数据与 API

- `POST /app-users/bootstrap`
- 成功后立即 `GET /home`

### 7.3 UI 内容

用户只看到短加载状态：

- Primary copy：`Preparing your practice space`
- Secondary copy：`This usually takes a moment.`

不得出现：

- anonymous user
- auth session
- token
- account recovery

### 7.4 成功路径

1. 生成或读取稳定 `installation_id`。
2. 发送 `app_bootstrap_started`。
3. 调用 bootstrap。
4. 保存 token、过期时间、`app_account_token`。
5. 发送 `app_bootstrap_completed`。
6. 调用 `GET /home`。
7. 进入 Home。

### 7.5 失败路径

| 条件 | UX | 主操作 |
|---|---|---|
| 网络不可用且无缓存 | `You're offline` | Retry |
| bootstrap API 失败 | `We couldn't prepare the app` | Retry |
| 连续失败 | `Something went wrong` | Retry app setup |

### 7.6 Analytics

- `app_bootstrap_started`
- `app_bootstrap_completed`
- `app_bootstrap_failed`
- `api_error_received`

### 7.7 验收

- bootstrap 成功前不展示上传、训练、购买入口。
- bootstrap 成功后一定渲染 Home。
- 删除全部数据后重新进入该 screen，并创建新的本地上下文。

---

## 8. IOS-SCR-01 Home

### 8.1 进入条件

- bootstrap 成功
- 用户从训练、历史、设置返回
- App foreground 后刷新
- token 恢复成功后刷新

### 8.2 数据与 API

- `GET /home`

Home 只根据该接口渲染主业务状态。

### 8.3 页面结构

推荐布局顺序：

1. Header：产品名或短标题 `Interview Coach`
2. Primary action area：根据 Home state 展示唯一主 CTA
3. Resume status block
4. Credits summary
5. Last training summary
6. Secondary actions：Header trailing Settings icon；View all history row

### 8.4 Home primary state 派生算法

Home 必须先从 `GET /home` 派生唯一 `homePrimaryState`，再渲染 primary action。以下条件不是互斥字段，客户端不得直接用多个 `if` 在 View 中抢渲染；必须按本节顺序计算，命中第一条后停止。

推荐 Swift enum：

```swift
enum HomePrimaryState: Equatable {
    case activeSession(sessionID: String)
    case noResume
    case resumeProcessing(resumeID: String)
    case resumeFailed(resumeID: String)
    case resumeUnusable(resumeID: String)
    case outOfCredits(resumeID: String)
    case readyLimited(resumeID: String)
    case ready(resumeID: String)
}
```

派生顺序：

| Priority | 条件 | `homePrimaryState` | Primary CTA | Secondary CTA |
|---:|---|---|---|---|
| 1 | `active_session != null` | `activeSession` | Continue session | 无 |
| 2 | `active_resume = null` | `noResume` | Upload resume | Privacy |
| 3 | `active_resume.status = uploaded / parsing` | `resumeProcessing` | View status | Cancel resume |
| 4 | `active_resume.status = failed` | `resumeFailed` | Upload another resume | View reason |
| 5 | `active_resume.profile_quality_status = unusable` | `resumeUnusable` | Upload another resume | View reason |
| 6 | `active_resume.status = ready` 且 `profile_quality_status = usable / limited` 且 `available_session_credits = 0` | `outOfCredits` | Buy Sprint Pack | Restore purchase |
| 7 | `active_resume.status = ready` 且 `profile_quality_status = limited` | `readyLimited` | Start training | Upload better resume |
| 8 | `active_resume.status = ready` | `ready` | Start training | Choose focus |

`available_session_credits` 计算规则：

```text
available_session_credits =
  free_session_credits_remaining + paid_session_credits_remaining
```

`reserved_session_credits` 不加入可用次数；如果存在 active session，第 1 优先级已经拦截。

硬规则：

- `active_session` 永远优先于简历、额度和历史摘要。
- 简历正在解析时，不允许 Start training，即使有历史摘要或剩余额度。
- 简历不可训练时，不允许 Buy Sprint Pack 成为 primary CTA；用户必须先换简历。
- 无额度只在“有可训练或有限可训练简历，且没有 active session”时成为 primary state。
- `last_training_summary` 永远不是 primary state，只能作为 supplemental card 展示。
- `last_training_summary` 不得改变 primary CTA；例如 ready + last summary 时 primary 仍是 Start training，last summary 只显示 `View last training` 卡片。
- parsing + last summary 时 primary 仍是 View status，last summary 可以保留为下方只读卡片。

### 8.5 Supplemental cards

Home 除 primary action area 外，可以展示 supplemental cards，但不得与 primary state 抢主操作。

| Supplemental data | 展示规则 | 操作 |
|---|---|---|
| `last_training_summary != null` | 显示在 primary action area 下方；最多 1 张卡片 | View last training |
| `usage_balance` | 显示可用训练次数；active session 时可弱化展示 | Buy Sprint Pack 只在 `outOfCredits` 或用户主动打开购买时出现 |
| `active_resume.file_name` | 简历存在时显示文件名和状态 | Manage resume |

### 8.6 CTA 行为引用

Home CTA 不在本节重复定义。所有按钮必须按第 6.5 节“全局 CTA 硬映射”执行。

### 8.7 训练重心入口

Home 上不常驻复杂筛选面板。用户点击 Start training 后展示 Training Focus Sheet；默认选中最近一次使用的 focus，若没有历史，默认不选，允许用户直接开始。

### 8.8 空状态文案

No resume:

- Title：`Upload your resume to start`
- Body：`Your practice questions will be based on your real experience.`
- CTA：`Upload resume`

Ready:

- Title：`Ready for a practice round`
- Body：`One question, one follow-up, and focused feedback.`
- CTA：`Start training`

Active session:

- Title：`Practice in progress`
- Body：`Continue where you left off.`
- CTA：`Continue session`

Out of credits:

- Title：`You're out of practice credits`
- Body：`Buy a Sprint Pack to continue personalized practice.`
- CTA：`Buy Sprint Pack`

### 8.9 Analytics

Home 成功渲染后发送：

- `home_viewed`

`home_viewed` 必须包含 Analytics Spec 定义的 `home_primary_state`，其值等于本次实际渲染的 `homePrimaryState`。

点击 Start training 发送：

- `training_session_create_started`

创建失败发送：

- `training_session_create_failed`
- `api_error_received`

### 8.10 验收

- 有 active session 时不能出现 Start training。
- 无简历时不能出现 Start training。
- 无额度时 Start training 不应直接进入训练，应进入 Paywall。
- Home 刷新后必须反映服务端 active session，而不是本地推断。
- Home 必须先派生唯一 `homePrimaryState`，不得在 SwiftUI body 中用多个非互斥条件并列抢 primary CTA。
- `last_training_summary` 只能作为 supplemental card，不得成为 Home primary state。

---

## 9. IOS-SCR-02 Resume Upload

### 9.1 进入条件

- Home 无简历
- 简历不可训练
- 用户选择替换简历

### 9.2 数据与 API

- `POST /resumes`
- 成功后轮询 `GET /resumes/{resume_id}` 或刷新 `GET /home`

### 9.3 页面结构

1. Title：`Upload your resume`
2. Supported file hint：`PDF or DOCX, up to 5 MB`
3. Upload control
4. Privacy note：只说明会用于生成个性化训练，不写长篇政策
5. Primary CTA：`Choose file`
6. Pending 状态区域

### 9.4 文件选择前校验

| 条件 | 客户端行为 |
|---|---|
| 非 PDF / DOCX | 阻止上传，提示 `Choose a PDF or DOCX file.` |
| 大于 5 MB | 阻止上传，提示 `Choose a file under 5 MB.` |
| 用户取消 picker | 不报错，不发送 analytics |

### 9.5 上传成功后

成功返回 `resume_id` 后进入 Resume Status / Manage：

- 状态：`parsing`
- 文案：`Reading your resume`
- 开始轮询 resume status

### 9.6 上传失败

| 错误 | UX | 主操作 |
|---|---|---|
| `UNSUPPORTED_FILE_TYPE` | `This file type isn't supported.` | Choose another file |
| `RESUME_PARSE_FAILED` | `We couldn't read this resume.` | Upload another resume |
| 网络失败 | `Upload failed.` | Retry upload |

### 9.7 Analytics

- `resume_upload_started`
- `resume_upload_completed` 由 server 发送
- `resume_parse_failed` 由 server 发送
- `resume_profile_unusable` 由 server 发送
- `api_error_received`

### 9.8 验收

- 文件名不得进入 analytics。
- 上传 pending 时按钮禁用。
- Retry upload 复用同一个文件与 idempotency key。
- 用户选择新文件时生成新的 idempotency key。

---

## 10. IOS-SCR-03 Resume Status / Manage

### 10.1 进入条件

- 简历上传成功后
- Home 点击 View status
- Home 点击 Upload better resume
- Settings 点击 Manage resume

### 10.2 数据与 API

- `GET /resumes/{resume_id}`
- `GET /resumes/active`
- `DELETE /resumes/active`

### 10.3 状态映射

| Resume state | UI | 主操作 |
|---|---|---|
| `uploaded` / `parsing` | `Preparing your resume` | Refresh |
| `ready` + `usable` | 展示简历摘要和可训练信号 | Start training |
| `ready` + `limited` | 展示证据有限提示 | Start training / Upload better resume |
| `ready` + `unusable` | 展示不可训练原因 | Upload another resume |
| `failed` | 展示解析失败 | Upload another resume |
| `deleted` | 返回 Home | 无 |

### 10.4 可展示字段

可以展示：

- `candidate_summary`
- `recommended_anchor_experience_count`
- `top_strength_signals` 的 display label
- `insufficient_evidence_reasons` 的安全解释

不得展示：

- 原始简历全文
- `source_snippets`
- 内部 prompt 字段

### 10.5 删除简历入口

Delete resume 进入 IOS-SCR-15，并要求用户选择一种 delete mode：

- `resume_only_redacted_history`
- `resume_and_linked_training`

### 10.6 验收

- `profile_quality_status = unusable` 时不得允许 Start training。
- 删除失败不得清空本地 resume 状态。
- 删除成功后 Home 必须显示无 active resume。

---

## 11. IOS-SCR-04 Training Focus Picker

### 11.1 进入条件

- Home 点击 Start training
- 用户主动点击 Choose focus

### 11.2 类型

Sheet。

### 11.3 UI 内容

Title：`Choose a practice focus`

选项：

| Display label | API enum |
|---|---|
| Ownership | `ownership` |
| Prioritization | `prioritization` |
| Cross-functional Influence | `cross_functional_influence` |
| Conflict Handling | `conflict_handling` |
| Failure / Learning | `failure_learning` |
| Ambiguity | `ambiguity` |

Primary CTA：`Start training`

Secondary CTA：`Start without a focus`

### 11.4 行为

- 用户选择 focus 后发送 `training_focus_selected`。
- 点击 Start training 调用 `POST /training-sessions`。
- 请求体必须使用 canonical enum，不得使用 display label。
- 未选择 focus 时不传 `training_focus`。

### 11.5 创建 session 成功

push IOS-SCR-05：

- `session_id`
- 初始状态通常为 `question_generating`

### 11.6 创建 session 失败

| 错误 | UX | 主操作 |
|---|---|---|
| `ACTIVE_RESUME_REQUIRED` | `Upload a resume first.` | Upload resume |
| `RESUME_NOT_READY` | `Your resume is still being prepared.` | Refresh status |
| `RESUME_PROFILE_UNUSABLE` | `This resume needs more detail for practice.` | Upload another resume |
| `ACTIVE_SESSION_EXISTS` | `You already have a practice round in progress.` | Continue session |
| `INSUFFICIENT_SESSION_CREDITS` | 展示 Paywall | Buy Sprint Pack |

### 11.7 验收

- 创建训练 pending 时关闭 sheet 后不得丢 pending request。
- `ACTIVE_SESSION_EXISTS` 必须跳到已有 session，不得重复创建。
- `INSUFFICIENT_SESSION_CREDITS` 不创建本地 session。

---

## 12. IOS-SCR-05 Training Session Shell

### 12.1 进入条件

- 创建 session 成功
- Home 点击 Continue session
- History detail 打开某个 session

### 12.2 数据与 API

- `GET /training-sessions/{session_id}`

该接口是 question、follow-up、feedback、redo review 的唯一读取入口。

### 12.3 Shell 职责

Training Session Shell 不承载复杂 UI。它只负责：

- 拉取 session detail
- 根据 `training_session.status` 显示对应子状态
- 控制轮询
- 控制 abandon / back 行为
- 记录 question / feedback / redo review viewed 事件

### 12.4 状态到子屏映射

| Session status | 子屏 |
|---|---|
| `created` | Processing state |
| `question_generating` | Processing state |
| `waiting_first_answer` | IOS-SCR-06 |
| `first_answer_processing` | Processing state |
| `followup_generating` | Processing state |
| `waiting_followup_answer` | IOS-SCR-07 |
| `followup_answer_processing` | Processing state |
| `feedback_generating` | Processing state |
| `redo_available` | IOS-SCR-08 |
| `redo_processing` | Processing state |
| `redo_evaluating` | Processing state |
| `completed` | IOS-SCR-10 |
| `abandoned` | Expired state |
| `failed` | Failed state |

### 12.5 Processing state 文案

| Status | Title | Body |
|---|---|---|
| `created` | `Starting your practice round` | `We're setting up the session.` |
| `question_generating` | `Preparing your personalized question` | `We're using your resume to choose a relevant prompt.` |
| `first_answer_processing` | `Processing your answer` | `We're uploading and transcribing your response.` |
| `followup_generating` | `Preparing your follow-up` | `We're finding the most useful gap to probe.` |
| `followup_answer_processing` | `Processing your follow-up answer` | `We're checking the audio before feedback.` |
| `feedback_generating` | `Building your feedback` | `We're turning your answers into a focused redo plan.` |
| `redo_processing` | `Processing your redo` | `We're checking your second attempt.` |
| `redo_evaluating` | `Reviewing your redo` | `We're comparing it with your first answer.` |

### 12.6 轮询规则

- 前 20 秒：每 2 秒请求一次。
- 20 秒后：每 5 秒请求一次。
- 90 秒后：显示 `This is taking longer than usual. You can come back later.`
- 用户离开后停止前台轮询。
- 用户回到 Home 后，Home 通过 `active_session` 恢复入口。

### 12.7 Abandon 规则

仅 feedback 前允许 abandon：

- `created`
- `question_generating`
- `waiting_first_answer`
- `first_answer_processing`
- `followup_generating`
- `waiting_followup_answer`
- `followup_answer_processing`
- `feedback_generating`

调用：

- `POST /training-sessions/{session_id}/abandon`

`redo_available` 之后不显示 abandon，只允许 skip redo 或完成 redo。

### 12.8 验收

- 每个 `training_session.status` 都有落页。
- 读取训练详情只使用聚合接口。
- completed 后 Home 不再显示 active session。
- redo review unavailable 不能显示 failed screen。

---

## 13. IOS-SCR-06 First Answer

### 13.1 进入条件

`training_session.status = waiting_first_answer`

### 13.2 数据

来自 `GET /training-sessions/{session_id}`：

- `question.resume_anchor_hint`
- `question.question_text`
- `question.training_focus`

### 13.3 UI 内容

1. Progress label：`Question`
2. Resume anchor hint
3. Question text
4. Recording control
5. Timer
6. Secondary action：Back home

### 13.4 录音权限

首次录音前请求 microphone permission。

| 权限状态 | UX | 主操作 |
|---|---|---|
| 未请求 | `Allow microphone access to answer out loud.` | Continue |
| denied | `Microphone access is off.` | Open Settings |
| granted | 显示录音控制 | Start recording |

### 13.5 录音控制

推荐状态：

```text
idle -> recording -> review -> uploading -> processing
```

按钮：

- Start recording
- Stop
- Re-record
- Submit answer

### 13.6 提交 API

- `POST /training-sessions/{session_id}/first-answer`
- multipart：
  - `audio_file`
  - `duration_seconds`

### 13.7 转写质量失败

| `transcript_quality_status` | UX | 主操作 |
|---|---|---|
| `too_short` | `That answer was too short to review.` | Record again |
| `silent` | `We couldn't hear enough audio.` | Record again |
| `non_english` | `Please answer in English for this version.` | Record again |
| `low_confidence` | `The audio wasn't clear enough.` | Record again |
| `failed` | `Transcription failed.` | Record again |

失败后停留或回到 `waiting_first_answer`，不得进入 follow-up。

### 13.8 Analytics

- `question_viewed`
- `first_answer_recording_started`
- `first_answer_submitted` 由 server 发送
- `first_answer_transcription_failed` 由 server 发送

### 13.9 验收

- 问题实际可见时才发送 `question_viewed`。
- 录音上传失败 retry 复用同一音频和 idempotency key。
- 用户重新录音后使用新的 idempotency key。

---

## 14. IOS-SCR-07 Follow-up Answer

### 14.1 进入条件

`training_session.status = waiting_followup_answer`

### 14.2 数据

来自 `GET /training-sessions/{session_id}`：

- `question.question_text`
- `follow_up.follow_up_text`
- `follow_up.target_gap`

### 14.3 UI 内容

1. Progress label：`Follow-up`
2. Original question collapsed summary
3. Follow-up question
4. Recording control
5. Timer
6. Secondary action：Back home

### 14.4 提交 API

- `POST /training-sessions/{session_id}/follow-up-answer`
- multipart：
  - `audio_file`
  - `duration_seconds`

### 14.5 失败处理

转写质量失败时回到 `waiting_followup_answer`，不得进入 feedback generation。

文案同 First Answer，但上下文改成 follow-up answer。

### 14.6 Analytics

- `follow_up_viewed`
- `follow_up_answer_recording_started`
- `follow_up_answer_submitted` 由 server 发送
- `follow_up_answer_transcription_failed` 由 server 发送

### 14.7 验收

- 追问一次只展示一个问题。
- 不提供自由聊天输入。
- 转写不可用时不 consume credit。

---

## 15. IOS-SCR-08 Feedback / Redo Decision

### 15.1 进入条件

`training_session.status = redo_available`

### 15.2 数据

来自 `GET /training-sessions/{session_id}`：

- `feedback.visible_assessments`
- `feedback.strongest_signal`
- `feedback.biggest_gap`
- `feedback.why_it_matters`
- `feedback.redo_priority`
- `feedback.redo_outline`
- `usage_balance`

### 15.3 页面结构

推荐展示顺序：

1. `biggest_gap`
2. `why_it_matters`
3. `redo_priority`
4. `redo_outline`
5. `strongest_signal`
6. 5 项 visible assessments
7. Primary CTA：`Redo this answer`
8. Secondary CTA：`Skip redo`

### 15.4 Visible assessment 展示

| Field | Display label |
|---|---|
| `answered_the_question` | Answered the question |
| `story_fit` | Story fit |
| `personal_ownership` | Personal ownership |
| `evidence_and_outcome` | Evidence and outcome |
| `holds_up_under_follow_up` | Holds up under follow-up |

状态值只展示：

- Strong
- Mixed
- Weak

不得展示总分，不展示内部 10 维评分。

### 15.5 Redo 行为

点击 `Redo this answer`：

- 进入 IOS-SCR-09
- 开始 redo recording 时发送 `redo_started`

点击 `Skip redo`：

- 调用 `POST /training-sessions/{session_id}/skip-redo`
- 成功后进入 IOS-SCR-10

### 15.6 Analytics

- `feedback_viewed`
- `redo_skipped` 由 server 发送

### 15.7 验收

- feedback 实际可见时才发送 `feedback_viewed`。
- `redo_available` 后 credit 已 consumed，不显示“尚未扣费”暗示。
- skip redo 成功后 session 进入 completed。

---

## 16. IOS-SCR-09 Redo Answer

### 16.1 进入条件

- 用户在 IOS-SCR-08 点击 `Redo this answer`
- session 仍为 `redo_available`

### 16.2 UI 内容

1. Title：`Redo your answer`
2. Redo priority
3. Redo outline
4. Original question
5. Recording control
6. Submit redo

### 16.3 提交 API

- `POST /training-sessions/{session_id}/redo`
- multipart：
  - `audio_file`
  - `duration_seconds`

### 16.4 成功路径

1. 提交成功后进入 `redo_processing`。
2. Shell 轮询 session。
3. 转写可用后进入 `redo_evaluating`。
4. 成功生成 redo review 后进入 `completed` + `redo_review_generated`。
5. redo review 不可用时进入 `completed` + `redo_review_unavailable`。

### 16.5 转写失败

redo 转写失败或质量不足时回到 `redo_available`，允许重新录 redo。

| 状态 | UX |
|---|---|
| `too_short` | `That redo was too short to review.` |
| `silent` | `We couldn't hear enough audio.` |
| `non_english` | `Please answer in English for this version.` |
| `low_confidence` | `The audio wasn't clear enough.` |
| `failed` | `Transcription failed.` |

### 16.6 Analytics

- `redo_started`
- `redo_submitted` 由 server 发送
- `redo_transcription_failed` 由 server 发送
- `redo_review_generated` 由 server 发送

### 16.7 验收

- redo 不生成第二轮 follow-up。
- redo 不额外扣费。
- redo review 失败不能进入 failed screen。

---

## 17. IOS-SCR-10 Completed Result

### 17.1 进入条件

`training_session.status = completed`

### 17.2 分流规则

| `completion_reason` | 展示内容 | 主操作 |
|---|---|---|
| `redo_skipped` | 原 feedback | Back home / Start next |
| `redo_review_generated` | 原 feedback + redo review | Back home / Start next |
| `redo_review_unavailable` | 原 feedback + 轻提示 | Back home / Start next |

### 17.3 Redo review generated 展示

如果 `redo_review` 非空，展示：

- Improvement status
- What improved
- Still missing
- Next attempt guidance

不得展示：

- 第二套完整 feedback
- 新追问
- 内部评分

### 17.4 Redo review unavailable

显示轻提示：

`Redo review is temporarily unavailable. Your original feedback is saved, and this practice round is complete.`

必须同时满足：

- 原 feedback 继续可见。
- session 不再 active。
- 用户可以 Start next。
- 不退款、不额外扣费。

### 17.5 主操作

Back home：

- pop to Home
- refresh `GET /home`

Start next：

- pop to Home
- 若有 credit 且 active resume ready，打开 IOS-SCR-04
- 若无 credit，打开 Paywall

### 17.6 Analytics

- `redo_review_viewed`，仅 redo review 实际可见时发送
- `training_session_completed` 由 server 发送

### 17.7 验收

- `completion_reason = redo_review_unavailable` 时不发送 `redo_review_viewed`。
- completed 后 Home 不显示 Continue session。
- Start next 不复用上一轮 idempotency key。

---

## 18. IOS-SCR-11 History List

### 18.1 进入条件

- 用户从 Home 点击 View all history
- 用户从 completed result 或历史详情回到历史列表

### 18.2 数据与 API

- `GET /training-sessions/history?limit=10`

### 18.3 页面结构

1. Title：`History`
2. Empty state
3. List of recent training summaries

### 18.4 List item 内容

每条展示：

- Question text，最多 2 行
- Training focus display label
- Completion date
- Redo status
- Final visible assessment summary

不要展示：

- 完整回答文本
- 完整 feedback 文本
- 音频入口

### 18.5 Empty state

- Title：`No practice history yet`
- Body：`Complete a practice round to see it here.`
- CTA：`Start training`，先返回 Home，再按当前 `homePrimaryState` 打开 focus sheet 或 Paywall

### 18.6 行为

点击 item：

- push IOS-SCR-12 with `session_id`

### 18.7 验收

- 删除单次训练成功后从列表移除。
- 本地缓存只保留摘要，不保留完整内容。

---

## 19. IOS-SCR-12 History Detail

### 19.1 进入条件

- History list item 点击
- Home last training summary 点击

### 19.2 数据与 API

- `GET /training-sessions/{session_id}`

### 19.3 页面内容

1. Question
2. Follow-up
3. Feedback
4. Redo review，如果存在
5. Completion reason 提示，如果需要
6. Delete training entry

### 19.4 状态规则

| Session status | 行为 |
|---|---|
| `completed` | 展示历史详情 |
| `abandoned` | 展示 session expired 简短状态 |
| `failed` | 展示未完成状态 |
| active status | 跳转 IOS-SCR-05，而不是按历史展示 |

### 19.5 删除单次训练

点击 Delete：

- 打开 IOS-SCR-15
- 确认后调用 `DELETE /training-sessions/{session_id}`
- 成功后返回 History

### 19.6 验收

- 历史详情不显示重新编辑或重新提交入口。
- redo review unavailable 时展示原 feedback 与轻提示。
- 删除失败保留当前详情。

---

## 20. IOS-SCR-13 Paywall / Billing

### 20.1 进入条件

- 创建训练返回 `INSUFFICIENT_SESSION_CREDITS`
- Home 无额度
- 用户从 Settings 或 Home 手动打开购买入口

### 20.2 数据与 API

- `GET /billing/entitlement`
- StoreKit 2 purchase
- `POST /billing/apple/verify`
- `POST /billing/apple/restore`

### 20.3 UI 内容

1. Title：`Continue personalized practice`
2. Credit summary：可用训练次数
3. Product：Sprint Pack
4. Primary CTA：`Buy Sprint Pack`
5. Secondary CTA：`Restore purchase`
6. Close

不展示复杂订阅对比，因为 v1 不做订阅。

### 20.4 购买流程

1. 获取 entitlement。
2. 点击 Buy 发送 `purchase_started`。
3. 调用 StoreKit 2，传入 `app_account_token`。
4. StoreKit 成功后调用 verify。
5. verify 成功后刷新 entitlement 和 Home。
6. 关闭 Paywall 或显示 Start training。

### 20.5 错误处理

| 错误 | UX | 主操作 |
|---|---|---|
| StoreKit cancel | `Purchase canceled.` | Close |
| StoreKit failure | `Purchase failed.` | Try again |
| verify 网络失败 | `We need to verify your purchase.` | Retry verification |
| `APPLE_PURCHASE_VERIFICATION_FAILED` | `Purchase verification failed.` | Retry verification |
| `APPLE_TRANSACTION_ALREADY_PROCESSED` | `Purchase already processed.` | Refresh credits |
| `APP_ACCOUNT_TOKEN_MISMATCH` | `This purchase doesn't match this app profile.` | Restore purchase |

### 20.6 Analytics

- `paywall_viewed`
- `purchase_started`
- `purchase_verified` 由 server 发送
- `purchase_failed`
- `purchase_restored` 由 server 发送

### 20.7 验收

- StoreKit pending 时 Buy 按钮禁用。
- verify 失败不得显示购买成功。
- verify retry 复用同一 transaction payload 与 idempotency key。
- analytics 不发送 transaction id、signed payload 或 `app_account_token`。

---

## 21. IOS-SCR-14 Settings / Data

### 21.1 进入条件

- 用户从 Home 点击 Settings icon
- 用户从 Privacy Notice 点击 Manage data

### 21.2 页面结构

1. Practice data
2. Resume management
3. Purchase restore
4. Privacy and deletion
5. App version

### 21.3 操作

| Item | 行为 |
|---|---|
| Manage resume | push IOS-SCR-03 |
| Restore purchase | present IOS-SCR-13 或直接 restore |
| Delete all data | present IOS-SCR-15 |
| Privacy | push IOS-SCR-17 |

### 21.4 Delete all data

调用：

- `DELETE /app-users/me/data`

成功后：

- 清空 token、Home cache、resume cache、history cache、active session id、analytics queue、pending idempotency records。
- 回到 IOS-SCR-00。

失败后：

- 不清空本地状态。
- 展示 Retry deletion。
- 保留 `request_id` 用于支持。

### 21.5 验收

- Settings 不提供登录、注册、账号绑定入口。
- 删除全部数据成功后不得继续发送旧 `app_user_id` 事件。

---

## 22. IOS-SCR-15 Delete Confirmation

### 22.1 类型

使用 confirmation dialog 或 sheet。删除简历因为有 delete mode，推荐 sheet。

### 22.2 删除简历

Title：`Delete resume`

必须说明：

- 原始简历会删除。
- 训练历史可能按选择被脱敏保留或一起删除。
- purchase / credit ledger 审计记录不会作为用户可见训练内容展示。

选项：

| Label | API value |
|---|---|
| Delete resume only | `resume_only_redacted_history` |
| Delete resume and linked training | `resume_and_linked_training` |

### 22.3 Cancel parsing resume

Home 在 `homePrimaryState = resumeProcessing` 时展示 `Cancel resume`。该 CTA 不是普通关闭按钮，必须走删除确认。

确认标题：

`Cancel resume processing?`

说明：

- `This stops using the current resume for practice.`
- `You can upload another resume afterward.`
- 如果服务端已经从该文件派生出部分简历数据，也必须一起清理。

确认后调用：

- `DELETE /resumes/active`
- request body 使用 `delete_mode = resume_only_redacted_history`

成功后：

- dismiss confirmation
- 返回 Home
- 刷新 `GET /home`
- Home 应进入 `noResume`，除非服务端返回新的 active resume 状态

失败后：

- 保留当前 parsing 状态
- 展示 Retry deletion
- 发送 `api_error_received`

### 22.4 删除单次训练

Title：`Delete this practice round?`

说明：

- `This removes the visible practice content and related audio.`
- `Purchase and credit records are not removed.`

API：

- `DELETE /training-sessions/{session_id}`

### 22.5 删除全部数据

Title：`Delete all app data?`

说明：

- `This deletes your resume, audio, transcripts, feedback, and history.`
- `Your local app profile will be reset.`

API：

- `DELETE /app-users/me/data`

### 22.6 Analytics

删除成功事件由 server 发送：

- `resume_delete_completed`
- `training_session_delete_completed`
- `user_data_delete_completed`

失败时 client 发送：

- `api_error_received`

### 22.7 验收

- 删除失败不能显示成功状态。
- 删除 pending 时确认按钮禁用。
- 删除全部数据成功后必须回到 Launch。
- Cancel resume 必须等价于确认后的 `DELETE /resumes/active`，不得只在本地隐藏 parsing resume。

---

## 23. IOS-SCR-16 Offline / Fatal Recovery

### 23.1 离线有缓存

展示只读 Home 或 session snapshot：

- Title：`You're offline`
- Body：`You can view the latest saved state, but new actions need a connection.`
- CTA：`Retry`

禁用：

- Upload
- Start training
- Submit answer
- Purchase
- Delete

### 23.2 离线无缓存

展示阻断页：

- Title：`You're offline`
- CTA：`Retry`

### 23.3 Fatal blocked

进入条件：

- bootstrap 连续失败
- 数据删除后 token 已撤销但新 bootstrap 失败

UX：

- Title：`We couldn't prepare the app`
- CTA：`Retry app setup`

### 23.4 验收

- 离线状态不得允许写请求排队后自动无提示发送。
- 网络恢复后用户主动 retry 或 app foreground 刷新。

---

## 24. IOS-SCR-17 Privacy Notice

### 24.1 进入条件

- Home 无简历时点击 Privacy
- Settings 点击 Privacy
- Resume Upload 页面点击隐私说明链接，如果实现为可点击入口

### 24.2 类型

Push screen。

### 24.3 UI 内容

该页面是首版 in-app privacy notice，不替代正式法律隐私政策。内容必须短、明确、可执行。

推荐段落：

1. `What we use`
   - resume file
   - practice audio
   - transcripts
   - AI feedback
   - purchase entitlement status
2. `Why we use it`
   - generate resume-based behavioral interview questions
   - transcribe spoken answers
   - provide feedback and redo review
   - manage credits and purchase restore
3. `What we do not do in v1`
   - no public profile
   - no resume rewriting product
   - no required account signup before practice
4. `Your controls`
   - delete active resume
   - delete a practice round
   - delete all app data

### 24.4 操作

| CTA | 行为 |
|---|---|
| Manage data | push IOS-SCR-14 |
| Back | pop to source |

### 24.5 验收

- Privacy Notice 必须有 route：`AppRoute.privacyNotice`。
- Home 的 Privacy CTA 和 Settings 的 Privacy item 都必须落到该 screen。
- Privacy Notice 的 Manage data 必须 push IOS-SCR-14，不得依赖底部导航选择状态。
- 页面不得展示原始简历、转写、feedback 或任何用户敏感内容。

---

## 25. 跨屏 API 行为矩阵

| 用户动作 | API | 成功后 | 失败后 |
|---|---|---|---|
| App 启动 | `POST /app-users/bootstrap` | `GET /home` | Launch error |
| Home 刷新 | `GET /home` | 渲染 Home | cache fallback / error |
| 查看隐私说明 | 无 | Privacy Notice | 无 |
| 上传简历 | `POST /resumes` | Resume status | Upload error |
| 查询简历 | `GET /resumes/{resume_id}` | Resume status | Resume error |
| 创建训练 | `POST /training-sessions` | Training shell | Existing session / Paywall / error |
| 查询训练 | `GET /training-sessions/{session_id}` | 对应 session state | Training error |
| 提交首轮回答 | `POST /training-sessions/{session_id}/first-answer` | processing | Re-record / retry |
| 提交追问回答 | `POST /training-sessions/{session_id}/follow-up-answer` | processing | Re-record / retry |
| Skip redo | `POST /training-sessions/{session_id}/skip-redo` | completed | Retry |
| 提交 redo | `POST /training-sessions/{session_id}/redo` | processing | Re-record / retry |
| 放弃训练 | `POST /training-sessions/{session_id}/abandon` | Home | Retry |
| 历史列表 | `GET /training-sessions/history?limit=10` | History list | Empty/error |
| 删除训练 | `DELETE /training-sessions/{session_id}` | History | Retry deletion |
| 获取商品 | `GET /billing/entitlement` | Paywall | Billing error |
| 校验购买 | `POST /billing/apple/verify` | Refresh credits | Retry verification |
| Restore | `POST /billing/apple/restore` | Refresh credits | Retry restore |
| 删除简历 / Cancel resume | `DELETE /resumes/active` | Home | Retry deletion |
| 删除全部数据 | `DELETE /app-users/me/data` | Launch | Retry deletion |

---

## 26. 跨屏 Analytics 映射

| Screen | Client event |
|---|---|
| Launch | `app_bootstrap_started`, `app_bootstrap_completed`, `app_bootstrap_failed` |
| Home | `home_viewed`, `training_session_create_started`, `training_session_create_failed` |
| Resume Upload | `resume_upload_started` |
| Training Focus | `training_focus_selected` |
| First Answer | `question_viewed`, `first_answer_recording_started` |
| Follow-up Answer | `follow_up_viewed`, `follow_up_answer_recording_started` |
| Feedback | `feedback_viewed` |
| Redo | `redo_started` |
| Completed Result | `redo_review_viewed`，仅 redo review 实际可见时 |
| Paywall | `paywall_viewed`, `purchase_started`, `purchase_failed` |
| Any API error | `api_error_received` |

Server-owned events 不由 iOS 伪造，包括：

- `training_session_created`
- `first_answer_submitted`
- `follow_up_answer_submitted`
- `feedback_generated`
- `redo_submitted`
- `redo_skipped`
- `redo_review_generated`
- `training_session_completed`
- `purchase_verified`
- deletion completed events

---

## 27. SwiftUI 组件建议

### 27.1 Root

- `AppRootView`
- `LaunchGateView`
- `HomeNavigationStack`
- `HomeView`
- `HistoryListView`
- `SettingsView`

### 27.2 Shared components

| Component | 用途 |
|---|---|
| `PrimaryActionButton` | 主 CTA，支持 loading / disabled |
| `SecondaryActionButton` | 次 CTA |
| `StatusBanner` | 错误、离线、processing 提示 |
| `CreditSummaryView` | 训练次数摘要 |
| `ResumeStatusView` | 简历状态 |
| `TrainingFocusPickerView` | focus sheet |
| `RecordingControlView` | 录音状态机 |
| `AssessmentBadgeView` | Strong / Mixed / Weak |
| `FeedbackSectionView` | feedback 段落 |
| `ProcessingStateView` | 明确任务名的 loading |
| `DeleteConfirmationView` | 删除确认 |
| `PrivacyNoticeView` | 首版数据使用与删除说明 |

### 27.3 State ownership

推荐：

- Root-owned `AppSessionStore`：token、app user、bootstrap 状态、Home cache。
- Feature-owned `HomeModel`：Home 加载、刷新、创建 session。
- Feature-owned `TrainingSessionModel`：session detail、polling、提交回答。
- Feature-owned `BillingModel`：entitlement、StoreKit、verify、restore。
- Local `@State`：当前录音 UI、sheet selection、form loading。

不得：

- 在 SwiftUI `body` 内直接触发网络请求。
- 将完整 API response 放入全局 mutable singleton。
- 让 View 直接拼接 multipart 或 Apple verify payload。

---

## 28. 最小 Preview / Fixture 要求

每个主 screen 至少提供以下 preview fixture：

| Screen | Required previews |
|---|---|
| Home | no resume, ready, active session, out of credits, resume unusable |
| Resume Upload | idle, uploading, parse failed |
| Training Session | question generating, waiting first answer, follow-up, feedback, redo processing, completed |
| Feedback | strong/mixed/weak 混合状态 |
| Paywall | entitlement loaded, verifying, verify failed |
| History | empty, list with redo review, list with redo skipped |
| Settings | normal, deletion pending |
| Privacy Notice | default content, manage data route |

Preview 使用 mock service，不访问真实网络。

---

## 29. 最小验收标准

iOS Client Screen Spec v1 满足以下条件才算完成：

1. App 启动后能通过 Launch / Bootstrap 进入 Home。
2. Home 必须通过固定优先级派生唯一 `homePrimaryState`，再渲染唯一 primary CTA。
3. Resume Upload 能处理文件类型、大小、上传、解析、不可训练和删除。
4. Start training 必须经过 canonical training focus 处理，创建 session 使用稳定 idempotency key。
5. Training Session 只通过 `GET /training-sessions/{session_id}` 渲染状态。
6. 每个 `training_session.status` 都有明确 UI 落点。
7. First Answer、Follow-up Answer、Redo 都有录音、提交、重录和转写质量失败状态。
8. Feedback 页面展示 5 段固定反馈和 5 项 visible assessment，不展示总分。
9. Redo review unavailable 显示为 completed 的轻提示，不显示 failed。
10. Paywall 使用 StoreKit 2 + server verify，不在 verify 失败时显示购买成功。
11. History 只缓存摘要，详情重新拉取 session detail。
12. Settings 能删除简历、单次训练、全部数据，删除失败不显示成功。
13. 删除全部数据成功后清空本地状态并回到 Launch。
14. 所有 client-owned analytics 只在用户实际看到或点击后发送。
15. 所有 server-owned analytics 不由 iOS 客户端伪造。
16. 所有 API envelope error 都有对应屏幕行为和 `api_error_received`。
17. 离线状态下不允许上传、提交、购买或删除。
18. 关键 screens 有 preview fixtures。
19. `last_training_summary` 只能作为 Home supplemental card，不得改变 primary CTA。
20. 所有 CTA 必须在第 6.5 节有 route / sheet / API / analytics 映射。
21. Home 的 `Cancel resume` 必须走删除确认，并在确认后调用 `DELETE /resumes/active`。
22. Home 和 Settings 的 Privacy 入口必须落到 IOS-SCR-17，不得悬空或仅保留文案。

---

## 30. 一句话收束

iOS Client Screen Spec v1 的目标，是让首版 iOS 客户端围绕 Home、一次完整训练闭环、Paywall、History 和 Data Settings 五个核心区域落地，严格服从服务端状态机和 API envelope，让用户在任何时候都能看到一个明确、可执行、不会误扣费或误删数据的下一步。
