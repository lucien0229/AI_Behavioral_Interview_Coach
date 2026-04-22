# AI Behavioral Interview Coach QA / Acceptance Test Plan v1

## 1. 文档信息

- 文档名称：QA / Acceptance Test Plan
- 版本：v1
- 日期：2026-04-21
- 适用产品版本：AI Behavioral Interview Coach v1
- 主要读者：QA、iOS 客户端、后端、Prompt / AI、产品、数据
- 上游依据：
  - `docs/ios/AI_Behavioral_Interview_Coach_PRD_v1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_Prompt_Content_Spec_v1.1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_Data_API_Spec_v1.1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_Client_UX_State_Error_Handling_Spec_v1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_Analytics_Event_Spec_v1.md`
  - `docs/ios/AI_Behavioral_Interview_Coach_iOS_Client_Screen_Spec_v1.md`
  - `docs/design/AI_Behavioral_Interview_Coach_iOS_UI_Design_Spec_v1.md`

---

## 2. 本文档解决什么问题

本文档把现有产品、Prompt、Data/API、Client UX、Analytics、iOS Screen 和 iOS UI Design 规格转成可执行验收测试。

目标是确保 v1 在进入 TestFlight 或首轮用户测试前，至少满足以下条件：

1. 用户可以完成一次基于简历的完整训练闭环。
2. 关键异常路径不会导致重复扣费、重复创建 session、丢失 active session 或误导用户。
3. Prompt 输出满足严格 schema、内容质量和不虚构要求。
4. Client UX 能正确处理所有 Data / API 错误码。
5. Analytics 能支持 PRD 定义的核心指标。
6. 简历、音频、转写和 AI 文案不会进入 analytics 或错误日志。

本文档不定义自动化测试框架选型、CI 配置、mock server 实现细节或具体测试账号管理流程。

---

## 3. 测试范围

### 3.1 In Scope

v1 必测范围：

- 匿名 bootstrap 与 token 恢复
- Home 状态渲染
- iOS screen route / sheet / API / analytics CTA 映射
- iOS UI Design / Wireframe 关键视觉规则
- 简历上传、解析、不可训练、删除
- 创建训练会话和 credit reserve
- Question Generate
- 首轮回答录音上传、转写、失败重录
- Follow-up Generate
- 追问回答录音上传、转写、失败重录
- Feedback Generate 与固定反馈结构
- Redo 提交、skip redo、redo review
- Active session 恢复、TTL、abandon
- Credit consume / release
- Apple IAP verify / restore
- 所有写接口 `Idempotency-Key`
- 所有 Data / API 错误码到 UX 行为
- Analytics 主漏斗和错误事件
- 删除简历、删除单次训练、删除全部数据
- 隐私禁止字段校验

### 3.2 Out of Scope

v1 不测或只做 smoke check：

- 多语言训练
- JD 个性化训练
- 文本回答主路径
- 多账号合并
- 长期成长图谱
- App Store Server Notifications 完整后台链路
- 广告归因
- Dashboard 视觉配置

---

## 4. 测试环境与数据

### 4.1 环境

| Environment | 用途 | 必须能力 |
|---|---|---|
| Local mock | 客户端状态和错误码测试 | 可稳定 mock API envelope、session state、错误码 |
| Staging API | 端到端联调 | 连接真实后端、对象存储、AI provider sandbox、StoreKit sandbox |
| TestFlight sandbox | 发布前验收 | 使用真实 iOS 包、StoreKit sandbox、真实网络条件 |

### 4.2 测试数据集

QA 至少准备以下简历与回答样本：

| Dataset | 最小数量 | 用途 |
|---|---:|---|
| 高质量英文 PM / Program Manager 简历 | 10 | Happy path、题目质量 |
| 信息有限但可训练简历 | 5 | `profile_quality_status = limited` |
| 不可训练简历 | 5 | `RESUME_PROFILE_UNUSABLE` |
| 解析失败文件 | 3 | `RESUME_PARSE_FAILED` |
| 不支持文件类型 | 3 | `UNSUPPORTED_FILE_TYPE` |
| 首轮回答音频 | 10 | ASR 与 Follow-up |
| 过短 / 静音 / 非英文 / 低置信 / ASR 失败音频 | 10 | `TRANSCRIPT_QUALITY_TOO_LOW` / `TRANSCRIPTION_FAILED` |
| Redo 回答音频 | 10 | Redo review |
| Apple sandbox transaction | 3 | verify、duplicate、restore |

测试数据不得包含真实个人敏感信息。简历样本必须脱敏或合成。

---

## 5. 验收优先级

| Priority | 含义 | Release gate |
|---|---|---|
| P0 | 阻断发布；会导致主路径不可用、重复扣费、隐私泄露、数据删除失真 | 必须 100% 通过 |
| P1 | 阻断首轮外部测试；影响核心闭环、恢复、错误处理或指标判断 | 必须 100% 通过 |
| P2 | 可进入小范围测试但必须有记录；影响边界体验或低频路径 | 发布前修复或明确风险 |
| P3 | 非阻断；文案、观测增强或后续自动化补充 | 可排后续 |

---

## 6. Acceptance Gates

进入 TestFlight 前必须满足：

1. 所有 P0 / P1 测试用例通过。
2. 端到端主路径在 TestFlight sandbox 连续通过 5 次。
3. 所有 Data / API v1.1 错误码都有客户端 UX 映射和 analytics error event。
4. 所有写接口重试不产生重复创建、重复提交、重复扣费或重复入账。
5. feedback 成功前系统失败会 release reserved credit。
6. feedback 成功后 skip redo 或 redo review 失败不会退款、不会额外扣费，且 session 以 `completed` 结束。
7. Analytics 不包含禁止字段。
8. 删除简历两种模式、删除单次训练、删除全部数据行为与文档一致。

---

## 7. 端到端主路径测试

### QA-E2E-001 完整训练闭环：提交 redo

- Priority：P0
- 覆盖：PRD 主路径、Data/API session state、Prompt 5 步 AI payload、Client UX、Analytics
- 前置条件：
  - 新匿名用户
  - 可训练英文简历
  - 免费额度 >= 1
- 步骤：
  1. 启动 App，完成 bootstrap。
  2. 上传英文简历。
  3. 等待简历状态进入 `ready` 且 `profile_quality_status = usable`。
  4. 选择 `training_focus = ownership`。
  5. 创建训练 session。
  6. 等待 question 可见。
  7. 提交首轮回答音频。
  8. 等待 follow-up 可见。
  9. 提交追问回答音频。
  10. 等待 feedback 可见。
  11. 点击 redo，提交 redo 音频。
  12. 等待 redo review 可见。
  13. 返回 Home。
- 预期结果：
  - session 依次经过 `question_generating`、`waiting_first_answer`、`first_answer_processing`、`followup_generating`、`waiting_followup_answer`、`followup_answer_processing`、`feedback_generating`、`redo_available`、`redo_processing`、`redo_evaluating`、`completed`。
  - 创建 session 后 credit 为 `reserved`。
  - feedback 成功后 credit 为 `consumed`。
  - `completion_reason = redo_review_generated`。
  - redo review 包含 `improvement_status` 和用户可见 delta review。
  - Home 不再显示 active session。
  - analytics 至少包含 `training_session_created`、`question_viewed`、`first_answer_submitted`、`follow_up_viewed`、`follow_up_answer_submitted`、`feedback_viewed`、`redo_submitted`、`redo_review_viewed`、`training_session_completed`。

### QA-E2E-002 完整训练闭环：skip redo

- Priority：P0
- 覆盖：redo 可跳过、session completed、credit consume
- 前置条件：
  - session 已进入 `redo_available`
- 步骤：
  1. 在 feedback 页面点击 Skip redo。
  2. 等待 API 成功。
  3. 刷新 Home。
- 预期结果：
  - `POST /training-sessions/{session_id}/skip-redo` 成功。
  - session 进入 `completed`。
  - `completion_reason = redo_skipped`。
  - `redo_submitted = false`。
  - credit 保持 `consumed`。
  - Home 不显示 active session。
  - analytics 包含 `redo_skipped` 和 `training_session_completed`，且 `training_session_completed.completion_reason = redo_skipped`，不包含 `redo_submitted`。

### QA-E2E-003 App 重启恢复 active session

- Priority：P0
- 覆盖：active session 恢复、聚合读接口
- 前置条件：
  - session 停留在 `waiting_followup_answer` 或 `feedback_generating`
- 步骤：
  1. 强制关闭 App。
  2. 重新打开 App。
  3. 完成 bootstrap / token 恢复。
  4. 进入 Home。
  5. 点击 Continue session。
- 预期结果：
  - Home 显示 active session。
  - 客户端调用 `GET /training-sessions/{session_id}` 恢复会话。
  - 不调用 `/follow-up`、`/feedback`、`/redo-review` 专项读接口。
  - 不创建新的 session。

---

## 8. Bootstrap / Auth 测试

### QA-AUTH-001 首次启动创建匿名用户

- Priority：P0
- 步骤：
  1. 清空本地数据。
  2. 启动 App。
  3. 调用 `POST /app-users/bootstrap`。
- 预期结果：
  - 返回 `app_user_id`、`access_token`、`expires_at`、`app_account_token`。
  - 初始免费额度写入 `credit_ledger.grant`。
  - 客户端进入 Home。
  - analytics 包含 `app_bootstrap_started` 和 `app_bootstrap_completed`。

### QA-AUTH-002 Token 过期自动恢复

- Priority：P1
- 步骤：
  1. 使用过期 token 调用 `GET /home`。
  2. 服务端返回 `UNAUTHORIZED`。
  3. 客户端自动 bootstrap。
  4. 客户端重试原请求一次。
- 预期结果：
  - 用户不需要重新安装或手动登录。
  - 原请求成功恢复。
  - analytics 包含 `api_error_received`，`error_code = UNAUTHORIZED`。

### QA-AUTH-003 写请求遇到 UNAUTHORIZED 后复用 Idempotency-Key

- Priority：P0
- 步骤：
  1. 用过期 token 提交 `POST /training-sessions`。
  2. 客户端收到 `UNAUTHORIZED` 后 bootstrap。
  3. 重试原写请求。
- 预期结果：
  - 重试使用同一个 `Idempotency-Key`。
  - 只创建一个 session。
  - 没有重复 reserve credit。

---

## 9. Resume 测试

### QA-RESUME-001 上传可训练英文简历

- Priority：P0
- 步骤：
  1. 上传 PDF 或 DOCX 英文简历。
  2. 轮询 `GET /resumes/{resume_id}`。
- 预期结果：
  - `POST /resumes` 返回 `status = parsing`。
  - 最终 `status = ready`。
  - `profile_quality_status = usable` 或 `limited`。
  - `resume_profile` 包含结构化 experience units。
  - analytics 包含 `resume_upload_completed` 和 `resume_parse_completed`。

### QA-RESUME-002 不支持文件类型

- Priority：P1
- 步骤：
  1. 选择非 PDF / DOCX 文件。
- 预期结果：
  - 客户端本地阻止上传，或服务端返回 `UNSUPPORTED_FILE_TYPE`。
  - 不创建 resume。
  - UX 提示 Choose another file。
  - analytics 不发送 resume text 或 file name。

### QA-RESUME-003 简历解析失败

- Priority：P1
- 步骤：
  1. 上传无法提取文本的 PDF。
  2. 等待解析结束。
- 预期结果：
  - 返回或记录 `RESUME_PARSE_FAILED`。
  - 不生成 question。
  - UX 主操作为 Upload another resume。
  - analytics 包含 `resume_parse_failed`。

### QA-RESUME-004 简历不可训练

- Priority：P0
- 步骤：
  1. 上传缺少经历锚点的英文简历。
  2. 等待解析完成。
  3. 尝试 Start training。
- 预期结果：
  - `profile_quality_status = unusable`。
  - Start training 被阻止，或 API 返回 `RESUME_PROFILE_UNUSABLE`。
  - 不生成问题。
  - 不 reserve credit。
  - analytics 包含 `resume_profile_unusable`。

### QA-RESUME-005 source snippets 条件约束

- Priority：P0
- 覆盖：Prompt schema 防虚构
- 步骤：
  1. 使用包含 high / medium / low questionability experience 的简历样本。
  2. 运行 Resume Parse。
  3. 校验 JSON Schema。
- 预期结果：
  - `questionability = high` 的 experience unit 必须有至少 1 个 `source_snippets`。
  - medium / low 可允许 `source_snippets = []`。
  - 模型不得为了满足 schema 编造 source snippets。

---

## 10. Training Session / State Machine 测试

### QA-SESSION-001 创建 session reserve credit

- Priority：P0
- 步骤：
  1. 在有可用 credit 和 active resume 的情况下创建 session。
- 预期结果：
  - session 创建成功。
  - `credit_state = reserved`。
  - `reserved_session_credits` 增加。
  - analytics 包含 `training_session_created`。

### QA-SESSION-002 active session 阻止新建

- Priority：P0
- 步骤：
  1. 创建 session 并停留在任意非终态。
  2. 再次点击 Start training。
- 预期结果：
  - API 返回 `ACTIVE_SESSION_EXISTS`。
  - 客户端展示 Continue session。
  - 不创建第二个 session。
  - 不重复 reserve credit。

### QA-SESSION-003 redo_processing / redo_evaluating 仍属于 active session

- Priority：P0
- 步骤：
  1. 提交 redo，让 session 进入 `redo_processing` 或 `redo_evaluating`。
  2. 返回 Home。
  3. 尝试创建新 session。
- 预期结果：
  - Home 显示 active session。
  - 新 session 创建被阻止。
  - 不出现历史更新和 redo review 展示竞态。

### QA-SESSION-004 TTL abandon release credit

- Priority：P1
- 步骤：
  1. 创建 session，但不完成 feedback。
  2. 模拟 TTL 到期。
- 预期结果：
  - session 进入 `abandoned`。
  - reserved credit 进入 `released`。
  - 用户可创建新 session。
  - analytics 包含 `training_session_abandoned`，`abandon_reason = ttl_expired`。

### QA-SESSION-005 feedback 前用户 abandon

- Priority：P1
- 步骤：
  1. 创建 session 并在 feedback 前点击 abandon。
- 预期结果：
  - session 进入 `abandoned`。
  - 如果 credit 尚未 consumed，reserved credit release。
  - UX 返回 Home 并刷新余额。

---

## 11. Answer / ASR 测试

### QA-ASR-001 首轮回答成功

- Priority：P0
- 步骤：
  1. 在 `waiting_first_answer` 提交可用音频。
- 预期结果：
  - `POST /training-sessions/{session_id}/first-answer` 成功。
  - session 进入 `first_answer_processing` 后进入 `followup_generating` / `waiting_followup_answer`。
  - `answer_submission.transcript_status = completed`。
  - `answer_submission.transcript_quality_status = usable`。
  - analytics 包含 `first_answer_submitted`。

### QA-ASR-002 首轮回答过短

- Priority：P1
- 步骤：
  1. 提交过短音频。
- 预期结果：
  - `transcript_status = completed`。
  - `transcript_quality_status = too_short`。
  - 错误码为 `TRANSCRIPT_QUALITY_TOO_LOW`。
  - session 回到或停留在 `waiting_first_answer`。
  - 不生成 follow-up。
  - UX 主操作为 Record again。

### QA-ASR-003 首轮回答静音

- Priority：P1
- 步骤：
  1. 在 `waiting_first_answer` 提交静音音频。
- 预期结果：
  - `transcript_status = completed`。
  - `transcript_quality_status = silent`。
  - 错误码为 `TRANSCRIPT_QUALITY_TOO_LOW`。
  - session 回到或停留在 `waiting_first_answer`。
  - 不生成 follow-up。
  - UX 主操作为 Record again。

### QA-ASR-004 首轮回答非英文

- Priority：P1
- 步骤：
  1. 在 `waiting_first_answer` 提交非英文音频。
- 预期结果：
  - `transcript_status = completed`。
  - `transcript_quality_status = non_english`。
  - 错误码为 `TRANSCRIPT_QUALITY_TOO_LOW`。
  - 如果服务端识别到语言，`detected_language` 记录真实值，例如 `es` 或 `zh`。
  - session 回到或停留在 `waiting_first_answer`。
  - 不生成 follow-up。
  - UX 主操作为 Record again。

### QA-ASR-005 追问回答低置信

- Priority：P1
- 步骤：
  1. 在 `waiting_followup_answer` 提交低置信音频。
- 预期结果：
  - `transcript_status = completed`。
  - `transcript_quality_status = low_confidence`。
  - 错误码为 `TRANSCRIPT_QUALITY_TOO_LOW`。
  - session 回到或停留在 `waiting_followup_answer`。
  - 不进入 `feedback_generating`。
  - 不 consume credit。
  - UX 主操作为 Record again。

### QA-ASR-006 追问回答 ASR 失败

- Priority：P1
- 步骤：
  1. 在 `waiting_followup_answer` 提交不可转写音频。
- 预期结果：
  - `transcript_status = failed`。
  - `transcript_quality_status = failed`。
  - 错误码为 `TRANSCRIPTION_FAILED`。
  - session 回到或停留在 `waiting_followup_answer`。
  - 不进入 `feedback_generating`。
  - 不 consume credit。
  - UX 主操作为 Record again。

### QA-ASR-007 redo 音频不可用

- Priority：P1
- 步骤：
  1. 在 `redo_available` 提交不可用 redo 音频。
- 预期结果：
  - `transcript_quality_status` 为 `too_short` / `silent` / `non_english` / `low_confidence` 时，`transcript_status = completed` 且错误码为 `TRANSCRIPT_QUALITY_TOO_LOW`。
  - `transcript_quality_status = failed` 时，`transcript_status = failed` 且错误码为 `TRANSCRIPTION_FAILED`。
  - 不生成 `redo_review_payload`。
  - 用户回到 redo 可录状态。
  - 不额外扣费。
  - 原 feedback 保持可见。

---

## 12. Prompt / AI 输出测试

### QA-AI-001 Question Generate 质量

- Priority：P0
- 步骤：
  1. 对 10 份高质量 PM 简历创建训练。
  2. 检查生成 question。
- 预期结果：
  - `question_text` 明显锚定简历经历。
  - `training_focus` 使用 canonical enum。
  - `expected_signal_targets` 不进入用户可见文案。
  - 不虚构简历事实。

### QA-AI-002 Follow-up 单问句约束

- Priority：P0
- 步骤：
  1. 提交首轮回答。
  2. 检查 follow-up payload。
- 预期结果：
  - `follow_up_text` 只有一个问号。
  - 不包含多问句或复合追问。
  - `target_gap` 属于允许枚举。

### QA-AI-003 Feedback 输出结构

- Priority：P0
- 步骤：
  1. 完成追问回答。
  2. 检查 feedback payload 和 API response view。
- 预期结果：
  - 模型输出包含完整 10 维 `internal_scores`。
  - 模型输出不包含 `visible_assessments`。
  - 服务端按固定映射生成 5 项 `visible_assessments`。
  - 用户可见 feedback 固定包含 5 段：`strongest_signal`、`biggest_gap`、`why_it_matters`、`redo_priority`、`redo_outline`。
  - 不出现总分字段。

### QA-AI-004 Redo Review 是 delta review

- Priority：P0
- 步骤：
  1. 提交 redo。
  2. 检查 redo review payload 和用户界面。
- 预期结果：
  - 模型输出 `updated_internal_scores`。
  - 模型不输出 `updated_visible_assessments`。
  - 服务端生成 final visible assessments。
  - 包含 `improvement_status`、`what_improved`、`still_missing`、`final_takeaway`、`next_practice_priority`。
  - 不生成新追问。
  - 不生成第二份完整 feedback。

### QA-AI-005 AI 输出校验失败 repair

- Priority：P1
- 步骤：
  1. mock AI 返回 schema invalid payload。
  2. 服务端执行自动重试和 repair prompt。
- 预期结果：
  - 同一步骤最多自动重试 1 次。
  - feedback 成功前 repair 仍失败时 session 进入 `failed`。
  - feedback 前失败会 release reserved credit。
  - analytics 包含 `training_session_failed` 和 `error_code = AI_OUTPUT_VALIDATION_FAILED`。

### QA-AI-006 redo review 失败不影响主 feedback

- Priority：P1
- 步骤：
  1. 已进入 `redo_available`。
  2. 提交 redo。
  3. mock Redo Evaluate 失败。
- 预期结果：
  - session 进入 `completed`。
  - `completion_reason = redo_review_unavailable`。
  - `redo_submitted = true`。
  - `redo_review = null`。
  - 主 feedback 仍可见。
  - 不退款。
  - 不额外扣费。
  - credit 保持 `consumed`。
  - UX 显示“Redo review is temporarily unavailable”。
  - Home 无 active session。
  - 用户可开始下一次训练。
  - analytics 包含 `training_session_completed` 且 `completion_reason = redo_review_unavailable`，不包含 `training_session_failed`。

---

## 13. Idempotency / Mobile Retry 测试

### QA-IDEMP-001 创建 session 重试

- Priority：P0
- 步骤：
  1. 调用 `POST /training-sessions`。
  2. 在客户端超时后用同一 `Idempotency-Key` 重试。
- 预期结果：
  - 只创建一个 session。
  - 只 reserve 一次 credit。
  - 返回同一业务结果或等价结果。

### QA-IDEMP-002 首轮回答上传重试

- Priority：P0
- 步骤：
  1. 上传同一首轮音频。
  2. 模拟网络超时。
  3. 用同一 key 重试。
- 预期结果：
  - 只创建一个 `answer_submission`。
  - 不重复触发 Follow-up Generate。

### QA-IDEMP-003 follow-up answer 上传重试

- Priority：P0
- 预期结果：
  - 只创建一个追问回答 submission。
  - 不重复触发 Feedback Generate。
  - 不重复 consume credit。

### QA-IDEMP-004 redo 上传重试

- Priority：P0
- 预期结果：
  - 只创建一个 `redo_submission`。
  - 不重复触发 Redo Evaluate。

### QA-IDEMP-005 Apple verify 重试

- Priority：P0
- 步骤：
  1. 同一 Apple transaction 调用 verify。
  2. 模拟客户端未收到响应。
  3. 用同一 key 和同一 transaction payload 重试。
- 预期结果：
  - 只入账一次。
  - 如交易已处理，返回 `APPLE_TRANSACTION_ALREADY_PROCESSED` 或等价已处理结果。
  - paid credits 不重复增加。

### QA-IDEMP-006 Idempotency conflict

- Priority：P0
- 步骤：
  1. 对同一 endpoint 使用同一 `Idempotency-Key` 发送不同请求体。
- 预期结果：
  - 返回 `IDEMPOTENCY_CONFLICT`。
  - 客户端停止自动重试。
  - UX 要求用户重新发起该动作。
  - analytics 包含 `api_error_received`，`idempotency_key_reused = true`。

---

## 14. Credit / Billing / IAP 测试

### QA-BILL-001 feedback 成功才 consume credit

- Priority：P0
- 步骤：
  1. 创建 session。
  2. 完成到 feedback 成功。
- 预期结果：
  - 创建时 `credit_state = reserved`。
  - feedback 成功生成后 `credit_state = consumed`。
  - `credit_ledger.consume` 写入一次。

### QA-BILL-002 feedback 前失败 release credit

- Priority：P0
- 步骤：
  1. 创建 session。
  2. mock feedback 前系统失败。
- 预期结果：
  - session 进入 `failed` 或 `abandoned`。
  - reserved credit release。
  - 用户可重新开始训练。

### QA-BILL-003 免费额度用尽触发 Paywall

- Priority：P1
- 步骤：
  1. 完成 2 次免费训练。
  2. 尝试创建第 3 次训练。
- 预期结果：
  - 返回 `INSUFFICIENT_SESSION_CREDITS` 或展示 Paywall。
  - 不创建 session。
  - analytics 包含 `paywall_viewed`。

### QA-BILL-004 purchase verified 后入账

- Priority：P0
- 步骤：
  1. StoreKit sandbox 购买 Sprint Pack。
  2. 调用 `POST /billing/apple/verify`。
- 预期结果：
  - 校验签名、transaction、product、`app_account_token`。
  - `purchase_transaction.status = verified`。
  - paid credits 增加。
  - analytics 包含 `purchase_verified`，不包含 Apple transaction payload。

### QA-BILL-005 restore purchase

- Priority：P1
- 步骤：
  1. 对已有可恢复购买调用 restore。
- 预期结果：
  - 返回 `restored_purchase_count`。
  - 权益同步。
  - 不重复入账。

### QA-BILL-006 app account token mismatch

- Priority：P0
- 步骤：
  1. 用不匹配的 `app_account_token` verify transaction。
- 预期结果：
  - 返回 `APP_ACCOUNT_TOKEN_MISMATCH`。
  - 不入账。
  - UX 提供 Restore purchase 或 Contact support。

---

## 15. Client UX / Error Handling 测试

### QA-UX-001 所有错误码都有 UX 行为

- Priority：P0
- 步骤：
  1. mock Data / API v1.1 每个错误码。
  2. 在对应页面触发。
- 预期结果：
  - 每个错误码都有用户解释、主操作和状态影响。
  - 不显示内部堆栈、Prompt 细节或原始 provider error。

### QA-UX-002 Loading 状态不是裸 spinner

- Priority：P2
- 步骤：
  1. 进入简历解析、question generation、ASR、feedback generation、redo evaluation、purchase verification。
- 预期结果：
  - 每个 loading 都有明确任务文案。
  - 90 秒后允许用户离开并稍后回来。

### QA-UX-003 写请求 pending 时按钮禁用

- Priority：P1
- 步骤：
  1. 在慢网环境点击 Start training / Submit answer / Verify purchase / Delete。
  2. 快速重复点击。
- 预期结果：
  - 不重复发起同一用户意图。
  - 如重试，复用同一 `Idempotency-Key`。

### QA-UX-004 Home 状态覆盖

- Priority：P1
- 步骤：
  1. mock Home 返回以下基础组合：无简历、解析中、ready usable、ready limited、unusable、active session、无额度。
  2. 额外 mock 非互斥组合：`active_session + ready + credit = 0`、`parsing + last_training_summary`、`ready + last_training_summary`、`ready limited + credit = 0`、`unusable + credit = 0`。
- 预期结果：
  - 客户端先派生唯一 `homePrimaryState`，再渲染唯一 primary CTA。
  - 优先级必须为 `activeSession > noResume > resumeProcessing > resumeFailed > resumeUnusable > outOfCredits > readyLimited > ready`。
  - `last_training_summary` 只显示 supplemental card，不改变 primary CTA。
  - active session 时不显示 Start training / Start new。
  - parsing 时不允许 Start training，即使有历史摘要或剩余额度。
  - unusable 时不允许 Buy Sprint Pack 成为 primary CTA。

### QA-IOS-001 全局 CTA 硬映射完整

- Priority：P1
- 步骤：
  1. 对照 iOS Client Screen Spec 6.5。
  2. 遍历 IOS-SCR-00 至 IOS-SCR-17 所有可点击 CTA、list item、sheet action、dialog action。
- 预期结果：
  - 每个 CTA 都有 route / sheet / API / analytics 映射。
  - Home `Cancel resume` 走 IOS-SCR-15 删除确认，确认后调用 `DELETE /resumes/active`，`delete_mode = resume_only_redacted_history`。
  - Home `View all history` push IOS-SCR-11。
  - Home Settings icon push IOS-SCR-14。
  - Privacy Notice `Manage data` push IOS-SCR-14，不依赖底部导航选择状态。
  - 不存在“文案可点击但没有落点”的入口。

### QA-IOS-001A Home-first navigation

- Priority：P1
- 步骤：
  1. App bootstrap 成功后进入主业务界面。
  2. 确认主界面不存在底部 TabView。
  3. 从 Home 点击 Settings icon，再返回。
  4. 从 Home 点击 View all history，再返回。
- 预期结果：
  - Home 是唯一 root screen。
  - 不显示 Home / History / Settings 底部导航。
  - Settings 和 History 都是从 Home push 进入的一跳页面。
  - 返回后 Home 的 `homePrimaryState`、last training supplemental card 和 pending CTA 不丢失。

### QA-IOS-002 Privacy Notice 路由闭环

- Priority：P1
- 步骤：
  1. 从 Home 无简历状态点击 Privacy。
  2. 从 Resume Upload 点击隐私说明入口。
  3. 从 Settings 点击 Privacy。
  4. 在 Privacy Notice 点击 Manage data 和 Back。
- 预期结果：
  - 三个入口都进入 IOS-SCR-17。
  - Back 返回触发来源。
  - Manage data push Settings / Data，不依赖底部导航状态。
  - Privacy Notice 不展示原始简历、转写、feedback 或任何用户敏感内容。

### QA-IOS-003 UI Design / Wireframe 合同

- Priority：P1
- 步骤：
  1. 对照 iOS UI Design / Wireframe Spec 的 IOS-SCR-00 至 IOS-SCR-17。
  2. 使用至少 iPhone SE、标准 iPhone、Pro Max 三种 viewport 或 simulator 尺寸检查关键屏幕。
  3. 开启较大 Dynamic Type 检查 Home、Training、Feedback、Paywall、Delete Confirmation、Privacy Notice。
- 预期结果：
  - 每个 Screen Spec screen 都有对应 UI 布局实现或 SwiftUI preview fixture。
  - Home 只有一个 primary CTA，Last practice 只作为 supplemental。
  - Training answer screens 使用暗色沉浸背景；Home / History / Settings / Feedback / Privacy 使用浅色阅读背景。
  - Apple Blue 只用于交互元素；没有额外强调色、装饰渐变、card inside card。
  - Dynamic Type 下按钮、录音控制、bottom CTA、文本不重叠、不截断关键动作。

---

## 16. Analytics 测试

### QA-AN-001 主漏斗事件完整

- Priority：P0
- 步骤：
  1. 执行 QA-E2E-001。
  2. 检查 analytics sink。
- 预期结果：
  - 主漏斗事件按顺序出现。
  - `event_schema_version = analytics_v1`。
  - `app_user_id`、`session_id`、`resume_id` 关联正确。
  - `training_session_completed` 包含 `completion_reason`。

### QA-AN-002 completed / verified 事件以服务端为准

- Priority：P0
- 步骤：
  1. mock API 点击成功但服务端返回失败。
  2. 检查 analytics。
- 预期结果：
  - 不发送 `training_session_completed`、`purchase_verified` 等成功事件。
  - 发送 `api_error_received`。

### QA-AN-003 feedback_viewed 只在实际曝光后发送

- Priority：P1
- 步骤：
  1. feedback 已生成。
  2. 用户在 feedback 页面显示前杀 App。
- 预期结果：
  - 可有 `feedback_generated`。
  - 不应有 `feedback_viewed`。

### QA-AN-004 错误事件字段完整

- Priority：P1
- 步骤：
  1. mock 任意 API envelope error。
- 预期结果：
  - `api_error_received` 包含 `error_code`、`request_id`、`http_status`、`failed_endpoint`、`failed_operation`。
  - 写接口错误包含 `idempotency_key_reused`。

### QA-AN-005 redo review unavailable 不触发 session failed

- Priority：P1
- 步骤：
  1. 执行 QA-AI-006。
  2. 检查 analytics sink。
- 预期结果：
  - 存在 `training_session_completed`。
  - `completion_reason = redo_review_unavailable`。
  - 可选包含 `redo_review_failure_code`。
  - 不存在同一 `session_id` 的 `training_session_failed`。

### QA-AN-006 ASR canonical enum

- Priority：P1
- 步骤：
  1. 执行 QA-ASR-002 至 QA-ASR-007。
  2. 检查 analytics sink。
- 预期结果：
  - 所有 ASR 相关事件中的 `transcript_quality_status` 只使用 `usable` / `too_short` / `silent` / `non_english` / `low_confidence` / `failed`。
  - 不出现废弃旧值。
  - 当 `transcript_quality_status` 为 `too_short` / `silent` / `non_english` / `low_confidence` 时，`transcript_status = completed`。
  - 当 `transcript_quality_status = failed` 时，`transcript_status = failed`。
  - `too_short` / `silent` / `non_english` / `low_confidence` 对应 `TRANSCRIPT_QUALITY_TOO_LOW`。
  - `failed` 对应 `TRANSCRIPTION_FAILED`。
  - `non_english` 场景下，如果服务端识别到语言，analytics 保留真实 `detected_language`。

### QA-AN-007 隐私禁止字段拦截

- Priority：P0
- 步骤：
  1. 构造包含禁止字段的 analytics event。
- 预期结果：
  - pipeline 拒绝事件。
  - 禁止字段包括 `resume_text`、`source_snippets`、`transcript_text`、`question_text`、`follow_up_text`、AI feedback 文案、Apple transaction payload、`app_account_token`。

### QA-AN-008 Home primary state analytics

- Priority：P1
- 步骤：
  1. 执行 QA-UX-004 的 Home 状态组合。
  2. 检查每次 `home_viewed`。
- 预期结果：
  - `home_viewed.home_primary_state` 与客户端实际渲染的 `homePrimaryState` 一致。
  - `last_training_summary` 不产生独立 primary state。
  - 可按 `home_primary_state` 区分 `activeSession`、`resumeProcessing`、`resumeUnusable`、`outOfCredits`、`readyLimited` 等状态。

---

## 17. Privacy / Deletion 测试

### QA-PRIV-001 删除简历：保留脱敏历史

- Priority：P0
- 步骤：
  1. 完成一次训练。
  2. 调用 `DELETE /resumes/active`，`delete_mode = resume_only_redacted_history`。
- 预期结果：
  - 原始简历、`resume_profile`、`source_snippets` 被删除。
  - 历史摘要保留但移除可识别简历派生细节。
  - response 报告 `removed` 和 `retained`。

### QA-PRIV-002 删除简历：删除关联训练

- Priority：P0
- 步骤：
  1. 完成一次训练。
  2. 调用 `DELETE /resumes/active`，`delete_mode = resume_and_linked_training`。
- 预期结果：
  - 原始简历、`resume_profile`、`source_snippets`、关联训练文本、AI payload、音频删除。
  - purchase / ledger 审计记录保留但解除可识别训练内容关联。
  - 历史列表不再展示该训练内容。

### QA-PRIV-003 删除单次训练

- Priority：P1
- 步骤：
  1. 删除一个 completed session。
- 预期结果：
  - 用户可见训练内容和关联音频删除。
  - ledger 保留。
  - 历史列表移除该 session。

### QA-PRIV-004 删除全部用户数据

- Priority：P0
- 步骤：
  1. 调用 `DELETE /app-users/me/data`。
- 预期结果：
  - 简历、音频、转写、AI payload、历史内容删除或匿名化。
  - token 撤销。
  - 客户端清空本地缓存和 analytics queue。
  - 后续不再发送旧 `app_user_id` 事件。

### QA-PRIV-005 删除失败不显示成功

- Priority：P0
- 步骤：
  1. mock `DATA_DELETION_FAILED`。
- 预期结果：
  - 客户端保留当前内容。
  - UX 展示 Retry deletion。
  - analytics 包含 `api_error_received`。

---

## 18. API Contract 测试

### QA-API-001 所有响应使用 envelope

- Priority：P0
- 步骤：
  1. 调用每个 v1 API。
- 预期结果：
  - 成功响应包含 `request_id`、`data`、`error = null`。
  - 失败响应包含 `request_id`、`data = null`、`error`。
  - 14 章示例与实际响应一致。

### QA-API-002 OpenAPI path/header 索引完整

- Priority：P1
- 步骤：
  1. 对照 Data / API 14 章 API 列表、13.7 OpenAPI path 和 `docs/api/openapi.yaml`。
- 预期结果：
  - 所有 v1 endpoint 都在 OpenAPI path 索引中出现。
  - 所有写接口都有 `Idempotency-Key`。
  - `docs/api/openapi.yaml` 与 Markdown endpoint 列表一致。

### QA-API-003 训练读取只用聚合接口

- Priority：P0
- 步骤：
  1. 检查客户端网络请求。
- 预期结果：
  - 训练详情、question、follow-up、feedback、redo review 都通过 `GET /training-sessions/{session_id}`。
  - 不调用 `/follow-up`、`/feedback`、`/redo-review` 专项读接口。

---

## 19. Coverage Reference Tables

### 19.1 Required session state coverage

QA 必须至少通过 E2E、mock API 或状态恢复测试覆盖以下 `training_session.status`：

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

QA 必须覆盖以下 `completion_reason`：

- `redo_skipped`
- `redo_review_generated`
- `redo_review_unavailable`

QA 必须覆盖以下 `transcript_quality_status`：

- `usable`
- `too_short`
- `silent`
- `non_english`
- `low_confidence`
- `failed`

### 19.2 Required error code coverage

QA-UX-001 和 QA-AN-004 必须逐项覆盖以下 Data / API v1.1 错误码：

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

### 19.3 Required analytics event coverage

QA-AN-001 至 QA-AN-007 必须至少覆盖以下关键事件：

- `app_bootstrap_completed`
- `home_viewed`
- `resume_upload_completed`
- `resume_parse_completed`
- `training_session_created`
- `question_viewed`
- `first_answer_submitted`
- `follow_up_viewed`
- `follow_up_answer_submitted`
- `feedback_generated`
- `feedback_viewed`
- `redo_submitted`
- `redo_skipped`
- `redo_review_generated`
- `redo_review_viewed`
- `training_session_completed`
- `training_session_abandoned`
- `training_session_failed`
- `paywall_viewed`
- `purchase_verified`
- `purchase_restored`
- `api_error_received`

---

## 20. Regression Checklist

每次修改 Prompt、Data/API、Client UX、Analytics、iOS Screen 或 iOS UI Design 文档后，至少回归：

1. QA-E2E-001 完整 redo 闭环。
2. QA-E2E-002 skip redo。
3. QA-AI-006 redo review 失败不影响主 feedback。
4. QA-SESSION-002 active session exists。
5. QA-IDEMP-001 创建 session 重试。
6. QA-IDEMP-005 Apple verify 重试。
7. QA-AI-003 Feedback 输出结构。
8. QA-PRIV-001 / QA-PRIV-002 删除简历两种模式。
9. QA-ASR-002 至 QA-ASR-007 转写质量枚举。
10. QA-AN-007 隐私禁止字段拦截。
11. QA-UX-004 Home priority collision matrix。
12. QA-IOS-001 / QA-IOS-001A 全局 CTA 映射与 Home-first navigation。
13. QA-IOS-002 Privacy Notice 路由闭环。
14. QA-IOS-003 UI Design / Wireframe 合同。
15. QA-AN-008 Home primary state analytics。

---

## 21. Traceability Matrix

| Requirement area | 覆盖测试 |
|---|---|
| PRD 最小完整训练闭环 | QA-E2E-001, QA-E2E-002 |
| Resume-first 个性化 | QA-RESUME-001, QA-AI-001 |
| 简历不可训练不生成问题 | QA-RESUME-004 |
| One question, one follow-up | QA-AI-002 |
| Feedback 固定 5 段 | QA-AI-003 |
| visible assessments 服务端映射 | QA-AI-003, QA-AI-004 |
| Redo delta review | QA-AI-004 |
| Active session 限制 | QA-SESSION-002, QA-SESSION-003 |
| Credit reserve / consume / release | QA-SESSION-001, QA-BILL-001, QA-BILL-002 |
| Apple IAP 入账 | QA-BILL-004, QA-BILL-005, QA-BILL-006 |
| 幂等写请求 | QA-IDEMP-001 至 QA-IDEMP-006 |
| Client 错误处理 | QA-UX-001 |
| Home primary state 优先级 | QA-UX-004, QA-AN-008 |
| iOS CTA / route / sheet 闭环 | QA-IOS-001, QA-IOS-001A, QA-IOS-002 |
| iOS UI Design / Wireframe 合同 | QA-IOS-003 |
| Analytics 主漏斗与状态观测 | QA-AN-001 至 QA-AN-008 |
| 隐私和删除 | QA-PRIV-001 至 QA-PRIV-005 |
| API envelope 与 OpenAPI | QA-API-001, QA-API-002 |

---

## 22. 最小发布判定

可以进入首轮 TestFlight 的最低条件：

1. P0 全部通过。
2. P1 全部通过，或有明确 owner 和修复日期。
3. P2 失败项不影响主路径、付费、删除、隐私和 analytics 核心指标。
4. 没有已知重复扣费、重复入账、数据删除误导、analytics PII 泄露问题。
5. QA-E2E-001 在 TestFlight sandbox 连续通过 5 次。

---


## 23. 一句话收束

QA / Acceptance Test Plan v1 的目标，是把“简历锚定训练、一次追问、结构化 feedback、redo 闭环、credit/IAP、删除和 analytics”这些跨文档规则变成可执行验收项，防止 v1 在联调阶段出现主路径能跑但状态、计费、隐私或观测不可验收的问题。
