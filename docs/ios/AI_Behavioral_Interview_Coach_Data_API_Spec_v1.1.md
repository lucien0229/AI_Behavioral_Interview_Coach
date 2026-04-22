# AI Behavioral Interview Coach Data / API Spec v1.1

## 1. 文档信息

- 文档名称：AI Behavioral Interview Coach Data / API Spec
- 文档版本：v1.1
- 关联文档：
  - `docs/ios/AI_Behavioral_Interview_Coach_产品概念文档_v3.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_PRD_v1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_Prompt_Content_Spec_v1.1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_iOS_Client_Screen_Spec_v1.md`
- 适用范围：iOS 首版、收费验证版、英语、PM / Program Manager、简历个性化行为面试训练
- 文档目的：定义首版数据模型、对象关系、服务端边界、API 契约、状态机、计费入账、隐私删除与最小存储策略，供开发直接落地

---

## 2. v1.1 修订目标

Data / API Spec v1.1 相对 v1 修复以下问题：

1. 显式绑定 `Prompt / Content Spec v1.1`，承接 5 步 AI 链路。
2. 新增 `redo_review_payload`，让 Redo Evaluate 成为完整训练闭环的一部分。
3. 统一 Prompt v1.1 中的 canonical enum，修正旧版 `ownership` / 双问句追问示例。
4. 将 credit 消耗时机从“题目生成成功”调整为“反馈生成成功并进入 redo_available”。
5. 新增 `credit_ledger`，避免仅靠余额字段导致重复扣费、重复入账或补偿困难。
6. 新增匿名 `access_token`，不再把 `installation_id` 当作权限凭证。
7. 所有写接口支持 `Idempotency-Key`。
8. IAP 契约升级为 StoreKit 2 / App Store Server API 风格，使用 `app_account_token` 关联交易与用户。
9. 补充转写质量字段，避免沉默、太短、非英文或低置信转写污染 AI 反馈。
10. 补充数据保留、删除和最小化存储策略。
11. 为所有 AI payload 增加 `prompt_version`、`schema_version`、`model_name`、`validation_status` 等元数据。

---

## 3. 本文档解决什么问题

PRD 定义“产品做什么”，Prompt / Content Spec v1.1 定义“AI 如何生成题目、追问、反馈和 redo review”。

本文档回答：

1. 需要保存哪些核心对象。
2. iOS、本地、服务端、对象存储分别承担什么职责。
3. 一次完整训练的数据与状态如何推进。
4. 简历、训练、AI payload、计费、历史记录之间如何关联。
5. 客户端要调用哪些 API，以及每个 API 的输入输出。
6. 在“不强制独立账号”的前提下，如何完成匿名身份、免费额度、Apple IAP 和数据删除。

---

## 4. 设计边界与原则

### 4.1 首版范围

v1.1 只覆盖以下主路径：

- App 启动并建立匿名用户。
- 上传 1 份英文简历并生成 `resume_profile`。
- 完成一次基于简历的完整训练闭环。
- 完成或跳过 1 次 guided redo。
- 查看最近训练历史。
- 用尽 2 次免费闭环后，通过 Apple IAP 购买 Sprint Pack。

### 4.2 首版不扩展的内容

v1.1 不做：

- 独立账号体系。
- 多简历管理。
- JD 数据模型。
- 多岗位配置中心。
- 长期成长图谱。
- 多设备资料合并。
- 复杂组织权限模型。
- live interview copilot。

### 4.3 数据设计原则

1. **Minimal but complete**：只保留训练、回看、计费、风控和删除所必需的数据。
2. **Resume-first**：训练、问题、追问、反馈、redo review 都必须可追溯到当前活跃简历画像。
3. **Anonymous-first, token-secured**：不强制注册，但所有服务端 API 必须使用匿名 `access_token` 授权。
4. **One active resume**：每个用户 v1.1 只允许 1 份活跃简历。
5. **One active session**：每个用户同一时间只允许 1 个未完成训练会话，避免刷题和状态发散。
6. **Session is billable unit**：计费单位是完整训练会话，不是单个 AI 调用。
7. **Redo is evaluated, not a second interview loop**：redo 后只生成轻量 delta review，不生成第二轮追问或完整第二份反馈。
8. **Ledger before balance**：余额是派生结果，credit 变化必须先进入不可变流水。
9. **Strict AI contracts**：所有 AI 输出先通过 JSON schema 与内容校验，再持久化并返回客户端。

---

## 5. 系统边界与职责划分

### 5.1 iOS 客户端职责

客户端负责：

- 生成并保存 `installation_id`。
- 保存服务端签发的匿名 `access_token` 到 Keychain。
- 简历选择、上传、替换和删除入口。
- 录音、回放、重录、提交。
- 展示题目、追问、反馈、redo guidance、redo review、历史记录、付费墙。
- 调用 StoreKit 2 发起 IAP，并把交易信息上报服务端校验。
- 对写请求传入 `Idempotency-Key`。
- 缓存少量首页、历史摘要和当前会话状态。

### 5.2 服务端职责

服务端负责：

- 匿名用户 bootstrap、token 签发与鉴权。
- 简历元数据、对象存储 key、解析结果和删除状态管理。
- 训练会话编排、状态推进、单 active session 限制。
- 音频转写、转写质量判断。
- 调用 Prompt v1.1 的 5 步 AI 链路并持久化结构化结果。
- AI 输出校验、失败重试、错误归因。
- credit reserve / consume / release / grant / refund 的 ledger 入账。
- Apple IAP 交易校验、`app_account_token` 匹配与权益入账。
- 提供历史记录、会话详情、删除接口。

### 5.3 对象存储职责

对象存储保存：

- 原始简历文件。
- 首轮回答音频。
- 追问回答音频。
- redo 音频。

对象存储中的文件必须支持按 `app_user_id`、`resume_id`、`session_id` 精确删除。

### 5.4 本地存储职责

本地仅保存：

- `installation_id`
- `app_user_id`
- 匿名 `access_token` 与过期时间
- 活跃简历摘要
- 最近 5 条训练历史摘要
- 最近一次 `usage_balance` 快照
- 当前未完成会话状态快照
- 录音临时文件，提交成功后可删除

本地不得保存原始简历全文、完整转写文本或完整 AI 反馈作为长期缓存。

---

## 6. 身份、鉴权与匿名用户

### 6.1 用户身份策略

v1.1 不要求独立注册/登录，但必须有稳定匿名身份。

推荐流程：

1. App 首次启动生成 `installation_id`。
2. 客户端调用 `POST /app-users/bootstrap`。
3. 服务端创建或恢复 `app_user`。
4. 服务端返回 `app_user_id`、`access_token`、`expires_at`、`app_account_token`。
5. 如果是首次创建用户，服务端在同一事务内创建 `usage_balance`，并写入初始免费额度的 `credit_ledger.grant`。
6. 后续 API 使用 `Authorization: Bearer <access_token>`。

`installation_id` 只用于 bootstrap 和恢复，不作为权限凭证。

### 6.2 `app_account_token`

每个 `app_user` 持有一个稳定 UUID 格式的 `app_account_token`，用于 StoreKit 2 购买时传入 `Product.PurchaseOption.appAccountToken`。

服务端校验 Apple 交易时，必须确认交易中的 `appAccountToken` 与当前 `app_user.app_account_token` 一致，才能入账。

### 6.3 Token 策略

- `access_token` 由服务端签发，客户端存入 Keychain。
- 服务端只保存 token hash，不保存明文 token。
- token 过期后，客户端可重新调用 bootstrap 获取新 token。
- 删除用户全部数据时，必须撤销该用户所有 active token。

---

## 7. 计费、额度与 Ledger

### 7.1 计费单位

计费单位是 1 次 `training_session`，也就是一次完整训练闭环：

- 1 道问题
- 1 次首轮回答
- 1 次追问
- 1 次追问回答
- 1 份结构化反馈
- 1 次 redo 机会
- 若用户提交 redo，则尝试生成 1 份轻量 redo review

### 7.2 免费额度

- 每个 `app_user_id` 初始获得 2 次免费训练额度。
- 免费额度与用户绑定，不与简历绑定。
- 删除 App 后重新安装不应自动重置免费额度；是否能恢复取决于本地 token / installation 仍可用程度。v1.1 不承诺跨设备恢复免费额度。

### 7.3 付费额度

- Sprint Pack 购买后增加 `paid_session_credits_remaining`。
- v1.1 不做订阅，不做月度重置。
- 付费额度进入统一余额池。

### 7.4 扣费时机

推荐规则：

1. 创建训练会话时，检查余额并预留 1 个 session credit。
2. 问题生成成功后不立刻 consume，只保持 reserved。
3. 当 `feedback_payload` 生成成功并且 session 进入 `redo_available` 时，consume 该 credit。
4. 如果在 feedback 成功前发生系统错误，release 该 credit。
5. 如果用户在 feedback 前放弃，会话进入 `abandoned`，reserved credit 在 TTL 到期后 release。
6. 如果用户在 feedback 后跳过 redo，credit 保持 consumed，会话进入 `completed`。
7. 如果用户提交 redo 但 redo review 生成失败或校验失败，credit 保持 consumed，会话进入 `completed`。
8. redo 与 redo review 不额外扣费；redo review 暂不可用不退款、不 release。

这样既符合“完整训练闭环”付费定义，也避免用户通过多开会话无限刷题。

### 7.5 Active session 限制与 TTL

- 每个用户最多只能有 1 个 `active` session。
- active session 指任何未进入终态的 session；终态仅包括 `completed`、`abandoned`、`failed`。
- `redo_processing` 与 `redo_evaluating` 仍属于 active session，不能同时创建新 session。
- `completed` 包含 skip redo、redo review generated、redo review unavailable 三种 completion reason。
- `failed` 只用于 feedback 成功之前的系统失败，或任何导致主 feedback 无法交付的失败。
- 如果存在 active session，创建新 session 必须返回 `ACTIVE_SESSION_EXISTS`，并返回当前 `session_id`。
- feedback 前未完成会话的默认 TTL 为 24 小时。
- TTL 到期后，服务端可将 session 标记为 `abandoned` 并 release reserved credit。

### 7.6 Credit Ledger

所有额度变化必须先写入 `credit_ledger`，再更新 `usage_balance`。

`usage_balance` 是当前状态；`credit_ledger` 是审计来源。

---

## 8. Canonical Enum

### 8.1 `training_focus`

`training_focus` 在 API、服务端存储和 Prompt 结构化字段中必须使用 canonical enum；客户端展示使用 Display label。映射以 PRD v1 FR-05 为准：

| Canonical enum | Display label | 用户可见 |
|---|---|---|
| `ownership` | Ownership | 是 |
| `prioritization` | Prioritization | 是 |
| `cross_functional_influence` | Cross-functional Influence | 是 |
| `conflict_handling` | Conflict Handling | 是 |
| `failure_learning` | Failure / Learning | 是 |
| `ambiguity` | Ambiguity | 是 |

不得把 Display label 写入结构化字段或数据库枚举字段。

### 8.2 `behavioral_signal`

- `ownership`
- `prioritization`
- `cross_functional_influence`
- `conflict_handling`
- `failure_learning`
- `ambiguity`

### 8.3 `target_gap`

必须与 Prompt / Content Spec v1.1 一致：

- `question_fit`
- `action_specificity`
- `ownership_judgment`
- `decision_logic`
- `evidence_metrics`

### 8.4 `transcript_status`

`transcript_status` 表示 ASR 处理是否完成。

- `pending`
- `completed`
- `failed`

### 8.5 `transcript_quality_status`

`transcript_quality_status` 表示已完成转写后的质量或可用性判断。Data / API Spec 是该字段的 source of truth，Analytics、Client UX 和 QA 不得定义另一套同名枚举。

- `usable`
- `too_short`
- `silent`
- `non_english`
- `low_confidence`
- `failed`

组合规则：

- `usable` 表示 ASR completed and transcript usable；此时 `transcript_status = completed`。
- `too_short` / `silent` / `non_english` / `low_confidence` 表示 ASR completed but transcript not usable；此时 `transcript_status = completed`。
- `failed` 表示 ASR failed；此时 `transcript_status = failed`。
- `too_short` / `silent` / `non_english` / `low_confidence` 统一映射 `TRANSCRIPT_QUALITY_TOO_LOW`。
- `failed` 统一映射 `TRANSCRIPTION_FAILED`。
- `detected_language` 在可获取时必须保留；当 `transcript_quality_status = non_english` 时，应尽量返回实际检测语言，例如 `es`、`zh`。

### 8.6 `visible_assessment_status`

- `Strong`
- `Mixed`
- `Weak`

### 8.7 `improvement_status`

- `improved`
- `partially_improved`
- `not_improved`
- `regressed`

### 8.8 `completion_reason`

`completion_reason` 只在 `training_session.status = completed` 时必填。

- `redo_skipped`
- `redo_review_generated`
- `redo_review_unavailable`

---

## 9. 核心对象模型总览

v1.1 使用以下核心对象：

1. `app_user`
2. `auth_session`
3. `usage_balance`
4. `credit_ledger`
5. `resume_document`
6. `resume_profile`
7. `purchase_transaction`
8. `training_session`
9. `question_payload`
10. `answer_submission`
11. `follow_up_payload`
12. `feedback_payload`
13. `redo_submission`
14. `redo_review_payload`
15. `ai_generation_log`
16. `history_item`，可派生，不必单独落表

对象关系：

```text
app_user
  ├─ auth_session (0..n)
  ├─ usage_balance (1:1)
  ├─ credit_ledger (0..n)
  ├─ resume_document (1 active in v1.1)
  │    └─ resume_profile (1:1 active parse)
  ├─ purchase_transaction (0..n)
  └─ training_session (0..n)
       ├─ question_payload (1:1)
       ├─ answer_submission:first_answer (1:1)
       ├─ follow_up_payload (1:1)
       ├─ answer_submission:followup_answer (1:1)
       ├─ feedback_payload (1:1)
       ├─ redo_submission (0..1)
       └─ redo_review_payload (0..1)
```

---

## 10. 通用 AI Payload 元数据

所有 AI payload 对象必须包含以下元数据：

```json
{
  "prompt_version": "prompt_content_v1.1",
  "schema_version": "data_api_v1.1",
  "model_provider": "openai",
  "model_name": "string",
  "generation_status": "succeeded",
  "validation_status": "passed",
  "attempt_count": 1,
  "validation_errors": [],
  "generated_at": "2026-04-21T10:05:08Z",
  "validated_at": "2026-04-21T10:05:09Z"
}
```

### `generation_status`

- `pending`
- `succeeded`
- `failed`

### `validation_status`

- `pending`
- `passed`
- `failed`
- `repaired`

---

## 11. 核心对象定义

### 11.1 `app_user`

用途：匿名用户主对象。

```json
{
  "app_user_id": "usr_123",
  "app_account_token": "00000000-0000-4000-8000-000000000000",
  "platform": "ios",
  "locale": "en-US",
  "created_at": "2026-04-21T10:00:00Z",
  "last_active_at": "2026-04-21T10:20:00Z",
  "status": "active",
  "deleted_at": null
}
```

`status` enum:

- `active`
- `deleted`
- `blocked`

### 11.2 `auth_session`

用途：匿名 token 与设备安装的绑定记录。

```json
{
  "auth_session_id": "auth_123",
  "app_user_id": "usr_123",
  "installation_id": "uuid-string",
  "access_token_hash": "sha256-token-hash",
  "platform": "ios",
  "app_version": "1.0.0",
  "created_at": "2026-04-21T10:00:00Z",
  "expires_at": "2026-05-21T10:00:00Z",
  "revoked_at": null
}
```

### 11.3 `usage_balance`

用途：当前可用额度快照。

```json
{
  "app_user_id": "usr_123",
  "free_session_credits_remaining": 2,
  "paid_session_credits_remaining": 0,
  "reserved_session_credits": 0,
  "updated_at": "2026-04-21T10:20:00Z"
}
```

### 11.4 `credit_ledger`

用途：不可变 credit 流水。

```json
{
  "ledger_id": "led_123",
  "app_user_id": "usr_123",
  "session_id": "ses_123",
  "purchase_id": null,
  "credit_kind": "free",
  "entry_type": "reserve",
  "delta": -1,
  "balance_after": {
    "free_session_credits_remaining": 1,
    "paid_session_credits_remaining": 0,
    "reserved_session_credits": 1
  },
  "reason": "training_session_created",
  "idempotency_key": "idem_abc",
  "created_at": "2026-04-21T10:05:00Z"
}
```

`credit_kind` enum:

- `free`
- `paid`

`entry_type` enum:

- `grant`
- `reserve`
- `consume`
- `release`
- `refund_adjustment`
- `admin_adjustment`

规则：

- `grant` 用于初始免费额度和 IAP 入账。
- `reserve` 在创建训练会话时写入。
- `consume` 在 feedback 成功生成时写入。
- `release` 在系统失败或 TTL 放弃时写入。
- 同一个 `idempotency_key` 在同一用户和同一接口下只能生效一次。

### 11.5 `resume_document`

用途：表示当前上传的简历文件及处理状态。

```json
{
  "resume_id": "res_123",
  "app_user_id": "usr_123",
  "file_name": "resume_jane_doe.pdf",
  "mime_type": "application/pdf",
  "storage_key": "resumes/usr_123/res_123.pdf",
  "source_language": "en",
  "status": "ready",
  "profile_quality_status": "usable",
  "failure_code": null,
  "is_active": true,
  "uploaded_at": "2026-04-21T10:01:00Z",
  "parsed_at": "2026-04-21T10:01:30Z",
  "archived_at": null,
  "deleted_at": null
}
```

`status` enum:

- `uploaded`
- `parsing`
- `ready`
- `failed`
- `archived`
- `deleted`

`profile_quality_status` enum:

- `usable`
- `limited`
- `unusable`

规则：

- `usable` 与 `limited` 可进入训练；`unusable` 不允许创建训练会话。
- 新简历上传成功后，旧简历转为 `archived`。
- 删除活跃简历后，用户必须重新上传简历才能训练。

### 11.6 `resume_profile`

用途：保存 Resume Parse 结构化结果，直接承接 Prompt / Content Spec v1.1。

```json
{
  "resume_profile_id": "rpf_123",
  "resume_id": "res_123",
  "prompt_version": "prompt_content_v1.1",
  "schema_version": "data_api_v1.1",
  "model_provider": "openai",
  "model_name": "string",
  "generation_status": "succeeded",
  "validation_status": "passed",
  "attempt_count": 1,
  "validation_errors": [],
  "candidate_summary": "string",
  "likely_role_track": ["Product Manager"],
  "likely_seniority": "mid-level",
  "top_strength_signals": ["ownership", "cross_functional_influence"],
  "experience_units": [
    {
      "experience_id": "exp_1",
      "company": "string",
      "title": "string",
      "time_range": "string",
      "context_summary": "string",
      "candidate_actions": ["string"],
      "outcomes": ["string"],
      "metrics": ["string"],
      "stakeholders": ["string"],
      "behavioral_signals": ["ownership", "prioritization"],
      "questionability": "high",
      "source_snippets": ["string"]
    }
  ],
  "recommended_anchor_experience_ids": ["exp_1"],
  "global_signal_gaps": ["weak metrics"],
  "insufficient_evidence_reasons": [],
  "generated_at": "2026-04-21T10:01:30Z",
  "validated_at": "2026-04-21T10:01:31Z",
  "created_at": "2026-04-21T10:01:31Z"
}
```

规则：

- 至少需要 1 个 `questionability = high` 的 experience unit 才能标记为 `usable`。
- 若只有 1 个强锚点，可标记为 `limited`，仍允许训练，但 UI 应提示训练覆盖有限。
- 若没有可训练锚点，`resume_document.profile_quality_status = unusable`，训练会话创建返回 `RESUME_PROFILE_UNUSABLE`。
- `source_snippets` 必须存储以支持 grounding 回溯，但默认不返回给普通 UI。
- `source_snippets` 单条最长 220 字符，最多 5 条。
- `source_snippets` 入库前必须 redaction 掉 email、电话号码、住址、LinkedIn URL、GitHub URL 等直接个人标识。
- `source_snippets` 不得进入 analytics event，也不得在客户端默认响应中返回。

### 11.7 `purchase_transaction`

用途：记录 Apple IAP 交易与权益入账结果。

```json
{
  "purchase_id": "pur_123",
  "app_user_id": "usr_123",
  "store": "apple_iap",
  "product_id": "coach_sprint_pack_01",
  "transaction_id": "apple_transaction_id",
  "original_transaction_id": "apple_original_transaction_id",
  "app_account_token": "00000000-0000-4000-8000-000000000000",
  "environment": "sandbox",
  "signed_transaction_info": "jws-string",
  "session_credits_granted": 5,
  "status": "verified",
  "idempotency_key": "idem_purchase_123",
  "purchased_at": "2026-04-21T11:00:00Z",
  "verified_at": "2026-04-21T11:00:05Z"
}
```

`status` enum:

- `pending`
- `verified`
- `rejected`
- `refunded`

规则：

- `transaction_id` 必须全局唯一。
- 服务端必须校验交易签名、product、environment、ownership 和 `app_account_token`。
- 已入账交易重复上报时，返回已有 `purchase_id` 和当前余额，不重复 grant。

### 11.8 `training_session`

用途：一次完整可计费训练会话。

```json
{
  "session_id": "ses_123",
  "app_user_id": "usr_123",
  "resume_id": "res_123",
  "resume_profile_id": "rpf_123",
  "billing_source": "free",
  "credit_state": "reserved",
  "training_focus": "ownership",
  "status": "redo_available",
  "completion_reason": null,
  "redo_review_failure_code": null,
  "question_payload_id": "q_123",
  "first_answer_submission_id": "ans_123",
  "follow_up_payload_id": "f_123",
  "followup_answer_submission_id": "ans_124",
  "feedback_payload_id": "fb_123",
  "redo_submission_id": null,
  "redo_review_payload_id": null,
  "started_at": "2026-04-21T10:05:00Z",
  "expires_at": "2026-04-22T10:05:00Z",
  "completed_at": null,
  "failed_at": null
}
```

`billing_source` enum:

- `free`
- `paid`

`credit_state` enum:

- `reserved`
- `consumed`
- `released`

`status` enum:

- `created`
- `question_generating`
- `waiting_first_answer`
- `first_answer_processing`
- `followup_generating`
- `waiting_followup_answer`
- `followup_answer_processing`
- `feedback_generating`
- `redo_available`
- `redo_processing`
- `redo_evaluating`
- `completed`
- `abandoned`
- `failed`

终态规则：

- `completed` 表示主 feedback 已交付，credit 已 consumed。
- `completion_reason = redo_skipped`：用户主动跳过 redo。
- `completion_reason = redo_review_generated`：用户提交 redo，且 redo review 生成并校验通过。
- `completion_reason = redo_review_unavailable`：用户提交 redo，但 redo review 生成失败或校验失败；此时 `redo_submission_id != null`、`redo_review_payload_id = null`，可选写入 `redo_review_failure_code`。
- `failed` 只用于 feedback 成功之前的系统失败，或任何导致主 feedback 无法交付的失败；feedback 成功后 session 不得再进入 `failed`。

### 11.9 `question_payload`

用途：保存一次训练的问题生成结果。

```json
{
  "question_payload_id": "q_123",
  "session_id": "ses_123",
  "prompt_version": "prompt_content_v1.1",
  "schema_version": "data_api_v1.1",
  "model_provider": "openai",
  "model_name": "string",
  "generation_status": "succeeded",
  "validation_status": "passed",
  "attempt_count": 1,
  "validation_errors": [],
  "question_id": "q_001",
  "anchor_experience_ids": ["exp_2"],
  "training_focus": "ownership",
  "resume_anchor_hint": "Based on your launch prioritization work,",
  "question_text": "Tell me about a time when you had to make a high-stakes prioritization decision with incomplete information.",
  "internal_rationale": "Anchored to launch prioritization work in exp_2; strong ownership and tradeoff potential.",
  "expected_signal_targets": ["ownership", "decision_logic", "evidence_metrics"],
  "generated_at": "2026-04-21T10:05:08Z",
  "validated_at": "2026-04-21T10:05:09Z",
  "created_at": "2026-04-21T10:05:09Z"
}
```

校验：

- `question_text` 非空。
- 词数 <= 35。
- 问号数 <= 1。
- `anchor_experience_ids` 至少 1 个。
- `resume_anchor_hint` 非空，最长 120 字符，不得包含问号或直接个人标识。

### 11.10 `answer_submission`

用途：表示首轮回答或追问回答。

```json
{
  "answer_submission_id": "ans_123",
  "session_id": "ses_123",
  "answer_type": "first_answer",
  "audio_storage_key": "audio/usr_123/ses_123/first_answer.m4a",
  "duration_seconds": 72,
  "transcript_text": "string",
  "transcript_status": "completed",
  "transcript_confidence": 0.92,
  "transcript_quality_status": "usable",
  "detected_language": "en",
  "word_count": 148,
  "submitted_at": "2026-04-21T10:06:10Z",
  "transcribed_at": "2026-04-21T10:06:16Z"
}
```

`answer_type` enum:

- `first_answer`
- `followup_answer`

`transcript_status` 使用第 8.4 节 canonical enum。

`transcript_quality_status` 使用第 8.5 节 canonical enum。

规则：

- `transcript_status` 表示 ASR 处理是否完成；`transcript_quality_status` 表示已完成转写后的质量或可用性判断。
- 当 `transcript_quality_status` 为 `usable` / `too_short` / `silent` / `non_english` / `low_confidence` 时，`transcript_status` 必须为 `completed`。
- 当 `transcript_quality_status = failed` 时，`transcript_status` 必须为 `failed`。
- `transcript_quality_status != usable` 时，不应继续生成追问或反馈。
- `too_short` / `silent` / `non_english` / `low_confidence` 返回 `TRANSCRIPT_QUALITY_TOO_LOW`，让客户端提示用户重录。
- `failed` 返回 `TRANSCRIPTION_FAILED`，让客户端提示用户重录。
- `detected_language` 在可获取时必须保留；当 `transcript_quality_status = non_english` 时，应尽量返回实际检测语言。

### 11.11 `follow_up_payload`

用途：保存一次追问生成结果。

```json
{
  "follow_up_payload_id": "f_123",
  "session_id": "ses_123",
  "prompt_version": "prompt_content_v1.1",
  "schema_version": "data_api_v1.1",
  "model_provider": "openai",
  "model_name": "string",
  "generation_status": "succeeded",
  "validation_status": "passed",
  "attempt_count": 1,
  "validation_errors": [],
  "follow_up_id": "f_001",
  "target_gap": "ownership_judgment",
  "follow_up_text": "What specific decision did you personally make at that point?",
  "internal_rationale": "The first answer described team activity but did not establish the candidate's personal judgment.",
  "generated_at": "2026-04-21T10:06:18Z",
  "validated_at": "2026-04-21T10:06:19Z",
  "created_at": "2026-04-21T10:06:19Z"
}
```

校验：

- `target_gap` 必须属于 canonical enum。
- `follow_up_text` 词数 <= 28。
- `follow_up_text` 必须正好 1 个问号。
- 不得出现 `and what`、`and how`、`and why`、`and which` 拼接第二问。

### 11.12 `feedback_payload`

用途：保存一次完整反馈结果。

```json
{
  "feedback_payload_id": "fb_123",
  "session_id": "ses_123",
  "prompt_version": "prompt_content_v1.1",
  "schema_version": "data_api_v1.1",
  "model_provider": "openai",
  "model_name": "string",
  "generation_status": "succeeded",
  "validation_status": "passed",
  "attempt_count": 1,
  "validation_errors": [],
  "internal_scores": {
    "question_fit": 4,
    "resume_grounding": 4,
    "story_selection": 4,
    "structure": 3,
    "action_specificity": 2,
    "ownership_judgment": 2,
    "decision_logic": 3,
    "evidence_metrics": 2,
    "outcome_reflection": 3,
    "followup_robustness": 2
  },
  "visible_assessments": {
    "answered_the_question": "Strong",
    "story_fit": "Strong",
    "personal_ownership": "Weak",
    "evidence_and_outcome": "Mixed",
    "holds_up_under_follow_up": "Weak"
  },
  "strongest_signal": "You picked a relevant example with real business context and a clear decision point.",
  "biggest_gap": "You still did not make your personal ownership explicit enough.",
  "why_it_matters": "In a behavioral interview, a strong story is not enough if the interviewer cannot tell what you personally decided or drove.",
  "redo_priority": "On your next attempt, spend one sentence on the context, then focus on the decision you personally made, the tradeoff you considered, and the measurable result.",
  "redo_outline": [
    "Set up the context in one sentence.",
    "State the decision you personally owned.",
    "Explain the tradeoff and why you chose that path.",
    "Close with the result and what it proved."
  ],
  "generated_at": "2026-04-21T10:07:20Z",
  "validated_at": "2026-04-21T10:07:21Z",
  "created_at": "2026-04-21T10:07:21Z"
}
```

规则：

- 不返回总分字段。
- 10 维 `internal_scores` 必须完整。
- 5 项 `visible_assessments` 必须完整，但不得由模型直接生成；服务端必须按 Prompt / Content Spec v1.1 第 12 节从 `internal_scores` 固定计算后写入。
- `redo_outline` 至少 3 条。

### 11.13 `redo_submission`

用途：记录用户对同一题目的 guided redo。

```json
{
  "redo_submission_id": "redo_123",
  "session_id": "ses_123",
  "audio_storage_key": "audio/usr_123/ses_123/redo_answer.m4a",
  "duration_seconds": 80,
  "transcript_text": "string",
  "transcript_status": "completed",
  "transcript_confidence": 0.91,
  "transcript_quality_status": "usable",
  "detected_language": "en",
  "word_count": 162,
  "submitted_at": "2026-04-21T10:08:00Z",
  "transcribed_at": "2026-04-21T10:08:06Z"
}
```

规则：

- `redo_submission` 不产生新的 `training_session`。
- 不额外扣费。
- `transcript_status` 与 `transcript_quality_status` 使用第 8.4 / 8.5 节 canonical enum 和组合规则。
- 若 `transcript_quality_status != usable`，不生成 `redo_review_payload`，客户端提示重录。

### 11.14 `redo_review_payload`

用途：承接 Prompt / Content Spec v1.1 的 Redo Evaluate 输出。

```json
{
  "redo_review_payload_id": "rr_123",
  "session_id": "ses_123",
  "redo_submission_id": "redo_123",
  "prompt_version": "prompt_content_v1.1",
  "schema_version": "data_api_v1.1",
  "model_provider": "openai",
  "model_name": "string",
  "generation_status": "succeeded",
  "validation_status": "passed",
  "attempt_count": 1,
  "validation_errors": [],
  "redo_review": {
    "improvement_status": "partially_improved",
    "updated_internal_scores": {
      "question_fit": 4,
      "resume_grounding": 4,
      "story_selection": 4,
      "structure": 4,
      "action_specificity": 3,
      "ownership_judgment": 3,
      "decision_logic": 3,
      "evidence_metrics": 3,
      "outcome_reflection": 3,
      "followup_robustness": 3
    },
    "updated_visible_assessments": {
      "answered_the_question": "Strong",
      "story_fit": "Strong",
      "personal_ownership": "Mixed",
      "evidence_and_outcome": "Mixed",
      "holds_up_under_follow_up": "Mixed"
    },
    "what_improved": "Your redo made your personal decision clearer and reduced team-level vagueness.",
    "still_missing": "You still need one stronger measurable result to fully support the story.",
    "final_takeaway": "This version is more interview-ready because the interviewer can now tell what you personally drove.",
    "next_practice_priority": "On your next practice round, make the outcome more concrete with one metric or business result."
  },
  "generated_at": "2026-04-21T10:08:12Z",
  "validated_at": "2026-04-21T10:08:13Z",
  "created_at": "2026-04-21T10:08:13Z"
}
```

校验：

- `improvement_status` 必须属于 canonical enum。
- `updated_internal_scores` 必须完整。
- `updated_visible_assessments` 必须完整，但不得由模型直接生成；服务端必须按 Prompt / Content Spec v1.1 第 12 节从 `updated_internal_scores` 固定计算后写入。
- `what_improved`、`still_missing`、`final_takeaway` 非空。
- 不得返回新追问。
- 不得返回第二份完整 10 维反馈报告。

### 11.15 `ai_generation_log`

用途：调试期追踪 AI 生成、校验和重试过程。v1.1 建议落表，但不向普通用户展示。

```json
{
  "ai_generation_log_id": "agl_123",
  "app_user_id": "usr_123",
  "session_id": "ses_123",
  "step": "follow_up_generate",
  "prompt_version": "prompt_content_v1.1",
  "schema_version": "data_api_v1.1",
  "model_provider": "openai",
  "model_name": "string",
  "input_hash": "sha256",
  "output_ref_type": "follow_up_payload",
  "output_ref_id": "f_123",
  "attempt_count": 1,
  "status": "succeeded",
  "validation_errors": [],
  "created_at": "2026-04-21T10:06:18Z"
}
```

---

## 12. 数据存储、保留与删除

### 12.1 服务端数据库保存

保存：

- `app_user`
- `auth_session`
- `usage_balance`
- `credit_ledger`
- `resume_document` 元数据
- `resume_profile`
- `purchase_transaction`
- `training_session`
- `question_payload`
- `answer_submission` 文本与元数据
- `follow_up_payload`
- `feedback_payload`
- `redo_submission` 文本与元数据
- `redo_review_payload`
- `ai_generation_log`

### 12.2 对象存储保存

保存：

- 原始简历文件。
- 首轮回答音频。
- 追问回答音频。
- redo 音频。

### 12.3 默认保留策略

v1.1 推荐默认策略：

- 原始简历文件：活跃期间保留；用户删除或替换后 30 天内硬删除。
- `resume_profile`：活跃期间保留；用户删除全部数据时硬删除。
- 原始音频：默认保留 30 天，用于用户回放和质量排查。
- 转写文本、AI payload、训练历史：默认保留最近 10 次历史；超过 UI 返回范围的数据可保留最多 180 天用于用户恢复和质量审计。
- `credit_ledger` 与 `purchase_transaction`：按财务和审计需要保留，不随普通历史清理删除；用户删除数据时应解除与可识别训练内容的关联。

### 12.4 删除能力

v1.1 必须支持：

- 删除活跃简历。
- 删除单次训练会话。
- 删除当前匿名用户的训练内容与简历数据。

删除用户全部数据时：

1. 撤销所有 `auth_session`。
2. 删除对象存储中的简历和音频。
3. 删除或匿名化训练文本、AI payload 和历史记录。
4. 保留必要的 purchase / ledger 审计数据，但不保留可识别面试内容。

---

## 13. API 通用约定

### 13.1 Base URL

```text
/api/v1
```

### 13.2 鉴权

除 bootstrap 外，所有接口必须带：

```text
Authorization: Bearer <access_token>
```

### 13.3 幂等

所有写接口必须支持：

```text
Idempotency-Key: <client-generated-uuid>
```

适用接口：

- `POST /app-users/bootstrap`
- `POST /resumes`
- `DELETE /resumes/active`
- `POST /training-sessions`
- `POST /training-sessions/{session_id}/first-answer`
- `POST /training-sessions/{session_id}/follow-up-answer`
- `POST /training-sessions/{session_id}/redo`
- `POST /training-sessions/{session_id}/skip-redo`
- `POST /training-sessions/{session_id}/abandon`
- `POST /billing/apple/verify`
- `POST /billing/apple/restore`
- `DELETE /training-sessions/{session_id}`
- `DELETE /app-users/me/data`

### 13.4 通用响应结构

成功：

```json
{
  "request_id": "req_123",
  "data": {},
  "error": null
}
```

失败：

```json
{
  "request_id": "req_123",
  "data": null,
  "error": {
    "code": "TRAINING_SESSION_NOT_READY",
    "message": "The training session is not ready for this step.",
    "details": {}
  }
}
```

### 13.5 时间格式

统一使用 ISO-8601 UTC：

```text
2026-04-21T10:05:08Z
```

### 13.6 ID 前缀

- `usr_`
- `auth_`
- `led_`
- `res_`
- `rpf_`
- `ses_`
- `q_`
- `ans_`
- `f_`
- `fb_`
- `redo_`
- `rr_`
- `pur_`
- `agl_`

### 13.7 OpenAPI 最小契约片段

本节给出开发联调必须落地的 OpenAPI path / header 索引。所有响应必须使用第 13.4 节的 `request_id / data / error` envelope；第 14 章只补充每个 endpoint 的业务语义、请求字段和 `data` 内容。训练会话读取统一使用 `GET /training-sessions/{session_id}`，不单独提供 `/follow-up`、`/feedback`、`/redo-review` 三个专项读接口。

机器可读版本维护在 `docs/api/openapi.yaml`。该文件是联调用 path / header / delete mode 最小索引；详细 request / response examples 仍以本章为准。修改 endpoint 或写接口幂等要求时，必须同步更新本节和 `docs/api/openapi.yaml`。

注意：Prompt / Content Spec v1.1 第 14 节的 `FeedbackPayload` 与 `RedoReviewPayload` 是 AI 模型输出契约；Data / API 层保存和返回时会额外加入服务端计算的 `visible_assessments` / `updated_visible_assessments`。

```yaml
openapi: 3.1.0
info:
  title: AI Behavioral Interview Coach API
  version: 1.1.0
servers:
  - url: /api/v1
security:
  - bearerAuth: []
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
  parameters:
    IdempotencyKey:
      name: Idempotency-Key
      in: header
      required: true
      schema:
        type: string
        minLength: 8
  schemas:
    ResumeProfile:
      $ref: ./schemas/prompt/resume-profile.schema.json
    QuestionPayload:
      $ref: ./schemas/prompt/question-payload.schema.json
    FollowUpPayload:
      $ref: ./schemas/prompt/follow-up-payload.schema.json
    FeedbackPayload:
      $ref: ./schemas/prompt/feedback-payload.schema.json
    RedoReviewPayload:
      $ref: ./schemas/prompt/redo-review-payload.schema.json
    UsageBalance:
      type: object
      required:
        - free_session_credits_remaining
        - paid_session_credits_remaining
        - reserved_session_credits
      properties:
        free_session_credits_remaining:
          type: integer
          minimum: 0
        paid_session_credits_remaining:
          type: integer
          minimum: 0
        reserved_session_credits:
          type: integer
          minimum: 0
    ApiError:
      type: object
      required: [code, message]
      properties:
        code:
          type: string
        message:
          type: string
        details:
          type: object
    ApiResponse:
      type: object
      required: [request_id, data, error]
      properties:
        request_id:
          type: string
        data:
          description: Endpoint-specific payload, or null on failure.
        error:
          oneOf:
            - $ref: '#/components/schemas/ApiError'
            - type: 'null'
paths:
  /app-users/bootstrap:
    post:
      security: []
      summary: Create or restore anonymous user
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
  /home:
    get:
      summary: Get home screen aggregate context
  /resumes:
    post:
      summary: Upload active resume
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
  /resumes/{resume_id}:
    get:
      summary: Get resume parsing status and summary
  /resumes/active:
    get:
      summary: Get active resume
    delete:
      summary: Delete active resume
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
  /training-sessions:
    post:
      summary: Create training session and reserve one credit
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
  /training-sessions/{session_id}:
    get:
      summary: Get current or historical session detail, including question, follow-up, feedback, and redo review when available
    delete:
      summary: Delete visible training content
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
  /training-sessions/history:
    get:
      summary: Get recent training history summaries
  /training-sessions/{session_id}/first-answer:
    post:
      summary: Submit first answer audio
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
  /training-sessions/{session_id}/follow-up-answer:
    post:
      summary: Submit follow-up answer audio
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
  /training-sessions/{session_id}/redo:
    post:
      summary: Submit redo answer and start redo evaluation
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
  /training-sessions/{session_id}/skip-redo:
    post:
      summary: Skip redo and complete session
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
  /training-sessions/{session_id}/abandon:
    post:
      summary: Abandon session before feedback and release reserved credit when eligible
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
  /billing/entitlement:
    get:
      summary: Get usage balance and purchasable products
  /billing/apple/verify:
    post:
      summary: Verify Apple IAP transaction and grant credits
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
  /billing/apple/restore:
    post:
      summary: Restore Apple IAP transactions
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
  /app-users/me/data:
    delete:
      summary: Delete current anonymous user's training and resume data
      parameters:
        - $ref: '#/components/parameters/IdempotencyKey'
```

---

## 14. API 列表

本章所有响应示例均为完整 HTTP JSON body，必须使用第 13.4 节 envelope。`data` 内部才是 endpoint-specific payload。训练会话读取统一使用 `GET /training-sessions/{session_id}`；客户端通过轮询或刷新该聚合接口获得 question、follow-up、feedback、redo review，不另设 `/follow-up`、`/feedback`、`/redo-review` 专项读接口。

### 14.1 Bootstrap

#### POST `/app-users/bootstrap`

作用：创建或恢复匿名用户并返回 token。

请求：

```json
{
  "installation_id": "uuid-string",
  "platform": "ios",
  "locale": "en-US",
  "app_version": "1.0.0"
}
```

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "app_user_id": "usr_123",
    "access_token": "opaque-token",
    "expires_at": "2026-05-21T10:00:00Z",
    "app_account_token": "00000000-0000-4000-8000-000000000000",
    "usage_balance": {
      "free_session_credits_remaining": 2,
      "paid_session_credits_remaining": 0,
      "reserved_session_credits": 0
    },
    "active_resume": null,
    "active_session": null
  },
  "error": null
}
```

### 14.2 首页上下文

#### GET `/home`

作用：返回首页所需最小聚合数据。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "app_user_id": "usr_123",
    "usage_balance": {
      "free_session_credits_remaining": 1,
      "paid_session_credits_remaining": 0,
      "reserved_session_credits": 0
    },
    "active_resume": {
      "resume_id": "res_123",
      "status": "ready",
      "profile_quality_status": "usable",
      "file_name": "resume_jane_doe.pdf"
    },
    "active_session": {
      "session_id": "ses_123",
      "status": "waiting_first_answer",
      "question_text": "Tell me about a time..."
    },
    "last_training_summary": {
      "session_id": "ses_122",
      "question_text": "Tell me about a time...",
      "completed_at": "2026-04-20T08:00:00Z"
    }
  },
  "error": null
}
```

### 14.3 简历

#### POST `/resumes`

作用：上传英文简历并启动解析。

请求：`multipart/form-data`

- `file`
- `source_language=en`

文件约束：

- 支持 `application/pdf` 与 `.docx`
- 最大 5 MB
- 推荐最多 5 页；超过 5 页可继续解析，但服务端可标记为 `profile_quality_status = limited`
- 若文本提取失败，返回 `RESUME_PARSE_FAILED`
- 若文件类型不支持，返回 `UNSUPPORTED_FILE_TYPE`

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "resume_id": "res_123",
    "status": "parsing",
    "is_active": true
  },
  "error": null
}
```

#### GET `/resumes/{resume_id}`

作用：查询简历状态与解析摘要。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "resume_id": "res_123",
    "status": "ready",
    "profile_quality_status": "usable",
    "is_active": true,
    "resume_profile_summary": {
      "candidate_summary": "Product manager with 6 years of experience...",
      "recommended_anchor_experience_count": 3,
      "top_strength_signals": ["ownership", "prioritization"],
      "insufficient_evidence_reasons": []
    }
  },
  "error": null
}
```

#### GET `/resumes/active`

作用：获取当前活跃简历。无活跃简历时 `data.active_resume = null`。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "active_resume": {
      "resume_id": "res_123",
      "status": "ready",
      "profile_quality_status": "usable",
      "file_name": "resume_jane_doe.pdf"
    }
  },
  "error": null
}
```

#### DELETE `/resumes/active`

作用：删除当前活跃简历及其原始文件，阻止后续训练。由于历史问题、反馈和 redo review 可能包含简历派生内容，客户端必须明确选择删除模式。

请求：

```json
{
  "delete_mode": "resume_only_redacted_history"
}
```

`delete_mode` enum:

- `resume_only_redacted_history`：删除原始简历、`resume_profile` 和 `source_snippets`；保留历史摘要，但必须移除或重写可识别的简历派生细节。
- `resume_and_linked_training`：删除原始简历、`resume_profile`、`source_snippets`、与该简历关联的训练文本、AI payload 和音频；保留必要的 purchase / ledger 审计记录但解除训练内容关联。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "deleted": true,
    "delete_mode": "resume_only_redacted_history",
    "active_resume": null,
    "removed": [
      "resume_file",
      "resume_profile",
      "source_snippets"
    ],
    "retained": [
      "redacted_history_summaries",
      "purchase_transaction",
      "credit_ledger"
    ]
  },
  "error": null
}
```

### 14.4 创建训练会话

#### POST `/training-sessions`

作用：创建训练会话，预留 credit，并启动 Question Generate。

请求：

```json
{
  "training_focus": "ownership"
}
```

服务端流程：

1. 验证 access token。
2. 检查是否存在 `profile_quality_status != unusable` 的活跃简历。
3. 检查是否已有 active session。
4. 检查可用免费 / 付费额度。
5. 写入 `credit_ledger.reserve`。
6. 创建 `training_session`。
7. 启动 Question Generate。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "session_id": "ses_123",
    "status": "question_generating",
    "billing_source": "free",
    "credit_state": "reserved"
  },
  "error": null
}
```

### 14.5 训练会话详情

#### GET `/training-sessions/{session_id}`

作用：统一查询当前会话状态和可展示内容。历史详情页也使用该接口。该接口是 question、follow-up、feedback、redo review 的唯一读取入口。

响应示例：

```json
{
  "request_id": "req_123",
  "data": {
    "session_id": "ses_123",
    "status": "redo_available",
    "completion_reason": null,
    "billing_source": "free",
    "credit_state": "consumed",
    "training_focus": "ownership",
    "redo_submitted": false,
    "redo_review_failure_code": null,
    "question": {
      "resume_anchor_hint": "Based on your launch prioritization work,",
      "question_text": "Tell me about a time when you had to make a high-stakes prioritization decision with incomplete information.",
      "training_focus": "ownership"
    },
    "follow_up": {
      "follow_up_text": "What specific decision did you personally make at that point?",
      "target_gap": "ownership_judgment"
    },
    "feedback": {
      "visible_assessments": {
        "answered_the_question": "Strong",
        "story_fit": "Strong",
        "personal_ownership": "Weak",
        "evidence_and_outcome": "Mixed",
        "holds_up_under_follow_up": "Weak"
      },
      "strongest_signal": "You picked a relevant example with real business context and a clear decision point.",
      "biggest_gap": "You still did not make your personal ownership explicit enough.",
      "why_it_matters": "In a behavioral interview, a strong story is not enough if the interviewer cannot tell what you personally decided or drove.",
      "redo_priority": "On your next attempt, spend one sentence on the context, then focus on the decision you personally made, the tradeoff you considered, and the measurable result.",
      "redo_outline": [
        "Set up the context in one sentence.",
        "State the decision you personally owned.",
        "Explain the tradeoff and why you chose that path.",
        "Close with the result and what it proved."
      ]
    },
    "redo_review": null,
    "usage_balance": {
      "free_session_credits_remaining": 1,
      "paid_session_credits_remaining": 0,
      "reserved_session_credits": 0
    }
  },
  "error": null
}
```

Response view 规则：

- `completion_reason` 仅在 `status = completed` 时非空。
- `completion_reason = redo_review_unavailable` 时，必须返回 `redo_submitted = true`、`redo_review = null`，并继续返回原 `feedback`。
- `redo_review_failure_code` 可选，仅用于客户端提示、日志和 analytics 归因。
- `status = completed` 的 session 不再属于 active session，用户可以开始下一次训练。

### 14.6 提交首轮回答

#### POST `/training-sessions/{session_id}/first-answer`

作用：提交首轮回答音频，启动转写与 Follow-up Generate。

请求：`multipart/form-data`

- `audio_file`
- `duration_seconds`

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "session_id": "ses_123",
    "status": "first_answer_processing"
  },
  "error": null
}
```

如果转写质量不可用，session 停留在 `waiting_first_answer`，返回可重录状态：

```json
{
  "request_id": "req_123",
  "data": {
    "session_id": "ses_123",
    "status": "waiting_first_answer",
    "transcript_status": "completed",
    "transcript_quality_status": "too_short",
    "error_code": "TRANSCRIPT_QUALITY_TOO_LOW",
    "detected_language": "en"
  },
  "error": null
}
```

首轮回答转写失败或质量不可用时：

- `too_short` / `silent` / `non_english` / `low_confidence`：session 回到或停留在 `waiting_first_answer`，`transcript_status = completed`，返回 `TRANSCRIPT_QUALITY_TOO_LOW`。
- `failed`：session 回到或停留在 `waiting_first_answer`，`transcript_status = failed`，返回 `TRANSCRIPTION_FAILED`。
- `transcript_quality_status != usable` 时，不进入 Follow-up Generate。

### 14.7 提交追问回答

#### POST `/training-sessions/{session_id}/follow-up-answer`

作用：提交追问回答音频，启动转写与 Feedback Generate。

请求：`multipart/form-data`

- `audio_file`
- `duration_seconds`

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "session_id": "ses_123",
    "status": "followup_answer_processing"
  },
  "error": null
}
```

如果转写质量不可用，session 停留在 `waiting_followup_answer`，返回可重录状态：

```json
{
  "request_id": "req_123",
  "data": {
    "session_id": "ses_123",
    "status": "waiting_followup_answer",
    "transcript_status": "completed",
    "transcript_quality_status": "non_english",
    "error_code": "TRANSCRIPT_QUALITY_TOO_LOW",
    "detected_language": "es"
  },
  "error": null
}
```

追问回答转写失败或质量不可用时：

- `too_short` / `silent` / `non_english` / `low_confidence`：session 回到或停留在 `waiting_followup_answer`，`transcript_status = completed`，返回 `TRANSCRIPT_QUALITY_TOO_LOW`。
- `failed`：session 回到或停留在 `waiting_followup_answer`，`transcript_status = failed`，返回 `TRANSCRIPTION_FAILED`。
- `transcript_quality_status != usable` 时，不进入 Feedback Generate，不 consume credit。

反馈成功生成后：

- session 进入 `redo_available`。
- credit 从 `reserved` 变为 `consumed`。
- 写入 `credit_ledger.consume`。
- 客户端通过 `GET /training-sessions/{session_id}` 获取 `feedback`。

### 14.8 提交 redo

#### POST `/training-sessions/{session_id}/redo`

作用：提交同一题目的 redo 音频，启动转写与 Redo Evaluate。

请求：`multipart/form-data`

- `audio_file`
- `duration_seconds`

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "session_id": "ses_123",
    "status": "redo_processing",
    "redo_submitted": true
  },
  "error": null
}
```

如果 redo 转写失败，session 回到 `redo_available`，返回可重录状态：

```json
{
  "request_id": "req_123",
  "data": {
    "session_id": "ses_123",
    "status": "redo_available",
    "transcript_status": "failed",
    "transcript_quality_status": "failed",
    "error_code": "TRANSCRIPTION_FAILED",
    "detected_language": null
  },
  "error": null
}
```

redo 转写失败或质量不可用时：

- `too_short` / `silent` / `non_english` / `low_confidence`：session 回到 `redo_available`，`transcript_status = completed`，返回 `TRANSCRIPT_QUALITY_TOO_LOW`。
- `failed`：session 回到 `redo_available`，`transcript_status = failed`，返回 `TRANSCRIPTION_FAILED`。
- `transcript_quality_status != usable` 时，不进入 Redo Evaluate，不生成 `redo_review_payload`。

redo review 生成成功后，session 进入 `completed`。客户端通过 `GET /training-sessions/{session_id}` 获取 `redo_review`。

redo review 结果规则：

- 生成并校验成功：`training_session.status = completed`，`completion_reason = redo_review_generated`，`redo_submitted = true`，`redo_review` 非空。
- 生成失败或校验失败：`training_session.status = completed`，`completion_reason = redo_review_unavailable`，`redo_submitted = true`，`redo_review = null`，原 `feedback` 继续可见。
- redo review 失败是 non-blocking terminal outcome，不得把 session 置为 `failed`。
- 可选写入 `redo_review_failure_code`，仅用于客户端提示、日志和 analytics 归因。
- 不额外扣费、不退款、不 release credit。

### 14.9 跳过或放弃训练

#### POST `/training-sessions/{session_id}/skip-redo`

作用：用户在看到 feedback 后主动跳过 redo，完成会话。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "session_id": "ses_123",
    "status": "completed",
    "completion_reason": "redo_skipped",
    "redo_submitted": false
  },
  "error": null
}
```

#### POST `/training-sessions/{session_id}/abandon`

作用：用户在 feedback 前主动放弃当前 session。

规则：

- 如果 credit 尚未 consumed，release reserved credit。
- session 进入 `abandoned`。
- 用户可重新创建 session。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "session_id": "ses_123",
    "status": "abandoned",
    "credit_state": "released"
  },
  "error": null
}
```

### 14.10 历史记录

#### GET `/training-sessions/history?limit=10`

作用：返回最近训练记录摘要。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "items": [
      {
        "session_id": "ses_123",
        "completed_at": "2026-04-21T10:08:13Z",
        "training_focus": "ownership",
        "question_text": "Tell me about a time when you had to make a high-stakes prioritization decision with incomplete information.",
        "original_visible_assessments": {
          "answered_the_question": "Strong",
          "story_fit": "Strong",
          "personal_ownership": "Weak",
          "evidence_and_outcome": "Mixed",
          "holds_up_under_follow_up": "Weak"
        },
        "final_visible_assessments": {
          "answered_the_question": "Strong",
          "story_fit": "Strong",
          "personal_ownership": "Mixed",
          "evidence_and_outcome": "Mixed",
          "holds_up_under_follow_up": "Mixed"
        },
        "completion_reason": "redo_review_generated",
        "redo_submitted": true,
        "redo_improvement_status": "partially_improved",
        "billing_source": "free"
      }
    ]
  },
  "error": null
}
```

### 14.11 删除单次训练

#### DELETE `/training-sessions/{session_id}`

作用：删除用户可见的单次训练内容，并删除关联音频。若 session 已产生 purchase / ledger 记录，ledger 不删除，但解除可识别训练内容关联。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "deleted": true,
    "session_id": "ses_123"
  },
  "error": null
}
```

### 14.12 付费相关

#### GET `/billing/entitlement`

作用：查询剩余额度、商品说明和购买所需 `app_account_token`。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "app_account_token": "00000000-0000-4000-8000-000000000000",
    "usage_balance": {
      "free_session_credits_remaining": 0,
      "paid_session_credits_remaining": 3,
      "reserved_session_credits": 0
    },
    "products": [
      {
        "product_id": "coach_sprint_pack_01",
        "display_name": "Sprint Pack",
        "session_credits": 5
      }
    ]
  },
  "error": null
}
```

#### POST `/billing/apple/verify`

作用：校验 Apple IAP 交易并入账额度。

请求：

```json
{
  "product_id": "coach_sprint_pack_01",
  "transaction_id": "apple_transaction_id",
  "original_transaction_id": "apple_original_transaction_id",
  "app_account_token": "00000000-0000-4000-8000-000000000000",
  "signed_transaction_info": "jws-string",
  "environment": "sandbox"
}
```

服务端必须验证：

1. `signed_transaction_info` 签名有效。
2. `transaction_id` 与 signed transaction 一致。
3. `product_id` 是允许商品。
4. `app_account_token` 与当前用户一致。
5. 交易未被入账过。
6. 交易状态不是 revoked / refunded。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "purchase_id": "pur_123",
    "status": "verified",
    "usage_balance": {
      "free_session_credits_remaining": 0,
      "paid_session_credits_remaining": 5,
      "reserved_session_credits": 0
    }
  },
  "error": null
}
```

#### POST `/billing/apple/restore`

作用：恢复与当前 `app_account_token` 匹配且可恢复的 Apple 交易并同步权益。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "restored_purchase_count": 1,
    "usage_balance": {
      "free_session_credits_remaining": 0,
      "paid_session_credits_remaining": 5,
      "reserved_session_credits": 0
    }
  },
  "error": null
}
```

### 14.13 删除全部用户数据

#### DELETE `/app-users/me/data`

作用：删除当前匿名用户的简历、音频、转写、AI payload 和历史内容，并撤销 token。

响应：

```json
{
  "request_id": "req_123",
  "data": {
    "deleted": true,
    "revoked_sessions": 1
  },
  "error": null
}
```

---

## 15. 状态机

### 15.1 简历状态机

```text
uploaded
  -> parsing
  -> ready
  -> archived
  -> deleted

parsing
  -> failed
```

### 15.2 训练会话状态机

```text
created
  -> question_generating
  -> waiting_first_answer
  -> first_answer_processing
  -> followup_generating
  -> waiting_followup_answer
  -> followup_answer_processing
  -> feedback_generating
  -> redo_available
  -> redo_processing
  -> redo_evaluating
  -> completed        (completion_reason = redo_review_generated)

redo_evaluating
  -> completed        (completion_reason = redo_review_unavailable)

redo_available
  -> completed        (completion_reason = redo_skipped)

Any state before feedback
  -> abandoned        (user abandon or TTL)

Any state before feedback
  -> failed           (system failure or feedback unavailable)
```

### 15.3 Credit 状态机

```text
available
  -> reserved         (session created)
  -> consumed         (feedback generated successfully)

reserved
  -> released         (system failure before feedback, user abandon before feedback, TTL)
```

### 15.4 IAP 入账状态机

```text
pending
  -> verified
  -> rejected

verified
  -> refunded
```

---

## 16. AI 输出校验与失败处理

### 16.1 服务端校验责任

服务端必须在返回客户端前完成：

- JSON schema strict validation。
- 必填字段校验。
- enum 校验。
- 文本长度校验。
- 单问句校验。
- redo review 不含新追问校验。
- 内部评分完整性校验。
- 可见评估完整性校验。

### 16.2 失败处理

若 AI 输出校验失败：

1. 同一步骤最多自动重试 1 次。
2. 重试仍失败时，使用更短、更强约束的 repair prompt。
3. 若失败发生在 feedback 成功之前，repair 仍失败时 session 进入 `failed`，并 release reserved credit。
4. 若失败导致主 feedback 无法交付，session 必须进入 `failed`。
5. 若失败发生在 redo review 阶段，session 必须进入 `completed`，并写入 `completion_reason = redo_review_unavailable`。
6. `completion_reason = redo_review_unavailable` 时，`redo_submitted = true`、`redo_review = null`、原 `feedback` 继续可见；可选写入 `redo_review_failure_code`。
7. redo review failure 不额外扣费、不退款、不 release credit，不触发 session `failed`。

---

## 17. 错误码

| Code | 含义 |
|---|---|
| `UNAUTHORIZED` | token 缺失、过期或无效 |
| `ACTIVE_RESUME_REQUIRED` | 当前没有活跃简历 |
| `RESUME_NOT_READY` | 简历仍在解析或不可用 |
| `RESUME_PARSE_FAILED` | 简历文本提取或解析失败 |
| `RESUME_PROFILE_UNUSABLE` | 简历缺少可训练锚点 |
| `ACTIVE_SESSION_EXISTS` | 当前已有未完成训练会话 |
| `INSUFFICIENT_SESSION_CREDITS` | 免费与付费次数都不足 |
| `TRAINING_SESSION_NOT_FOUND` | 会话不存在 |
| `TRAINING_SESSION_NOT_READY` | 当前状态不允许执行该步骤 |
| `IDEMPOTENCY_CONFLICT` | 同一幂等键对应的请求体不一致 |
| `AUDIO_UPLOAD_FAILED` | 音频上传失败 |
| `TRANSCRIPTION_FAILED` | 转写失败 |
| `TRANSCRIPT_QUALITY_TOO_LOW` | 转写结果不可用于 AI 链路 |
| `AI_GENERATION_FAILED` | AI 生成失败 |
| `AI_OUTPUT_VALIDATION_FAILED` | AI 输出结构或内容校验失败 |
| `APPLE_PURCHASE_VERIFICATION_FAILED` | Apple IAP 校验失败 |
| `APPLE_TRANSACTION_ALREADY_PROCESSED` | Apple 交易已入账 |
| `APP_ACCOUNT_TOKEN_MISMATCH` | Apple 交易不属于当前用户 |
| `UNSUPPORTED_FILE_TYPE` | 不支持的简历文件类型 |
| `DATA_DELETION_FAILED` | 数据删除失败或部分失败 |

转写错误映射：

- `transcript_quality_status = too_short` / `silent` / `non_english` / `low_confidence`：`transcript_status = completed`，错误码使用 `TRANSCRIPT_QUALITY_TOO_LOW`。
- `transcript_quality_status = failed`：`transcript_status = failed`，错误码使用 `TRANSCRIPTION_FAILED`。
- `transcript_quality_status != usable` 时，不进入下一步 AI 链路。

---

## 18. 最小验收标准

Data / API 层满足以下条件，才可以进入首轮联调：

1. App 首次启动能创建或恢复匿名 `app_user`，并获取可用 `access_token`。
2. 后续 API 不依赖 `installation_id` 鉴权。
3. 用户上传英文简历后，能得到 `resume_profile`，且包含 `source_snippets` 与质量状态。
4. 简历不可训练时，不生成问题，不虚构经历。
5. 创建训练会话时会预留 credit，并限制同一用户只有 1 个 active session。
6. 问题、追问、反馈、redo review 的字段与 Prompt / Content Spec v1.1 一致。
7. 追问使用 canonical `target_gap`，且不出现双问句。
8. 首轮回答、追问回答、redo 回答都有 `transcript_status` 与 `transcript_quality_status` 字段，且组合规则、错误码映射与第 8.4 / 8.5 节一致；`transcript_quality_status != usable` 时不进入下一步 AI 链路。
9. feedback 成功生成时才 consume credit。
10. 系统失败或 feedback 前放弃时能 release reserved credit。
11. redo 提交后能进入 Redo Evaluate；生成成功时返回 `redo_review_payload` 并以 `completion_reason = redo_review_generated` 完成，生成失败或校验失败时以 `completion_reason = redo_review_unavailable` 完成且 `redo_review = null`。
12. 所有写接口支持 `Idempotency-Key`。
13. IAP 交易校验使用 `app_account_token` 与 signed transaction 信息，重复上报不会重复入账。
14. 用户可以删除活跃简历、单次训练记录和全部训练数据。
15. 历史记录能返回最近 10 次训练摘要，并包含 `completion_reason`；redo review 成功时包含 redo 改善状态。
16. 服务端返回对象字段与 Prompt / Content Spec v1.1 契约一致。
17. `docs/api/openapi.yaml` 与本文档 endpoint / idempotency header 索引一致，OpenAPI 组件能引用或承接 Prompt / Content Spec v1.1 第 14 节 JSON Schema。
18. 首次创建匿名用户时，必须写入初始免费额度的 `credit_ledger.grant`。

---


## 19. 一句话收束

Data / API Spec v1.1 的目标不是扩张系统，而是把收费验证版真正需要的底座补齐：匿名但可鉴权的用户、可审计的 credit ledger、与 Prompt v1.1 对齐的 5 步 AI payload、可评估的 redo 闭环、可恢复的移动端写请求、可校验的 Apple IAP，以及对简历和音频这类敏感数据的最小化保存与删除能力。
