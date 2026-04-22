# AI Behavioral Interview Coach Client UX State & Error Handling Spec v1

## 1. 文档信息

- 文档名称：Client UX State & Error Handling Spec
- 版本：v1
- 日期：2026-04-21
- 适用产品版本：AI Behavioral Interview Coach v1
- 主要读者：iOS 客户端、后端、QA、产品设计
- 上游依据：
  - `docs/ios/AI_Behavioral_Interview_Coach_PRD_v1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_Data_API_Spec_v1.1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_Prompt_Content_Spec_v1.1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_iOS_Client_Screen_Spec_v1.md`
  - `docs/design/AI_Behavioral_Interview_Coach_iOS_UI_Design_Spec_v1.md`

---

## 2. 本文档解决什么问题

本文档把 PRD、Data / API 和 Prompt / Content 的产品闭环落到客户端可执行状态：

1. 每个 API / session / resume 状态下，用户应该看到什么。
2. 每个错误码下，客户端应该展示什么操作。
3. 哪些状态可以重试、重录、恢复、放弃或重新开始。
4. 写请求如何使用 `Idempotency-Key`，避免移动端重试导致重复创建、重复扣费或重复提交。
5. 训练过程如何通过 `GET /training-sessions/{session_id}` 聚合接口恢复。
6. 删除简历、删除训练、删除全部数据时，客户端如何解释保留和删除范围。

本文档不定义视觉样式、具体组件尺寸、动画、埋点事件、App Store 商品定价或完整 Privacy Policy 文案。具体页面、路由和 CTA 落点以 iOS Client Screen Spec 为准；视觉布局以 iOS UI Design / Wireframe Spec 为准。

---

## 3. UX 状态设计原则

### 3.1 API 状态是唯一业务事实来源

客户端不得自行推导训练是否完成、credit 是否消耗、redo 是否可用。以下字段是客户端状态渲染的事实来源：

- `resume.status`
- `resume.profile_quality_status`
- `training_session.status`
- `credit_state`
- `usage_balance`
- `active_resume`
- `active_session`
- `redo_submitted`
- `completion_reason`
- `redo_review_failure_code`
- API envelope 中的 `error.code`

### 3.2 所有 API response 必须按 envelope 处理

客户端统一按以下规则处理响应：

- `error = null` 且 `data != null`：按 `data` 渲染业务状态。
- `error != null`：不得使用 `data` 渲染业务状态，必须进入错误处理路径。
- `request_id` 必须写入本地诊断日志；普通用户界面不默认展示，只有在支持或重试失败时展示。

### 3.3 训练读取只用聚合接口

客户端读取训练内容时只调用：

```text
GET /training-sessions/{session_id}
```

客户端不得依赖以下专项读接口，因为 v1.1 已明确不提供：

- `GET /training-sessions/{session_id}/follow-up`
- `GET /training-sessions/{session_id}/feedback`
- `GET /training-sessions/{session_id}/redo-review`

### 3.4 写请求必须稳定幂等

所有写接口必须带 `Idempotency-Key`。同一次用户意图的自动重试必须复用同一个 key。

用户意图包括：

- 上传同一份简历
- 创建一次训练
- 提交同一段首轮回答音频
- 提交同一段追问回答音频
- 提交同一段 redo 音频
- 跳过 redo
- 放弃训练
- 校验同一笔 Apple IAP 交易
- restore Apple IAP
- 删除简历、单次训练或全部数据

只有当用户重新选择文件、重新录音、重新购买、重新发起删除确认时，客户端才生成新的 `Idempotency-Key`。

### 3.5 失败提示必须可操作

错误提示必须告诉用户下一步能做什么，而不是暴露内部实现。

推荐优先级：

1. 可重试：展示 Retry。
2. 可重录：展示 Record again。
3. 可重新上传：展示 Upload another resume。
4. 可恢复会话：展示 Continue session。
5. 额度不足：展示购买入口。
6. 数据删除失败：展示 Retry deletion，并保留 `request_id` 供支持排查。

### 3.6 不把 AI 失败包装成用户错误

`AI_GENERATION_FAILED`、`AI_OUTPUT_VALIDATION_FAILED` 属于系统失败。客户端不得提示用户“回答不合格”或“你做错了”。只有 `TRANSCRIPT_QUALITY_TOO_LOW` 和 `TRANSCRIPTION_FAILED` 才要求用户重录。

---

## 4. 客户端主要界面状态

v1 客户端至少包含以下状态承载界面：

| Surface | 责任 |
|---|---|
| Launch / Bootstrap | 创建或恢复匿名身份，获取 token |
| Home | 聚合展示简历、active session、余额和最近训练 |
| Resume Upload | 选择文件、上传、解析、不可训练处理 |
| Training Session | 问题、录音、追问、processing、feedback、redo |
| Feedback / Redo | 展示结构化反馈、提交 redo 或跳过 |
| History | 最近训练摘要与历史详情入口 |
| Paywall / Billing | 展示额度、购买 Sprint Pack、restore |
| Settings / Data | 删除简历、删除单次训练、删除全部数据 |

这些 surface 可以映射成多个 iOS screen，但业务状态必须按本文档处理。

---

## 5. 全局客户端运行状态

| Client state | 进入条件 | 用户看到 | 允许操作 | 下一步 |
|---|---|---|---|---|
| `bootstrapping` | App 首次启动或本地无有效 token | 初始化加载状态 | 无 | `POST /app-users/bootstrap` |
| `authenticated_ready` | bootstrap 成功或 token 有效 | Home | 上传简历、继续训练、购买、历史、设置 | `GET /home` |
| `offline_with_cache` | 网络不可用且本地有上次成功状态 | 只读 Home 或训练快照，并提示离线 | 重试连接；不可提交写操作 | 网络恢复后刷新 |
| `offline_no_cache` | 网络不可用且无可用缓存 | 离线错误页 | Retry | bootstrap 或刷新 Home |
| `token_refreshing` | 任意 API 返回 `UNAUTHORIZED` | 保持当前界面，显示轻量恢复状态 | 无 | 重新 bootstrap 后重试原请求一次 |
| `fatal_blocked` | bootstrap 连续失败或数据删除后 token 已撤销 | 阻断错误页 | Retry app setup | 重新 bootstrap |

客户端必须缓存以下最小恢复信息：

- `app_user_id`
- `access_token` 与过期时间
- `app_account_token`
- 最近一次成功的 `home` response
- 当前 `active_session.session_id`
- 未完成写请求的 `Idempotency-Key`、endpoint、payload fingerprint

---

## 6. Bootstrap 与身份恢复

### 6.1 首次启动

流程：

1. 客户端生成并保存稳定 `installation_id`。
2. 调用 `POST /app-users/bootstrap`，带 `Idempotency-Key`。
3. 成功后保存 `access_token`、`expires_at`、`app_account_token`。
4. 立即调用 `GET /home` 渲染首页。

用户体验：

- 加载文案应表达“正在准备训练环境”，不得提到账号系统或匿名用户实现。
- bootstrap 成功前不得展示上传、训练或购买入口。

### 6.2 Token 过期或无效

当任意非 bootstrap API 返回 `UNAUTHORIZED`：

1. 客户端进入 `token_refreshing`。
2. 调用 `POST /app-users/bootstrap` 恢复身份。
3. bootstrap 成功后，自动重试原请求一次。
4. 如果原请求是写请求，必须复用原 `Idempotency-Key`。
5. 如果重试仍失败，按对应错误码处理。

### 6.3 删除全部数据后的身份

`DELETE /app-users/me/data` 成功后：

- 客户端必须清空本地 token、session id、resume cache、history cache、pending idempotency records。
- 返回 Launch 状态。
- 下一次使用需要重新 bootstrap，得到新的匿名用户上下文。

---

## 7. Home 状态

Home 只根据 `GET /home` 的 `data` 渲染。Home 的 primary action 必须先派生唯一 `homePrimaryState`，再渲染 UI；不得在 SwiftUI View 中用多个非互斥 `if` 并列抢 primary CTA。

Home priority 以 iOS Client Screen Spec 第 8.4 节为准。Client UX 层同步定义如下：

| Priority | 条件 | `homePrimaryState` | 主操作 | 次操作 |
|---:|---|---|---|---|
| 1 | `active_session != null` | `activeSession` | Continue session | 无 |
| 2 | `active_resume = null` | `noResume` | Upload resume | Privacy |
| 3 | `active_resume.status = uploaded / parsing` | `resumeProcessing` | View status | Cancel resume |
| 4 | `active_resume.status = failed` | `resumeFailed` | Upload another resume | View reason |
| 5 | `active_resume.profile_quality_status = unusable` | `resumeUnusable` | Upload another resume | View reason |
| 6 | `active_resume.status = ready` 且 `profile_quality_status = usable / limited` 且 `available_session_credits = 0` | `outOfCredits` | Buy Sprint Pack | Restore purchase |
| 7 | `active_resume.status = ready` 且 `profile_quality_status = limited` | `readyLimited` | Start training | Upload better resume |
| 8 | `active_resume.status = ready` | `ready` | Start training | Choose focus |

规则：

- Home 不展示复杂数据面板。
- 有 active session 时，Start training 按钮必须被 Continue session 替代。
- 客户端不得因为本地认为 session 结束而隐藏 active session，必须以 `GET /home` 为准。
- `last_training_summary` 只能作为 supplemental card，不得成为 primary state。
- parsing + last summary 时 primary 仍为 View status；ready + last summary 时 primary 仍为 Start training。
- 无额度只在“有可训练或有限可训练简历，且没有 active session”时成为 primary state。

---

## 8. 简历上传、解析与删除

### 8.1 文件选择前校验

客户端必须在上传前做本地校验：

| 条件 | 客户端行为 |
|---|---|
| 文件类型不是 PDF / DOCX | 阻止上传，提示仅支持 PDF 或 DOCX |
| 文件大于 5 MB | 阻止上传，提示文件过大 |
| 用户取消选择 | 返回原界面，不显示错误 |

页数超过 5 页不阻止上传；服务端可将结果标记为 `profile_quality_status = limited`。

### 8.2 上传中

状态：

- Surface：Resume Upload
- API：`POST /resumes`
- UI：上传进度、不可重复点击提交
- 自动重试：仅网络中断或超时可重试一次，复用同一 `Idempotency-Key`
- 用户取消：只取消本地上传；如果服务端已接受请求，后续以 `GET /resumes/{resume_id}` 状态为准

### 8.3 解析中

当 `POST /resumes` 返回 `status = parsing`：

- 客户端进入解析中状态。
- 轮询 `GET /resumes/{resume_id}`。
- 推荐轮询节奏：前 20 秒每 2 秒一次，之后每 5 秒一次。
- 90 秒仍未完成时，显示“仍在解析，可稍后回来”，但继续允许用户留在页面。
- 用户离开后，Home 必须能显示 active resume parsing 状态。

### 8.4 解析成功

| 服务端状态 | UX |
|---|---|
| `status = ready` 且 `profile_quality_status = usable` | 显示简历已准备好，主操作 Start training |
| `status = ready` 且 `profile_quality_status = limited` | 允许 Start training，同时提示简历证据有限，建议上传更完整简历 |
| `status = ready` 且 `profile_quality_status = unusable` | 阻止训练，主操作 Upload another resume |

### 8.5 解析失败

| 错误码 | UX | 主操作 |
|---|---|---|
| `RESUME_PARSE_FAILED` | 无法读取简历文本 | Upload another resume |
| `RESUME_PROFILE_UNUSABLE` | 简历缺少可训练经历 | Upload more detailed resume |
| `UNSUPPORTED_FILE_TYPE` | 文件类型不支持 | Choose another file |

客户端不得在解析失败后生成通用题目绕过简历前置条件。

### 8.6 删除活跃简历

`DELETE /resumes/active` 必须提供两个明确选项：

| UI option | API `delete_mode` | 用户解释 |
|---|---|---|
| Delete resume only | `resume_only_redacted_history` | 删除原始简历和简历解析内容，保留已脱敏历史摘要 |
| Delete resume and linked training | `resume_and_linked_training` | 删除简历以及由该简历产生的训练内容、音频和 AI payload |

确认弹窗必须说明：

- 删除后不能用该简历开始新训练。
- `resume_only_redacted_history` 会保留脱敏历史摘要。
- purchase / ledger 审计记录不会被删除。

成功后：

- 清空 Home 中的 active resume。
- 如果有依赖该简历的 active session，必须刷新 Home，以服务端返回为准。

失败时：

- 不得显示删除成功。
- 展示 Retry deletion。
- 记录 `request_id`。

---

## 9. 创建训练与 active session

### 9.1 Start training

用户点击 Start training 时：

1. 客户端提交 `POST /training-sessions`。
2. 请求体使用 canonical `training_focus` enum。
3. 写入稳定 `Idempotency-Key`。
4. 成功后进入 `question_generating` 状态。

如果用户没有选择训练重心，客户端可以传 `null` 或不传，由服务端 / Prompt 链路选择；如果传值，必须使用 PRD 中定义的 canonical enum。

### 9.2 Active session exists

当创建训练返回 `ACTIVE_SESSION_EXISTS`：

- 客户端不得再次创建新 session。
- 必须展示 Continue existing session。
- 如果 error details 返回 `session_id`，直接跳转 `GET /training-sessions/{session_id}`。
- 如果未返回 `session_id`，先刷新 `GET /home`。

### 9.3 Credit reservation

创建 session 成功后，credit 进入 reserved 状态。客户端必须展示“本次训练已开始”的状态，但不得说 credit 已消耗。

credit 消耗口径：

- feedback 成功生成并进入 `redo_available` 后才算 consumed。
- feedback 前系统失败或 TTL 放弃时，reserved credit 会 release。
- feedback 后跳过 redo 或 redo review 失败，不退款、不 release、不额外扣费。

---

## 10. 训练会话状态

客户端统一通过 `GET /training-sessions/{session_id}` 渲染训练状态。

| `training_session.status` | 用户看到 | 主操作 | 轮询 | 允许离开 |
|---|---|---|---|---|
| `created` | 正在创建训练 | 无 | 是 | 是 |
| `question_generating` | 正在准备个性化问题 | 无 | 是 | 是 |
| `waiting_first_answer` | 问题 + 首轮录音入口 | Start recording | 否 | 是 |
| `first_answer_processing` | 正在上传 / 转写首轮回答 | 无 | 是 | 是 |
| `followup_generating` | 正在生成追问 | 无 | 是 | 是 |
| `waiting_followup_answer` | 追问 + 追问录音入口 | Start recording | 否 | 是 |
| `followup_answer_processing` | 正在上传 / 转写追问回答 | 无 | 是 | 是 |
| `feedback_generating` | 正在生成反馈 | 无 | 是 | 是 |
| `redo_available` | 展示 feedback + redo 入口 | Redo / Skip redo | 否 | 是 |
| `redo_processing` | 正在上传 / 转写 redo | 无 | 是 | 是 |
| `redo_evaluating` | 正在生成 redo review | 无 | 是 | 是 |
| `completed` | 展示最终结果 | Back home / Start next | 否 | 是 |
| `abandoned` | 会话已结束 | Start new session | 否 | 是 |
| `failed` | feedback 前会话失败 | 见 10.4 | 否 | 是 |

### 10.1 AI 生成中状态

以下状态属于 AI 或服务端处理：

- `question_generating`
- `followup_generating`
- `feedback_generating`
- `redo_evaluating`

UX 规则：

- 显示明确任务名，避免只显示通用 spinner。
- 前 20 秒每 2 秒轮询一次，之后每 5 秒轮询一次。
- 90 秒仍未完成时，显示“仍在处理中，可以稍后回来”。
- 用户离开后，Home 必须通过 active session 恢复。

### 10.2 录音处理状态

以下状态属于音频上传或转写：

- `first_answer_processing`
- `followup_answer_processing`
- `redo_processing`

UX 规则：

- 进入 processing 后不得允许继续修改刚提交的音频。
- 如果请求因网络失败未到达服务端，Retry 必须复用同一 `Idempotency-Key` 和同一音频文件。
- 如果用户重新录音，必须生成新的 `Idempotency-Key`。

### 10.3 Feedback 展示状态

`redo_available` 时，客户端必须展示：

- 5 项 `visible_assessments`
- 5 段固定反馈字段：
  - `strongest_signal`
  - `biggest_gap`
  - `why_it_matters`
  - `redo_priority`
  - `redo_outline`
- Redo 按钮
- Skip redo 按钮

客户端不得展示总分。

字段列表表示 API / payload required fields，不表示页面展示顺序。页面展示顺序以第 12.1 节和 iOS Screen / UI Design Spec 为准，首屏优先展示 `biggest_gap`。

### 10.4 Completed 状态

`completed` 必须按 `completion_reason` 分流：

| `completion_reason` | UX | 主操作 |
|---|---|---|
| `redo_skipped` | 展示原 feedback | Back home / Start next |
| `redo_review_generated` | 展示原 feedback + redo review | Back home / Start next |
| `redo_review_unavailable` | 展示原 feedback + “Redo review is temporarily unavailable” 轻量提示 | Back home / Start next |

`completion_reason = redo_review_unavailable` 时：

- `redo_submitted = true`。
- `redo_review = null`。
- 不隐藏原 feedback。
- 不退款、不额外扣费。
- Home 不再显示 active session。
- 用户可以直接开始下一次训练。

### 10.5 Failed 状态

`failed` 只用于 feedback 成功之前的系统失败，或任何导致主 feedback 无法交付的失败。

| 条件 | UX | 主操作 |
|---|---|---|
| `feedback = null` | 本次训练未能完成，系统会释放 reserved credit | Start new session |

如果失败发生在 feedback 前，客户端必须刷新 `GET /home` 或 `GET /billing/entitlement`，以显示 release 后的余额。

---

## 11. 录音、上传与转写 UX

### 11.1 录音权限

客户端必须在首次录音前请求麦克风权限。

| 权限状态 | UX | 主操作 |
|---|---|---|
| 未请求 | 解释需要口头回答 | Continue |
| 被拒绝 | 提示开启麦克风权限 | Open Settings |
| 可用 | 进入录音 | Start recording |

文本输入不是 v1 主路径，不作为麦克风拒绝后的默认替代。

### 11.2 录音中

录音界面必须展示：

- 当前题目或追问
- 录音时长
- Stop / Submit
- Discard and record again

用户离开录音界面时：

- 未提交的本地录音可以保存为 draft。
- draft 不应被服务端视为回答。
- 重新提交 draft 时仍属于同一次用户意图，使用同一 `Idempotency-Key`；重新录音则使用新 key。

### 11.3 转写质量不可用

首轮、追问、redo 三个步骤都适用同一套 `transcript_quality_status` 解释。客户端不得把 `transcript_quality_status` 展示为用户可见 label。

当服务端返回以下错误：

- `TRANSCRIPTION_FAILED`
- `TRANSCRIPT_QUALITY_TOO_LOW`

客户端必须停留或回到对应等待回答状态：

- 首轮：`waiting_first_answer`
- 追问：`waiting_followup_answer`
- Redo：`redo_available`

UX 映射：

| `transcript_quality_status` | UX | 主操作 | 错误码 |
|---|---|---|---|
| `too_short` | 回答太短 | Record again | `TRANSCRIPT_QUALITY_TOO_LOW` |
| `silent` | 未检测到足够语音 | Record again | `TRANSCRIPT_QUALITY_TOO_LOW` |
| `non_english` | 请用英文回答 | Record again | `TRANSCRIPT_QUALITY_TOO_LOW` |
| `low_confidence` | 音频不清晰 | Record again | `TRANSCRIPT_QUALITY_TOO_LOW` |
| `failed` | 转写失败 | Record again | `TRANSCRIPTION_FAILED` |

`too_short` / `silent` / `non_english` / `low_confidence` 表示 ASR 已完成但转写不可用于 AI 链路；`failed` 表示 ASR 处理失败。不得把低质量转写提交给下一步 AI 链路。

---

## 12. Feedback 与 Redo UX

### 12.1 Feedback 页面

Feedback 页面必须先展示用户最需要采取行动的信息：

1. `biggest_gap`
2. `why_it_matters`
3. `redo_priority`
4. `redo_outline`
5. `strongest_signal`
6. 5 项 `visible_assessments`

这一展示顺序是 UX 建议；数据结构仍按 Prompt / Data 定义的 5 段字段。

### 12.2 Redo 可用

`redo_available` 时：

- Redo 是主操作。
- Skip redo 是次操作。
- 用户可离开页面，Home 继续显示 active session。
- Skip redo 调用 `POST /training-sessions/{session_id}/skip-redo`，成功后 session 进入 `completed`。

### 12.3 Redo 提交

用户提交 redo 后：

1. 调用 `POST /training-sessions/{session_id}/redo`。
2. 成功后进入 `redo_processing`。
3. 转写成功后进入 `redo_evaluating`。
4. redo review 生成成功后进入 `completed`，`completion_reason = redo_review_generated`。
5. redo review 生成失败或校验失败后进入 `completed`，`completion_reason = redo_review_unavailable`。

客户端通过 `GET /training-sessions/{session_id}` 获取最终 `redo_review`。

### 12.4 Redo review 失败

如果 redo review 失败：

- session 必须是 `completed`。
- `completion_reason = redo_review_unavailable`。
- `redo_submitted = true`。
- `redo_review = null`。
- 不额外扣费。
- 不退款，因为主 feedback 已完成。
- 不隐藏原 feedback。
- 展示“Redo review is temporarily unavailable”的轻量提示。
- 允许用户返回 Home 或开始下一次训练。
- Home 不再显示 active session。

---

## 13. Active session 恢复与 TTL

### 13.1 App 重启恢复

App 启动后：

1. bootstrap / token 恢复。
2. 调用 `GET /home`。
3. 如果 `active_session != null`，Home 主 CTA 必须是 Continue session。
4. 点击后调用 `GET /training-sessions/{session_id}`。

客户端不得仅凭本地缓存判断 session 已结束。

如果上次 redo review 失败后服务端返回 `status = completed` 且 `completion_reason = redo_review_unavailable`：

- Home 不显示 active session。
- 历史详情展示原 feedback 和轻量提示“Redo review is temporarily unavailable”。
- Start training 可直接开始下一次训练。

### 13.2 TTL 到期

feedback 前未完成 session 的默认 TTL 为 24 小时。TTL 到期后服务端可将 session 标记为 `abandoned` 并 release reserved credit。

客户端看到 `abandoned` 时：

- 展示“Previous session expired”。
- 主操作为 Start new session。
- 刷新余额。
- 不展示 redo 或 feedback 入口。

### 13.3 放弃训练

用户只能在 feedback 前主动 abandon。

UX 规则：

- 放弃前必须确认。
- 确认文案必须说明本次未完成训练会结束。
- 如果 credit 尚未 consumed，服务端会 release reserved credit。
- 放弃成功后返回 Home 并刷新余额。

---

## 14. Credit、Paywall 与 IAP

### 14.1 额度展示

客户端展示额度时必须区分：

- 免费剩余次数：`free_session_credits_remaining`
- 付费剩余次数：`paid_session_credits_remaining`
- 已预留次数：`reserved_session_credits`

推荐展示给用户的主信息是可用训练次数：

```text
available = free_session_credits_remaining + paid_session_credits_remaining
```

`reserved_session_credits` 不作为普通用户主显示字段，但可以影响“当前有训练进行中”的状态。

### 14.2 额度不足

当创建训练返回 `INSUFFICIENT_SESSION_CREDITS`：

- 展示 Paywall。
- 主操作：Buy Sprint Pack。
- 次操作：Restore purchase。
- 不创建本地 session。

### 14.3 购买中

购买流程：

1. `GET /billing/entitlement` 获取商品与 `app_account_token`。
2. 调用 StoreKit 2，并传入 `app_account_token`。
3. 交易成功后调用 `POST /billing/apple/verify`。
4. verify 成功后刷新 `GET /billing/entitlement` 或 `GET /home`。

UX 规则：

- StoreKit 支付中不得允许重复点击购买。
- verify 请求失败时，不得显示购买成功。
- verify 网络失败可重试，并复用同一 `Idempotency-Key` 和同一 transaction payload。

### 14.4 Restore

`POST /billing/apple/restore` 成功后：

- 如果 `restored_purchase_count > 0`，展示恢复成功并刷新余额。
- 如果为 0，展示没有可恢复购买。
- restore 失败时允许 Retry restore。

### 14.5 IAP 错误

| 错误码 | UX | 主操作 |
|---|---|---|
| `APPLE_PURCHASE_VERIFICATION_FAILED` | 购买校验失败，尚未入账 | Retry verification |
| `APPLE_TRANSACTION_ALREADY_PROCESSED` | 交易已处理，刷新余额 | Refresh entitlement |
| `APP_ACCOUNT_TOKEN_MISMATCH` | 交易不属于当前用户 | Restore purchase / Contact support |

---

## 15. 数据删除 UX

### 15.1 删除单次训练

接口：`DELETE /training-sessions/{session_id}`

确认弹窗必须说明：

- 会删除用户可见训练内容和关联音频。
- purchase / ledger 审计记录不会删除。

成功后：

- 从历史列表移除该训练。
- 如果当前详情页就是该 session，返回 History 或 Home。

失败后：

- 保留当前内容。
- 展示 Retry deletion。

### 15.2 删除全部用户数据

接口：`DELETE /app-users/me/data`

确认弹窗必须说明：

- 会删除简历、音频、转写、AI payload 和历史内容。
- token 会被撤销。
- 必要 purchase / ledger 审计记录可能按服务端合规要求保留。

成功后：

- 清空本地缓存。
- 回到 Launch。

失败后：

- 不得清空本地状态。
- 展示 Retry deletion。
- 记录 `request_id`。

---

## 16. 错误码到 UX 行为映射

| Error code | 用户解释 | 主操作 | 状态影响 |
|---|---|---|---|
| `UNAUTHORIZED` | 会话已过期，正在恢复 | 自动恢复 | bootstrap 后重试原请求一次 |
| `ACTIVE_RESUME_REQUIRED` | 需要先上传简历 | Upload resume | 返回 Home / Resume Upload |
| `RESUME_NOT_READY` | 简历仍在准备中 | Refresh status | 轮询 resume 状态 |
| `RESUME_PARSE_FAILED` | 无法读取简历内容 | Upload another resume | 当前 resume 不可训练 |
| `RESUME_PROFILE_UNUSABLE` | 简历缺少可训练经历 | Upload more detailed resume | 阻止 Start training |
| `ACTIVE_SESSION_EXISTS` | 当前已有未完成训练 | Continue session | 不创建新 session |
| `INSUFFICIENT_SESSION_CREDITS` | 训练次数不足 | Buy Sprint Pack | 展示 Paywall |
| `TRAINING_SESSION_NOT_FOUND` | 训练不存在或已删除 | Back home | 清理本地 session cache |
| `TRAINING_SESSION_NOT_READY` | 当前步骤还没准备好 | Refresh | 重新 GET session |
| `IDEMPOTENCY_CONFLICT` | 该请求已被不同内容占用 | Restart this action | 清理当前 pending key，要求用户重新操作 |
| `AUDIO_UPLOAD_FAILED` | 音频上传失败 | Retry upload | 复用同一音频和 idempotency key |
| `TRANSCRIPTION_FAILED` | 转写失败 | Record again | 回到对应录音状态 |
| `TRANSCRIPT_QUALITY_TOO_LOW` | 回答太短、静音、非英文或音频不清晰 | Record again | 不进入下一步 AI |
| `AI_GENERATION_FAILED` | 系统生成失败 | Retry / Start new | feedback 前失败应刷新余额 |
| `AI_OUTPUT_VALIDATION_FAILED` | 系统生成结果不可用 | Retry / Start new | feedback 前失败应刷新余额 |
| `APPLE_PURCHASE_VERIFICATION_FAILED` | 购买校验失败 | Retry verification | 不入账 |
| `APPLE_TRANSACTION_ALREADY_PROCESSED` | 购买已处理 | Refresh entitlement | 刷新余额 |
| `APP_ACCOUNT_TOKEN_MISMATCH` | 无法匹配当前用户 | Restore purchase | 不入账 |
| `UNSUPPORTED_FILE_TYPE` | 文件类型不支持 | Choose another file | 不上传 |
| `DATA_DELETION_FAILED` | 删除失败或部分失败 | Retry deletion | 不显示删除成功 |

---

## 17. Loading、Retry 与 Polling 规则

### 17.1 Loading 文案

Loading 必须说明当前任务：

- Preparing your resume
- Preparing your question
- Transcribing your answer
- Preparing your follow-up
- Preparing your feedback
- Reviewing your redo
- Verifying your purchase

客户端不得长时间只显示无上下文 spinner。

### 17.2 Polling 规则

适用对象：

- 简历解析
- question generation
- follow-up generation
- feedback generation
- redo evaluation
- 音频转写状态

推荐节奏：

| 时间 | 轮询间隔 |
|---|---|
| 0-20 秒 | 每 2 秒 |
| 20 秒后 | 每 5 秒 |
| 90 秒后 | 继续轮询，但显示可离开提示 |
| 180 秒后 | 显示 Retry refresh / Back home |

Retry refresh 只重新 GET 当前资源，不重新提交写请求。

### 17.3 写请求重试规则

| 场景 | 是否复用 `Idempotency-Key` |
|---|---|
| 同一文件上传重试 | 是 |
| 重新选择文件 | 否 |
| 同一音频上传重试 | 是 |
| 重新录音 | 否 |
| 创建同一次训练重试 | 是 |
| 用户返回 Home 后重新点 Start training | 否，除非本地仍有同一 pending request |
| 同一 Apple transaction verify 重试 | 是 |
| Restore retry | 是，直到用户离开 restore flow |
| 删除确认后的自动重试 | 是 |
| 用户重新打开删除弹窗并再次确认 | 否 |

---

## 18. 本地缓存与并发保护

客户端必须防止以下并发问题：

1. Start training 双击导致重复创建 session。
2. 录音提交双击导致重复上传。
3. 网络慢时旧 response 覆盖新 session 状态。
4. purchase verify 重试导致重复入账。
5. delete 成功后本地仍展示已删除内容。

实现要求：

- 每个写操作进入 pending 后，主按钮必须 disabled。
- 每个 pending 写操作保存 endpoint、idempotency key、payload fingerprint。
- 如果同一 key 返回 `IDEMPOTENCY_CONFLICT`，客户端必须停止自动重试，并要求用户重新发起该动作。
- 对 session response 必须检查 `session_id` 是否等于当前页面 session。
- 对 resume response 必须检查 `resume_id` 是否等于当前 active resume。

---

## 19. 最小验收标准

Client UX / Error Handling 层满足以下条件，才可以进入首轮联调：

1. 首次启动能 bootstrap，并进入 Home。
2. `UNAUTHORIZED` 后能自动 bootstrap 并重试原请求一次。
3. Home 能正确区分无简历、解析中、可训练、不可训练、active session、无额度。
4. 简历上传失败、解析失败、不可训练分别有明确下一步。
5. 创建训练时所有写请求都有稳定 `Idempotency-Key`。
6. `ACTIVE_SESSION_EXISTS` 时不会创建第二个 session。
7. 所有训练读取都通过 `GET /training-sessions/{session_id}`。
8. 每个 `training_session.status` 都有明确 UI 状态。
9. 音频上传失败能用同一 key 重试。
10. `too_short` / `silent` / `non_english` / `low_confidence` / `failed` 都会回到对应录音状态，不进入下一步 AI，并要求用户重录。
11. feedback 前系统失败后会刷新余额。
12. feedback 页面固定展示 5 项 visible assessment 和 5 段反馈，展示顺序以 `biggest_gap` 优先。
13. redo 可提交或跳过。
14. redo review 失败时 session 展示为 `completed + completion_reason = redo_review_unavailable`，不隐藏主 feedback，不退款，不额外扣费。
15. redo review 失败后 Home 不显示 active session，用户可以直接开始下一次训练。
16. App 重启后能通过 Home 恢复 active session。
17. TTL 后 abandoned session 能释放用户继续训练。
18. Paywall 能处理 purchase、verify、restore、already processed 和 mismatch。
19. 删除简历必须提供两种 delete mode。
20. 删除失败不得显示成功。
21. 所有 Data / API v1.1 错误码都有对应 UX 行为。

---


## 20. 一句话收束

Client UX State & Error Handling Spec v1 的目标，是让 iOS 客户端严格围绕服务端状态机、统一 API envelope、幂等写请求和可恢复 active session 构建体验，确保用户在简历、训练、redo、付费和删除这些高风险路径上始终知道下一步该做什么。
