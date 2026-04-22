# AI Behavioral Interview Coach Analytics Event Spec v1

## 1. 文档信息

- 文档名称：Analytics Event Spec
- 版本：v1
- 日期：2026-04-21
- 适用产品版本：AI Behavioral Interview Coach v1
- 主要读者：产品、数据、iOS 客户端、后端、QA
- 上游依据：
  - `docs/ios/AI_Behavioral_Interview_Coach_PRD_v1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_Data_API_Spec_v1.1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_Client_UX_State_Error_Handling_Spec_v1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_iOS_Client_Screen_Spec_v1.md`

---

## 2. 本文档解决什么问题

本文档定义 v1 必须采集的 analytics event、事件属性、触发时机、隐私边界和核心指标计算方式。

目标是让团队能回答以下问题：

1. 用户是否能顺利从上传简历进入训练。
2. 简历锚定的问题是否让用户愿意开始回答。
3. 用户是否完成首轮回答、追问回答和 feedback 闭环。
4. feedback 是否足够有价值，能驱动用户 redo。
5. redo review 是否完成，以及 redo 后是否改善。
6. 免费额度后是否触发付费和购买。
7. 失败主要发生在简历、ASR、AI、IAP、API 还是删除链路。

本文档不定义数据仓库表结构、BI dashboard 样式、A/B 实验平台、归因广告 SDK 或隐私政策全文。

---

## 3. Analytics 设计原则

### 3.1 产品验证优先

v1 analytics 只采集能判断产品成立的事件。优先回答 PRD 中的核心行为指标：

- 简历上传后开始训练的比例
- 完整训练闭环完成率
- 重答率
- 7 天内二次使用率
- 完成 2 次免费训练后的付费转化率

### 3.2 状态确认事件必须以服务端为准

以下事件不得只因客户端点击就上报为 completed：

- resume upload completed
- resume parse completed
- training session created
- first / follow-up / redo answer submitted
- feedback viewed
- redo review viewed
- session completed
- purchase verified
- purchase restored
- data deletion completed

客户端可以上报 started / clicked / viewed 类事件，但 completed / failed / credited / consumed 类事件必须以 API 成功响应或服务端状态变化为准。

### 3.3 事件分层

v1 采用混合事件模型：

| Event owner | 负责事件 | 原因 |
|---|---|---|
| Client | 页面曝光、按钮点击、录音开始、paywall 曝光、用户主动 skip / abandon 意图 | 只有客户端知道用户看到什么、点了什么 |
| Server | session 状态变化、credit reserve / consume / release、AI / ASR 结果、IAP verify / restore、删除结果 | 服务端是业务事实来源 |
| Client after API success | 用户可见结果曝光，例如 question viewed、feedback viewed、redo review viewed | 需要确认用户确实看到了结果 |

### 3.4 隐私最小化

Analytics event 绝对禁止包含：

- 原始简历文本
- `source_snippets`
- 原始音频
- 完整转写文本
- 用户完整回答内容
- AI feedback 原文
- redo review 原文
- Apple `signed_transaction_info`
- `app_account_token`
- 文件名中的真实姓名
- email、phone、地址、学校或公司自由文本

允许包含：

- 枚举
- 状态
- 数量
- 时长
- 文件类型
- 文件大小 bucket
- word count bucket
- 质量等级
- 布尔值
- 服务端生成的对象 ID
- `request_id`

### 3.5 事件命名必须稳定

事件名使用 lower snake_case：

```text
domain_object_action
```

推荐例子：

- `resume_upload_completed`
- `training_session_created`
- `feedback_viewed`
- `purchase_verified`

不得在事件名中混入 display label、UI 文案或实验组描述。

---

## 4. 通用事件 Envelope

所有 analytics event 必须包含以下通用字段：

| Field | Type | Required | Source | 说明 |
|---|---:|---|---|---|
| `event_name` | string | 是 | client / server | lower snake_case |
| `event_id` | string | 是 | emitter | UUID，用于去重 |
| `event_schema_version` | string | 是 | emitter | v1 固定为 `analytics_v1` |
| `occurred_at` | string | 是 | emitter | ISO-8601 UTC |
| `emitted_by` | enum | 是 | emitter | `client` / `server` |
| `environment` | enum | 是 | emitter | `development` / `testflight` / `production` |
| `platform` | enum | 是 | client | v1 固定为 `ios` |
| `app_version` | string | 是 | client | 例如 `1.0.0` |
| `locale` | string | 否 | client | 例如 `en-US` |
| `app_user_id` | string | 是 | API | `usr_` 前缀匿名用户 ID |
| `device_session_id` | string | 是 | client | 每次 App 前台 session 生成 |
| `request_id` | string | 否 | API | API envelope 返回的 request id |

规则：

- `app_user_id` 是匿名产品用户 ID，可用于行为分析。
- 第三方 analytics 工具不得接收 `app_account_token`。
- 如果用户删除全部数据成功，客户端必须清空本地 `device_session_id` 和 analytics queue。

---

## 5. 通用业务属性

以下字段按事件需要附加。没有业务含义时不要发送空字符串。

### 5.1 Resume context

| Field | Type | 说明 |
|---|---:|---|
| `resume_id` | string | `res_` 前缀 |
| `resume_status` | enum | `uploaded` / `parsing` / `ready` / `archived` / `deleted` / `failed` |
| `profile_quality_status` | enum | `usable` / `limited` / `unusable` |
| `source_language` | enum | v1 仅 `en` |
| `file_type` | enum | `pdf` / `docx` |
| `file_size_bucket` | enum | `0_1mb` / `1_3mb` / `3_5mb` / `over_5mb` |
| `page_count_bucket` | enum | `1_2` / `3_5` / `over_5` / `unknown` |
| `recommended_anchor_experience_count` | integer | 来自解析摘要，可为空 |
| `resume_parse_duration_ms` | integer | 服务端解析耗时 |

### 5.2 Home context

| Field | Type | 说明 |
|---|---:|---|
| `home_primary_state` | enum | 客户端按 iOS Screen Spec 第 8.4 节派生后的唯一 Home primary state |

`home_primary_state` enum:

- `activeSession`
- `noResume`
- `resumeProcessing`
- `resumeFailed`
- `resumeUnusable`
- `outOfCredits`
- `readyLimited`
- `ready`

规则：

- `home_primary_state` 只由客户端在 Home 成功渲染后发送。
- 值必须等于本次 UI 实际渲染的 primary state，不得由数据仓库事后从原始字段推算。
- `last_training_summary` 不得映射成独立 primary state；该信息继续使用 `has_last_training_summary` 表示。

### 5.3 Training context

| Field | Type | 说明 |
|---|---:|---|
| `session_id` | string | `ses_` 前缀 |
| `training_focus` | enum | canonical enum |
| `session_status` | enum | Data / API `training_session.status` |
| `billing_source` | enum | `free` / `paid` |
| `credit_state` | enum | `reserved` / `consumed` / `released` |
| `active_session_exists` | boolean | 创建训练失败或 Home 状态使用 |
| `session_age_seconds` | integer | 从 `started_at` 到事件发生 |

### 5.4 Answer / ASR context

| Field | Type | 说明 |
|---|---:|---|
| `answer_step` | enum | `first_answer` / `follow_up_answer` / `redo_answer` |
| `duration_seconds_bucket` | enum | `0_15` / `16_30` / `31_60` / `61_120` / `over_120` |
| `word_count_bucket` | enum | `0_30` / `31_80` / `81_160` / `over_160` |
| `transcript_status` | enum | `pending` / `completed` / `failed` |
| `transcript_quality_status` | enum | `usable` / `too_short` / `silent` / `non_english` / `low_confidence` / `failed` |
| `detected_language` | string | 例如 `en`；`non_english` 场景应尽量保留真实检测语言，例如 `es`、`zh` |

规则：

- `transcript_quality_status` 必须与 Data / API Spec v1.1 canonical enum 完全一致，不得作为粗粒度 analytics bucket 重新定义。
- `transcript_status` 表示 ASR 处理是否完成；`transcript_quality_status` 表示已完成转写后的质量或可用性判断。
- `transcript_quality_status = usable` / `too_short` / `silent` / `non_english` / `low_confidence` 时，`transcript_status = completed`。
- `transcript_quality_status = failed` 时，`transcript_status = failed`。
- `too_short` / `silent` / `non_english` / `low_confidence` 对应 `error_code = TRANSCRIPT_QUALITY_TOO_LOW`。
- `failed` 对应 `error_code = TRANSCRIPTION_FAILED`。
- 如后续需要粗粒度分析，只能新增 derived / reporting-only 字段，例如 `transcript_quality_bucket`，不得复用 `transcript_quality_status`。

### 5.5 Feedback / redo context

| Field | Type | 说明 |
|---|---:|---|
| `visible_assessment_answered_the_question` | enum | `Strong` / `Mixed` / `Weak` |
| `visible_assessment_story_fit` | enum | `Strong` / `Mixed` / `Weak` |
| `visible_assessment_personal_ownership` | enum | `Strong` / `Mixed` / `Weak` |
| `visible_assessment_evidence_and_outcome` | enum | `Strong` / `Mixed` / `Weak` |
| `visible_assessment_holds_up_under_follow_up` | enum | `Strong` / `Mixed` / `Weak` |
| `redo_submitted` | boolean | 用户是否提交 redo |
| `redo_improvement_status` | enum | `improved` / `partially_improved` / `not_improved` / `regressed` |
| `completion_reason` | enum | `redo_skipped` / `redo_review_generated` / `redo_review_unavailable` |
| `redo_review_failure_code` | string | 可选，仅 `completion_reason = redo_review_unavailable` 时用于归因 |

不得发送 10 维 `internal_scores` 到第三方 analytics。内部数据仓库可以保存分数用于质量评估，但必须与用户行为 analytics 分开建表，并遵守隐私最小化原则。

### 5.6 Billing context

| Field | Type | 说明 |
|---|---:|---|
| `free_session_credits_remaining` | integer | API 返回值 |
| `paid_session_credits_remaining` | integer | API 返回值 |
| `reserved_session_credits` | integer | API 返回值 |
| `available_session_credits` | integer | free + paid |
| `product_id` | string | App Store product id |
| `purchase_id` | string | `pur_` 前缀 |
| `restored_purchase_count` | integer | restore 结果 |

### 5.7 Error context

| Field | Type | 说明 |
|---|---:|---|
| `error_code` | enum | Data / API v1.1 错误码；仅 API envelope 返回错误时使用 |
| `client_error_code` | enum | 客户端、本地网络或 StoreKit 失败码；不得混入 Data / API 错误码 |
| `http_status` | integer | HTTP 状态码 |
| `failed_endpoint` | string | API path template，不含 query 中的 PII |
| `failed_operation` | string | 例如 `resume_upload`、`verify_purchase` |
| `retry_count` | integer | 当前用户意图下的重试次数 |
| `idempotency_key_reused` | boolean | 写请求重试是否复用 key |

`error_code` 必须来自 Data / API Spec v1.1 的错误码枚举：

- `UNAUTHORIZED`
- `ACTIVE_RESUME_REQUIRED`
- `RESUME_NOT_READY`
- `RESUME_PARSE_FAILED`
- `RESUME_PROFILE_UNUSABLE`
- `ACTIVE_SESSION_EXISTS`
- `INSUFFICIENT_SESSION_CREDITS`
- `TRAINING_SESSION_NOT_FOUND`
- `TRAINING_SESSION_NOT_READY`
- `IDEMPOTENCY_CONFLICT`
- `AUDIO_UPLOAD_FAILED`
- `TRANSCRIPTION_FAILED`
- `TRANSCRIPT_QUALITY_TOO_LOW`
- `AI_GENERATION_FAILED`
- `AI_OUTPUT_VALIDATION_FAILED`
- `APPLE_PURCHASE_VERIFICATION_FAILED`
- `APPLE_TRANSACTION_ALREADY_PROCESSED`
- `APP_ACCOUNT_TOKEN_MISMATCH`
- `UNSUPPORTED_FILE_TYPE`
- `DATA_DELETION_FAILED`

`client_error_code` 仅允许以下值：

- `network_unreachable`
- `request_timeout`
- `storekit_user_cancelled`
- `storekit_purchase_failed`
- `local_file_read_failed`
- `microphone_permission_denied`

---

## 6. 事件清单总览

v1 必须实现以下事件。

| Domain | Event | Owner | 触发时机 |
|---|---|---|---|
| App | `app_bootstrap_started` | client | 开始 bootstrap |
| App | `app_bootstrap_completed` | client | bootstrap API 成功后 |
| App | `app_bootstrap_failed` | client | bootstrap API 失败后 |
| Home | `home_viewed` | client | Home 成功渲染后 |
| Resume | `resume_upload_started` | client | 用户确认上传后 |
| Resume | `resume_upload_completed` | server | `POST /resumes` 成功创建 resume |
| Resume | `resume_parse_completed` | server | resume 进入 `ready` |
| Resume | `resume_parse_failed` | server | 文本提取或解析失败 |
| Resume | `resume_profile_unusable` | server | `profile_quality_status = unusable` |
| Training | `training_focus_selected` | client | 用户选择训练重心 |
| Training | `training_session_create_started` | client | 用户点击 Start training |
| Training | `training_session_created` | server | session 创建成功并 reserve credit |
| Training | `training_session_create_failed` | client | 创建训练 API 返回错误 |
| Training | `question_viewed` | client | 问题在客户端可见 |
| Answer | `first_answer_recording_started` | client | 首轮录音开始 |
| Answer | `first_answer_submitted` | server | 首轮音频被服务端接受且转写可用 |
| Answer | `first_answer_transcription_failed` | server | 首轮转写失败或质量不足 |
| Follow-up | `follow_up_viewed` | client | 追问在客户端可见 |
| Answer | `follow_up_answer_recording_started` | client | 追问录音开始 |
| Answer | `follow_up_answer_submitted` | server | 追问音频被服务端接受且转写可用 |
| Answer | `follow_up_answer_transcription_failed` | server | 追问转写失败或质量不足 |
| Feedback | `feedback_generated` | server | feedback payload 生成并校验通过 |
| Feedback | `feedback_viewed` | client | feedback 在客户端可见 |
| Redo | `redo_started` | client | 用户开始 redo 录音 |
| Redo | `redo_submitted` | server | redo 音频被服务端接受且转写可用 |
| Redo | `redo_transcription_failed` | server | redo 转写失败或质量不足 |
| Redo | `redo_skipped` | server | `skip-redo` 成功，session completed |
| Redo | `redo_review_generated` | server | redo review payload 生成并校验通过 |
| Redo | `redo_review_viewed` | client | redo review 在客户端可见 |
| Session | `training_session_completed` | server | session 进入 `completed` |
| Session | `training_session_abandoned` | server | 用户 abandon 或 TTL |
| Session | `training_session_failed` | server | feedback 成功前 session 进入 `failed` |
| Billing | `paywall_viewed` | client | Paywall 可见 |
| Billing | `purchase_started` | client | 调起 StoreKit 购买 |
| Billing | `purchase_verified` | server | Apple 交易校验成功并入账 |
| Billing | `purchase_failed` | client / server | StoreKit 失败或 verify 失败 |
| Billing | `purchase_restored` | server | restore 成功返回 |
| Data | `resume_delete_completed` | server | 删除活跃简历成功 |
| Data | `training_session_delete_completed` | server | 删除单次训练成功 |
| Data | `user_data_delete_completed` | server | 删除全部用户数据成功 |
| Error | `api_error_received` | client | 任意 API 返回 `error != null` |

---

## 7. 事件定义

### 7.1 App / Home

#### `app_bootstrap_started`

触发：App 需要创建或恢复匿名身份时。

必填属性：

- common envelope
- `has_cached_token`
- `has_cached_home`

#### `app_bootstrap_completed`

触发：`POST /app-users/bootstrap` 成功后。

必填属性：

- common envelope
- `free_session_credits_remaining`
- `paid_session_credits_remaining`
- `reserved_session_credits`
- `has_active_resume`
- `has_active_session`

#### `app_bootstrap_failed`

触发：bootstrap 失败后。

必填属性：

- common envelope
- `retry_count`

如果收到 API envelope error，必须带：

- `error_code`
- `http_status`
- `request_id`

如果请求未到达服务端，必须带：

- `client_error_code`

#### `home_viewed`

触发：Home 成功渲染后。

必填属性：

- common envelope
- `has_active_resume`
- `active_resume_status`
- `profile_quality_status`
- `has_active_session`
- `active_session_status`
- `available_session_credits`
- `home_primary_state`
- `has_last_training_summary`

---

### 7.2 Resume

#### `resume_upload_started`

触发：用户选择文件并确认上传。

Owner：client。

必填属性：

- `file_type`
- `file_size_bucket`
- `page_count_bucket`
- `source_language`

禁止属性：

- file name
- resume text

#### `resume_upload_completed`

触发：`POST /resumes` 成功，服务端创建 `resume_document`。

Owner：server。

必填属性：

- `resume_id`
- `resume_status`
- `source_language`
- `file_type`
- `file_size_bucket`

#### `resume_parse_completed`

触发：resume 进入 `ready`。

Owner：server。

必填属性：

- `resume_id`
- `resume_status`
- `profile_quality_status`
- `resume_parse_duration_ms`
- `recommended_anchor_experience_count`

规则：

- 如果 `profile_quality_status = unusable`，同时发 `resume_profile_unusable`。
- 不得发送 `candidate_summary`、`top_strength_signals` 的自由文本。

#### `resume_parse_failed`

触发：简历文本提取或解析失败。

Owner：server。

必填属性：

- `resume_id`
- `error_code`
- `resume_status`
- `resume_parse_duration_ms`

#### `resume_profile_unusable`

触发：简历解析完成但缺少可训练锚点。

Owner：server。

必填属性：

- `resume_id`
- `profile_quality_status`
- `recommended_anchor_experience_count`
- `error_code`

---

### 7.3 Training Session

#### `training_focus_selected`

触发：用户选择训练重心。

Owner：client。

必填属性：

- `training_focus`

规则：

- `training_focus` 必须使用 canonical enum。
- 不得发送 Display label。

#### `training_session_create_started`

触发：用户点击 Start training。

Owner：client。

必填属性：

- `resume_id`
- `training_focus`
- `available_session_credits`

#### `training_session_created`

触发：服务端创建 session 并写入 `credit_ledger.reserve`。

Owner：server。

必填属性：

- `session_id`
- `resume_id`
- `training_focus`
- `session_status`
- `billing_source`
- `credit_state`
- `free_session_credits_remaining`
- `paid_session_credits_remaining`
- `reserved_session_credits`

#### `training_session_create_failed`

触发：`POST /training-sessions` 返回错误。

Owner：client。

必填属性：

- `error_code`
- `request_id`
- `training_focus`
- `available_session_credits`
- `active_session_exists`

---

### 7.4 Question / Follow-up

#### `question_viewed`

触发：客户端从 `GET /training-sessions/{session_id}` 获得 question 并实际展示给用户。

Owner：client。

必填属性：

- `session_id`
- `resume_id`
- `training_focus`
- `session_status`
- `question_id`

禁止属性：

- `question_text`
- `resume_anchor_hint`

#### `follow_up_viewed`

触发：客户端展示 follow-up question。

Owner：client。

必填属性：

- `session_id`
- `training_focus`
- `target_gap`
- `session_status`

禁止属性：

- `follow_up_text`
- first answer transcript

---

### 7.5 Answer / ASR

#### `first_answer_recording_started`

触发：用户开始首轮录音。

Owner：client。

必填属性：

- `session_id`
- `training_focus`
- `answer_step = first_answer`

#### `first_answer_submitted`

触发：服务端接受首轮音频，且转写可用于 Follow-up Generate。

Owner：server。

必填属性：

- `session_id`
- `answer_step = first_answer`
- `duration_seconds_bucket`
- `transcript_status`
- `transcript_quality_status`
- `word_count_bucket`
- `detected_language`

规则：

- 可用首轮回答必须使用 `transcript_status = completed` 与 `transcript_quality_status = usable`。

禁止属性：

- audio URL
- transcript text

#### `first_answer_transcription_failed`

触发：首轮转写失败或质量不足。

Owner：server。

必填属性：

- `session_id`
- `answer_step = first_answer`
- `error_code`
- `transcript_status`
- `transcript_quality_status`
- `duration_seconds_bucket`

规则：

- `too_short` / `silent` / `non_english` / `low_confidence` 时，`transcript_status = completed`，`error_code = TRANSCRIPT_QUALITY_TOO_LOW`。
- `failed` 时，`transcript_status = failed`，`error_code = TRANSCRIPTION_FAILED`。
- `non_english` 场景应尽量包含真实 `detected_language`。

#### `follow_up_answer_recording_started`

触发：用户开始追问回答录音。

Owner：client。

必填属性：

- `session_id`
- `training_focus`
- `answer_step = follow_up_answer`
- `target_gap`

#### `follow_up_answer_submitted`

触发：服务端接受追问回答音频，且转写可用于 Feedback Generate。

Owner：server。

必填属性：

- `session_id`
- `answer_step = follow_up_answer`
- `target_gap`
- `duration_seconds_bucket`
- `transcript_status`
- `transcript_quality_status`
- `word_count_bucket`

规则：

- 可用追问回答必须使用 `transcript_status = completed` 与 `transcript_quality_status = usable`。

#### `follow_up_answer_transcription_failed`

触发：追问回答转写失败或质量不足。

Owner：server。

必填属性：

- `session_id`
- `answer_step = follow_up_answer`
- `target_gap`
- `error_code`
- `transcript_status`
- `transcript_quality_status`

规则：

- `too_short` / `silent` / `non_english` / `low_confidence` 时，`transcript_status = completed`，`error_code = TRANSCRIPT_QUALITY_TOO_LOW`。
- `failed` 时，`transcript_status = failed`，`error_code = TRANSCRIPTION_FAILED`。
- `non_english` 场景应尽量包含真实 `detected_language`。

---

### 7.6 Feedback

#### `feedback_generated`

触发：服务端生成 `feedback_payload` 并校验通过；credit 从 `reserved` 变为 `consumed`。

Owner：server。

必填属性：

- `session_id`
- `training_focus`
- `session_status = redo_available`
- `billing_source`
- `credit_state = consumed`
- 5 个 `visible_assessment_*`

禁止属性：

- `strongest_signal`
- `biggest_gap`
- `why_it_matters`
- `redo_priority`
- `redo_outline`
- internal scores

#### `feedback_viewed`

触发：客户端实际展示 feedback 页面。

Owner：client。

必填属性：

- `session_id`
- `training_focus`
- `session_status`
- 5 个 `visible_assessment_*`
- `available_session_credits`

规则：

- 这是判断用户是否进入 redo 决策点的关键事件。
- 如果用户离开 App，没有看到 feedback，不应发送该事件。

---

### 7.7 Redo

#### `redo_started`

触发：用户点击 redo 并开始录音。

Owner：client。

必填属性：

- `session_id`
- `training_focus`
- `answer_step = redo_answer`

#### `redo_submitted`

触发：服务端接受 redo 音频，且转写可用于 Redo Evaluate。

Owner：server。

必填属性：

- `session_id`
- `answer_step = redo_answer`
- `duration_seconds_bucket`
- `transcript_status`
- `transcript_quality_status`
- `word_count_bucket`

规则：

- 可用 redo 回答必须使用 `transcript_status = completed` 与 `transcript_quality_status = usable`。

#### `redo_transcription_failed`

触发：redo 转写失败或质量不足。

Owner：server。

必填属性：

- `session_id`
- `answer_step = redo_answer`
- `error_code`
- `transcript_status`
- `transcript_quality_status`

规则：

- `too_short` / `silent` / `non_english` / `low_confidence` 时，`transcript_status = completed`，`error_code = TRANSCRIPT_QUALITY_TOO_LOW`。
- `failed` 时，`transcript_status = failed`，`error_code = TRANSCRIPTION_FAILED`。
- `non_english` 场景应尽量包含真实 `detected_language`。

#### `redo_skipped`

触发：`POST /training-sessions/{session_id}/skip-redo` 成功。

Owner：server。

必填属性：

- `session_id`
- `training_focus`
- `redo_submitted = false`
- `session_status = completed`
- `completion_reason = redo_skipped`

#### `redo_review_generated`

触发：服务端生成 `redo_review_payload` 并校验通过。

Owner：server。

必填属性：

- `session_id`
- `redo_submitted = true`
- `completion_reason = redo_review_generated`
- `redo_improvement_status`
- 5 个 final `visible_assessment_*`

禁止属性：

- `what_improved`
- `still_missing`
- `final_takeaway`
- `next_practice_priority`
- updated internal scores

#### `redo_review_viewed`

触发：客户端实际展示 redo review。

Owner：client。

必填属性：

- `session_id`
- `redo_submitted = true`
- `redo_improvement_status`
- 5 个 final `visible_assessment_*`

---

### 7.8 Session Lifecycle

#### `training_session_completed`

触发：session 进入 `completed`。

Owner：server。

必填属性：

- `session_id`
- `training_focus`
- `billing_source`
- `credit_state`
- `redo_submitted`
- `completion_reason`
- `redo_improvement_status`，仅 `completion_reason = redo_review_generated` 时必填
- `session_age_seconds`

可选属性：

- `redo_review_failure_code`，仅 `completion_reason = redo_review_unavailable` 时使用

`completion_reason` 规则：

- `redo_skipped`：`redo_submitted = false`，不得包含 `redo_improvement_status`。
- `redo_review_generated`：`redo_submitted = true`，必须包含 `redo_improvement_status`。
- `redo_review_unavailable`：`redo_submitted = true`，不得包含 `redo_improvement_status`，可包含 `redo_review_failure_code`。

#### `training_session_abandoned`

触发：用户主动 abandon 或 TTL 导致 session 进入 `abandoned`。

Owner：server。

必填属性：

- `session_id`
- `session_status = abandoned`
- `credit_state`
- `abandon_reason`，enum：`user_abandon` / `ttl_expired`
- `session_age_seconds`

#### `training_session_failed`

触发：feedback 成功前 session 进入 `failed`，或任何导致主 feedback 无法交付的失败。

redo review generation failure 不触发 `training_session_failed`；该场景必须通过 `training_session_completed` + `completion_reason = redo_review_unavailable` 记录。

Owner：server。

必填属性：

- `session_id`
- `session_status = failed`
- `error_code`
- `failed_stage`
- `credit_state`
- `session_age_seconds`

`failed_stage` enum:

- `question_generation`
- `first_answer_transcription`
- `follow_up_generation`
- `follow_up_answer_transcription`
- `feedback_generation`

---

### 7.9 Billing

#### `paywall_viewed`

触发：客户端展示 Paywall。

Owner：client。

必填属性：

- `available_session_credits`
- `free_session_credits_remaining`
- `paid_session_credits_remaining`
- `paywall_reason`

`paywall_reason` enum:

- `insufficient_credits`
- `start_training_blocked`
- `manual_open`

#### `purchase_started`

触发：用户点击购买并调起 StoreKit。

Owner：client。

必填属性：

- `product_id`
- `available_session_credits`

#### `purchase_verified`

触发：`POST /billing/apple/verify` 校验成功并入账。

Owner：server。

必填属性：

- `purchase_id`
- `product_id`
- `free_session_credits_remaining`
- `paid_session_credits_remaining`
- `reserved_session_credits`

禁止属性：

- transaction id
- original transaction id
- signed transaction info
- app account token

#### `purchase_failed`

触发：StoreKit 失败、用户取消，或服务端 verify 失败。

Owner：client / server。

必填属性：

- `product_id`
- `purchase_failure_stage`

如果失败发生在 StoreKit 阶段，必须带：

- `client_error_code`

如果失败发生在服务端 verify 阶段，必须带：

- `error_code`
- `request_id`

`purchase_failure_stage` enum:

- `storekit_purchase`
- `server_verify`

#### `purchase_restored`

触发：`POST /billing/apple/restore` 成功。

Owner：server。

必填属性：

- `restored_purchase_count`
- `free_session_credits_remaining`
- `paid_session_credits_remaining`
- `reserved_session_credits`

---

### 7.10 Data Deletion

#### `resume_delete_completed`

触发：`DELETE /resumes/active` 成功。

Owner：server。

必填属性：

- `resume_id`
- `delete_mode`
- `removed_artifact_count`
- `retained_artifact_count`

禁止属性：

- removed / retained artifact 的自由文本明细；如需记录，只能使用安全 enum。

#### `training_session_delete_completed`

触发：`DELETE /training-sessions/{session_id}` 成功。

Owner：server。

必填属性：

- `session_id`
- `had_audio`
- `had_feedback`
- `had_redo_review`

#### `user_data_delete_completed`

触发：`DELETE /app-users/me/data` 成功。

Owner：server。

必填属性：

- `revoked_sessions`
- `deleted_resume_count`
- `deleted_training_session_count`

规则：

- 该事件发送成功后，不得继续发送与旧 `app_user_id` 绑定的客户端 analytics。

---

### 7.11 Error

#### `api_error_received`

触发：任意 API 返回 envelope `error != null`。

Owner：client。

必填属性：

- `error_code`
- `request_id`
- `http_status`
- `failed_endpoint`
- `failed_operation`
- `retry_count`
- `idempotency_key_reused`，仅写接口必填

规则：

- `failed_endpoint` 使用 path template，例如 `/training-sessions/{session_id}/redo`。
- 不得把 request body 写入 analytics。

---

## 8. 核心指标定义

### 8.1 简历上传成功率

```text
resume_upload_completed / resume_upload_started
```

按 `file_type`、`file_size_bucket` 分组。

### 8.2 简历可训练率

```text
resume_parse_completed where profile_quality_status in (usable, limited)
/
resume_parse_completed
```

同时关注：

```text
resume_profile_unusable / resume_parse_completed
```

### 8.3 简历上传到开始训练转化率

```text
training_session_created / resume_parse_completed where profile_quality_status in (usable, limited)
```

按 `profile_quality_status`、`training_focus` 分组。

### 8.4 训练开始到问题曝光率

```text
question_viewed / training_session_created
```

低于预期通常说明 question generation、轮询或 session 恢复有问题。

### 8.5 问题曝光到首轮回答提交率

```text
first_answer_submitted / question_viewed
```

这是判断“题目是否让用户愿意回答”的核心指标。

### 8.6 首轮回答到追问曝光率

```text
follow_up_viewed / first_answer_submitted
```

失败主要归因于 ASR 或 Follow-up Generate。

### 8.7 追问曝光到追问回答提交率

```text
follow_up_answer_submitted / follow_up_viewed
```

这是判断追问是否过难、过怪或打断体验的指标。

### 8.8 训练开始到 feedback 完成率

```text
feedback_viewed / training_session_created
```

这是 v1 最核心闭环完成率。

### 8.9 Feedback 后 redo 使用率

```text
redo_submitted / feedback_viewed
```

如果偏低，需要结合质性反馈判断 feedback 是否足够具体、redo 入口是否清楚。

### 8.10 Redo review 完成率

```text
redo_review_viewed / redo_submitted
```

该指标衡量用户实际看到 redo review 的比例。redo review 生成不可用不计入 `training_session_failed`，需要单独看 8.11。

### 8.11 Redo review unavailable rate

```text
training_session_completed where completion_reason = redo_review_unavailable
/
training_session_completed where redo_submitted = true
```

该指标衡量 redo review generation / validation failure。不得通过 `training_session_failed` 统计 redo review 失败率。

### 8.12 完整训练闭环完成率

```text
training_session_completed / training_session_created
```

注意：用户 skip redo 后也算 session completed；`completion_reason = redo_review_unavailable` 仍计入 completed。redo 使用率和 redo review unavailable rate 单独衡量。

### 8.13 免费额度后付费转化率

```text
purchase_verified / paywall_viewed where paywall_reason = insufficient_credits
```

需要额外跟踪：

```text
paywall_viewed after user has completed 2 free sessions
```

### 8.14 7 天内二次使用率

```text
count(app_user_id with >= 2 training_session_created within 7 days of first training_session_created)
/
count(app_user_id with >= 1 training_session_created)
```

### 8.15 系统失败率

```text
training_session_failed / training_session_created
```

必须按 `failed_stage`、`error_code` 分组。

redo review generation failure 不计入系统失败率；统一通过 `completion_reason = redo_review_unavailable` 统计。

---

## 9. 关键分析切片

v1 dashboard 必须支持以下切片：

- `training_focus`
- `profile_quality_status`
- `billing_source`
- `app_version`
- `environment`
- `file_type`
- `duration_seconds_bucket`
- `transcript_quality_status`
- `error_code`
- `failed_stage`
- `paywall_reason`
- `completion_reason`
- `redo_improvement_status`

不建议在 v1 做以下切片：

- 学校
- 公司
- 职级
- 具体行业自由文本
- 用户简历关键词
- 用户回答关键词

这些字段要么容易引入 PII，要么在 v1 样本量不足时会制造噪声。

---

## 10. 隐私与数据保留边界

### 10.1 第三方 analytics 禁止字段

如果使用第三方 analytics 工具，禁止发送：

- `app_account_token`
- Apple transaction id
- `signed_transaction_info`
- resume text
- transcript text
- feedback text
- redo review text
- audio URL
- file name
- `source_snippets`
- internal scores

### 10.2 内部数据仓库允许字段

内部数据仓库可以保存以下字段用于质量评估：

- `internal_scores`
- visible assessments
- redo improvement status
- word count bucket
- duration bucket
- AI generation status
- validation status
- failed stage
- completion reason
- redo review failure code

内部数据仓库不得把这些字段和原始简历、原始回答文本混存在同一宽表中。

### 10.3 删除用户数据后的 analytics 行为

当 `user_data_delete_completed` 成功：

- 客户端停止发送旧 `app_user_id` 事件。
- 本地 analytics queue 必须清空。
- 后续重新使用产品时，重新 bootstrap 并使用新的用户上下文。
- 历史聚合指标可以保留不可逆聚合结果，但不能继续保留可识别训练内容。

---

## 11. 事件 QA 规则

### 11.1 基础校验

每个事件必须满足：

- `event_name` 属于本文档定义事件。
- `event_id` 唯一。
- `occurred_at` 是 ISO-8601 UTC。
- `event_schema_version = analytics_v1`。
- 必填字段完整。
- enum 值与 Data / API Spec v1.1 一致。
- `home_viewed.home_primary_state` 必须等于客户端实际渲染的 Home primary state。
- `transcript_quality_status` 必须使用 Data / API Spec v1.1 canonical enum，不得出现废弃值。
- 当 `transcript_quality_status` 为 `usable` / `too_short` / `silent` / `non_english` / `low_confidence` 时，`transcript_status` 必须为 `completed`。
- 当 `transcript_quality_status = failed` 时，`transcript_status` 必须为 `failed`。
- 当 `transcript_quality_status = non_english` 且服务端识别到语言时，必须保留真实 `detected_language`。

### 11.2 PII 校验

Analytics pipeline 必须拒绝包含以下字段名或疑似内容的事件：

- `resume_text`
- `source_snippets`
- `transcript_text`
- `audio_storage_key`
- `question_text`
- `follow_up_text`
- `strongest_signal`
- `biggest_gap`
- `why_it_matters`
- `redo_priority`
- `redo_outline`
- `what_improved`
- `still_missing`
- `final_takeaway`
- `next_practice_priority`
- `signed_transaction_info`
- `app_account_token`

### 11.3 漏斗一致性校验

同一个 `session_id` 下应满足：

1. `training_session_created` 早于 `question_viewed`。
2. `question_viewed` 早于 `first_answer_submitted`。
3. `first_answer_submitted` 早于 `follow_up_viewed`。
4. `follow_up_viewed` 早于 `follow_up_answer_submitted`。
5. `follow_up_answer_submitted` 早于 `feedback_generated`。
6. `feedback_generated` 早于 `feedback_viewed`。
7. `redo_review_generated` 早于 `redo_review_viewed`。
8. `training_session_completed` 不得早于 `feedback_generated`。

允许例外：

- 用户没有 redo：可以有 `redo_skipped`，没有 `redo_submitted`。
- redo review 失败：必须有 `training_session_completed` 且 `completion_reason = redo_review_unavailable`，可以有 `redo_submitted`，没有 `redo_review_generated` 或 `redo_review_viewed`。
- session abandoned：可以缺少 feedback 之后的事件。

---

## 12. 最小验收标准

Analytics v1 满足以下条件，才可以进入首轮 TestFlight：

1. 所有 v1 必须事件均能被 client 或 server 触发。
2. 所有事件都带 `event_schema_version = analytics_v1`。
3. 所有 completed / failed / verified 类事件以服务端状态或 API 成功响应为准。
4. `feedback_viewed` 只在用户实际看到 feedback 后触发。
5. `redo_review_viewed` 只在用户实际看到 redo review 后触发。
6. redo review generation failure 不触发 `training_session_failed`。
7. `training_session_completed` 必须支持 `completion_reason`。
8. 所有 ASR 相关事件中的 `transcript_quality_status` 使用 Data / API Spec v1.1 canonical enum。
9. `too_short` / `silent` / `non_english` / `low_confidence` 使用 `TRANSCRIPT_QUALITY_TOO_LOW`；`failed` 使用 `TRANSCRIPTION_FAILED`。
10. 所有 Data / API v1.1 错误码都能通过 `api_error_received` 记录。
11. IAP verify 成功只产生一次 `purchase_verified`。
12. 同一 `event_id` 重复上报能被去重。
13. 第三方 analytics 不接收简历、转写、AI 文案、Apple transaction payload 或 `app_account_token`。
14. 能计算 PRD v1 第 16 节定义的核心行为指标。
15. 能按 `training_focus`、`profile_quality_status`、`error_code`、`failed_stage`、`completion_reason`、`transcript_quality_status` 做基础切片。
16. 能按 `home_primary_state` 分析 Home 实际展示的下一步动作。
17. 删除全部用户数据成功后，客户端不再发送旧 `app_user_id` 事件。

---


## 13. 一句话收束

Analytics Event Spec v1 的目标不是采集更多数据，而是用最少、最安全、最可归因的事件判断：用户是否能从简历进入训练、是否完成 feedback 和 redo 闭环、是否愿意付费，以及失败到底发生在哪个产品环节。
