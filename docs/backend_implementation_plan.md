# 契合后端实现规划

## 目标

把当前 FastAPI MVP 后端升级为支持“合同工作台”的后端：

- 支持审查立场。
- 支持文档块、风险定位、修改记录。
- 支持审查/生成异步任务进度。
- 支持邮箱验证码登录。
- 支持积分、激活码和 StoreKit 权益入账。
- 支持多人使用时的数据归属、持久化、并发控制和文件清理。
- 保持现有 `/api/contracts/run` 兼容，避免前端一次性大迁移。

## 当前后端结构

```txt
backend/app/
  api/
    auth.py            注册、登录、me
    chat.py            AI 对话
    contracts.py       /run 和 /export/word
    files.py           文件上传
    health.py          健康检查
    deps.py            登录鉴权
  models/
    auth.py
    chat.py
    contracts.py       ContractRunRequest、ReviewResult、GenerateResult
    files.py
  services/
    auth.py
    chat.py
    contracts/
      common.py        text/file_id 输入解析
      review.py        合同审查
      generate.py      合同生成
      export_word.py   Word 导出
    files/
      extractor.py     PDF/DOCX/TXT 文本抽取
      storage.py       上传文件和 metadata
    llm/
      qwen.py
      dify.py
      base.py
  prompts/
    review.md
    generate.md
```

当前合同入口：

```txt
POST /api/contracts/run
  mode=review   -> services/contracts/review.py
  mode=generate -> services/contracts/generate.py

POST /api/files/upload
  保存文件 -> 抽取文本 -> 保存 metadata -> 返回 file_id/text_preview
```

## 后端架构原则

1. 先做多人使用基础设施，再做上层功能。
2. 所有持久数据统一进入一个 SQLite 数据库，避免 auth、jobs、quota 分散成多个库。
3. 生产数据库必须放在持久目录，不放 `/tmp`。
4. 所有用户资源都必须有 `owner_user_id`，包括 files、jobs、documents、revisions、credits。
5. 保持当前同步接口兼容，新功能用新增字段、新增接口渐进式接入。
6. 合同能力统一围绕 Document、Block、Risk、Revision 建模。
7. 积分扣费放在后端 job runner 或合同服务成功路径里，不在前端扣。
8. MVP 积分策略是“执行前检查余额，成功后扣费，失败不扣”，暂不做冻结积分。
9. 激活码和 StoreKit 都只是权益来源，业务只依赖统一积分余额。
10. 文件要有过期策略，避免多用户上线后 `uploads/` 爆盘。

## 目标目录结构

```txt
backend/app/
  api/
    contracts.py        保留 run/export，新增 jobs 和 revisions 入口
    jobs.py             任务状态查询
    entitlements.py     积分和激活码
    storekit.py         StoreKit 交易校验
    auth.py             增加邮箱验证码接口
  models/
    contracts.py        增加 Block、Revision、DocumentSource
    jobs.py
    entitlements.py
    files.py            增加 owner_user_id、expires_at
  services/
    db.py               统一 SQLite 连接、schema 初始化、WAL
    contracts/
      segmenter.py      文本分块
      revise.py         应用建议、确认修改
      review.py         审查立场、风险绑定 block
      generate.py       生成 blocks
      export_word.py    导出修改后版本
    documents/
      store.py          原文、blocks、revisions 存储
    files/
      cleanup.py        过期文件清理
    jobs/
      store.py          job 状态存储
      runner.py         后台任务执行
    billing/
      quota.py          积分检查、扣减、退回
      activation.py     激活码生成、兑换
      storekit.py       Apple 交易验证和入账
```

## 任务零：多人使用基础设施

这项必须先做。它不直接改产品 UI，但决定后面 jobs、验证码、积分、文件归属能不能稳定扩展。

### 1. 统一 SQLite 单库

当前问题：

- `auth.py` 使用 `settings.auth_db_path`。
- 默认路径曾是 `/tmp/qihe-auth.sqlite3`。
- 后续 jobs、quota、验证码如果各自建库，会造成数据分散。
- `/tmp` 在服务器重启或清理后可能丢数据，不适合生产账号和积分。

目标：

- 新增统一配置 `QIHE_DB_PATH`。
- 本地默认：`backend/data/qihe.db`。
- 生产建议：`/var/lib/qihe/qihe.db`。
- `AUTH_DB_PATH` 先保留兼容，但内部逐步迁移到 `settings.db_path`。

新增文件：

- `backend/app/services/db.py`

职责：

```python
def connect() -> sqlite3.Connection
def init_schema() -> None
```

连接要求：

```python
conn.execute("PRAGMA journal_mode=WAL")
conn.execute("PRAGMA foreign_keys=ON")
```

验收：

- auth、验证码、jobs、积分都使用同一个 DB path。
- 本地测试仍可以 monkeypatch 到临时 DB。
- 生产文档不再推荐把真实 DB 放 `/tmp`。

### 2. 统一资源归属字段

从任务零开始，新增表都必须包含：

```txt
owner_user_id
created_at
updated_at
```

适用资源：

```txt
files
jobs
documents
revisions
user_credits
credit_transactions
storekit_transactions
```

原则：

- 用户只能访问自己的 file/job/document/revision。
- 后端根据 token 得到 user_id，不能相信前端传入 owner。
- 查询接口和写接口都要做归属校验。

### 3. StoredFile 兼容 owner_user_id 和 expires_at

当前问题：

- `StoredFile` 是 `@dataclass(frozen=True)`。
- metadata 用 `json.dumps(asdict(stored_file))` 存文件。
- 直接新增必填字段会导致老 metadata 反序列化失败。

修改：

```python
@dataclass(frozen=True)
class StoredFile:
    file_id: str
    filename: str
    content_type: str | None
    suffix: str
    path: str
    char_count: int = 0
    text_preview: str = ""
    owner_user_id: int | None = None
    created_at: str | None = None
    expires_at: str | None = None
```

`load_metadata` 必须兼容老文件：

```python
data.setdefault("owner_user_id", None)
data.setdefault("created_at", None)
data.setdefault("expires_at", None)
return StoredFile(**data)
```

上传新文件：

- 写入 `owner_user_id`。
- 写入 `created_at`。
- 写入 `expires_at`，默认 90 天后。

### 4. 文件归属校验

当前 `find_upload(file_id)` 要升级成：

```python
def find_upload(file_id: str, owner_user_id: int | None = None) -> Path | None
```

校验规则：

- 新文件必须匹配 owner。
- 老 metadata `owner_user_id is None` 可以临时允许读取，作为过渡。
- 后续可加迁移或过期清理，逐步消化老文件。

合同输入解析也要接收当前用户：

```python
resolve_contract_input(request, owner_user_id=user.id)
```

### 5. 文件清理策略

先预留字段，后续实现清理任务。

规则：

```txt
默认文件保留 90 天
删除范围：原文件、metadata、抽取全文
清理方式：cron 或后台定时任务每天执行一次
付费套餐以后可延长保留期
```

新增文件：

- `backend/app/services/files/cleanup.py`

未来命令：

```bash
python -m app.services.files.cleanup
```

验收：

- 新上传 metadata 含 `expires_at`。
- 清理脚本能跳过未过期文件，删除已过期文件。

### 6. 积分扣减时机

MVP 明确不做冻结积分。

策略：

```txt
创建 job 或同步 run 前：预检查余额
AI 成功并生成结果后：事务内扣积分 + 写 credit_transaction
AI 失败：不扣
余额不足：直接返回 402，不创建 job
```

扣费必须在 job runner 或合同服务成功路径中完成，不能只在 API 层“创建任务时扣”。

原因：

- 第一版 job 还未做完整崩溃恢复。
- 如果进队列时冻结积分，进程崩溃可能导致冻结积分永远不释放。

### 7. 并发限制

MVP 不引入复杂队列系统。

规则：

```txt
同一用户最多 1 个 running job
已有 running job 时，新的 review/generate job 返回 409
```

后续再按付费套餐扩展并发数。

### 8. 任务零验收

- `.venv/bin/python -m pytest -q` 通过。
- auth 仍能注册、登录、鉴权。
- SQLite 文件路径可通过 `QIHE_DB_PATH` 覆盖。
- SQLite 开启 WAL 和 foreign keys。
- 老 metadata 文件缺 `owner_user_id/expires_at` 时仍能读取。
- 新上传文件含 `owner_user_id/created_at/expires_at`。
- 同一用户可读取自己的 file_id。
- 不同用户不能读取新文件的 file_id。

## 任务一：审查立场

### 1. ContractRunRequest 增加字段

文件：

- `backend/app/models/contracts.py`

新增：

```python
ReviewPerspective = Literal["party_a", "party_b", "neutral"]

class ContractRunRequest(BaseModel):
    mode: Literal["review", "generate"]
    text: str | None = None
    file_id: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    review_perspective: ReviewPerspective | None = None
```

兼容策略：

- 前端可以直接传顶层 `review_perspective`。
- 也兼容 `metadata["review_perspective"]`。
- 默认 `neutral`。

### 2. review.py 注入 prompt

文件：

- `backend/app/services/contracts/review.py`
- `backend/app/prompts/review.md`

逻辑：

```txt
party_a  -> 站在甲方利益角度识别风险并给修改建议
party_b  -> 站在乙方利益角度识别风险并给修改建议
neutral  -> 中立审查，兼顾双方公平性
```

验收：

- 传不同立场时 prompt 中包含对应说明。
- 不传时保持原有中立行为。
- 现有测试仍通过。

## 任务二：文档块和修改记录

### 1. 数据模型

文件：

- `backend/app/models/contracts.py`

新增：

```python
class ContractBlock(BaseModel):
    block_id: str
    order: int
    title: str | None = None
    text: str
    start_offset: int | None = None
    end_offset: int | None = None
    type: str = "general"

class ContractRevision(BaseModel):
    revision_id: str
    block_id: str
    risk_id: str | None = None
    before_text: str
    after_text: str
    source: Literal["user", "suggestion", "ai"] = "user"
    status: Literal["draft", "confirmed", "applied"] = "draft"

class DocumentSource(BaseModel):
    document_id: str | None = None
    file_id: str | None = None
    filename: str | None = None
    text_preview: str
    char_count: int
```

扩展：

```python
class ReviewResult(BaseModel):
    ...
    blocks: list[ContractBlock] = Field(default_factory=list)
    revisions: list[ContractRevision] = Field(default_factory=list)

class GenerateResult(BaseModel):
    ...
    blocks: list[ContractBlock] = Field(default_factory=list)
    revisions: list[ContractRevision] = Field(default_factory=list)
```

### 2. 文本分块服务

新增：

- `backend/app/services/contracts/segmenter.py`

职责：

- 把合同全文拆成 blocks。
- 识别标题、条款编号、普通段落。
- 生成稳定 `block_id`。
- 保留 `start_offset/end_offset`。

MVP 分块规则：

```txt
按换行和条款编号拆分：
第X条
一、
（一）
1.
没有编号则按段落拆
```

### 3. 风险绑定 block

文件：

- `backend/app/services/contracts/review.py`

做法：

- review 输出风险后，用 `start_offset/end_offset` 或 `original_excerpt` 匹配 block。
- `ClauseReview` 增加 `block_id`。

验收：

- 每个可定位风险尽量有 `block_id`。
- 风险定位失败时仍返回风险项，不中断审查。

### 4. 生成合同输出 blocks

文件：

- `backend/app/services/contracts/generate.py`

做法：

- `draft` 仍保留。
- 对 `draft` 调用 `segmenter.segment_text`。
- 返回 `blocks`。

验收：

- 旧前端仍使用 `draft`。
- 新前端优先使用 `blocks`。

## 任务三：修改建议应用

新增：

- `backend/app/services/contracts/revise.py`

新增接口：

- `POST /api/contracts/apply-suggestion`
- `POST /api/contracts/revisions/{revision_id}/confirm`

请求示例：

```json
{
  "document_id": "doc_xxx",
  "block_id": "block_3",
  "risk_id": "risk_1",
  "after_text": "用户确认后的条款文本"
}
```

返回：

```json
{
  "revision_id": "rev_xxx",
  "block_id": "block_3",
  "before_text": "...",
  "after_text": "...",
  "status": "draft"
}
```

验收：

- 应用建议不会覆盖其他 block。
- 同一个 block 多次修改有版本记录。
- 确认后 status 变为 `confirmed`。

## 任务四：原文全文存储

当前 `files.storage` 只保存 metadata 和原文件。需要增加抽取文本存储，并继承任务零的 `owner_user_id/expires_at` 策略。

文件：

- `backend/app/services/files/storage.py`

新增：

```python
def extracted_text_path(file_id: str) -> Path
def save_extracted_text(file_id: str, text: str) -> None
def load_extracted_text(file_id: str) -> str | None
```

文件上传时：

- `api/files.py` 抽取文本后保存全文。

新增接口：

- `GET /api/files/{file_id}/text`

注意：

- 必须鉴权。
- 必须校验 `owner_user_id`，用户只能读取自己的文件。
- 老 metadata 无 owner 的文件只在过渡期允许读取。

验收：

- 上传文件后可以获取完整抽取文本。
- 原文页不再只能显示 240 字预览。

## 任务五：任务进度 jobs

新增：

```txt
backend/app/api/jobs.py
backend/app/models/jobs.py
backend/app/services/jobs/store.py
backend/app/services/jobs/runner.py
```

接口：

```txt
POST /api/contracts/review-jobs
POST /api/contracts/generate-jobs
GET  /api/jobs/{job_id}
```

Job 响应：

```python
class JobStep(BaseModel):
    key: str
    title: str
    status: Literal["pending", "running", "done", "failed"]

class ContractJobResponse(BaseModel):
    job_id: str
    status: Literal["queued", "running", "succeeded", "failed"]
    progress: int
    current_step: str | None = None
    steps: list[JobStep]
    result: ContractRunResponse | None = None
    error: APIError | None = None
```

MVP 存储：

- 使用统一 SQLite 单库，不再优先用内存 dict。
- job 必须绑定 `owner_user_id`。
- 同一用户最多 1 个 running job。
- 多实例部署再迁移 Redis 或专用队列。

验收：

- 创建 job 立即返回。
- 前端轮询能看到步骤变化。
- 成功后返回完整 result。
- 失败能返回错误信息。
- 用户不能查询别人的 job。
- 余额不足时不创建 job，返回 402。

## 任务六：邮箱验证码登录

文件：

- `backend/app/api/auth.py`
- `backend/app/services/auth.py`
- `backend/app/models/auth.py`

新增接口：

```txt
POST /api/auth/send-code
POST /api/auth/verify-code
```

验证码规则：

- 6 位数字。
- 10 分钟有效。
- 60 秒内同邮箱不能重复发送。
- 同邮箱/同 IP 限制发送频次。
- 最多尝试 5 次。
- DB 存 hash，不存明文验证码。

SQLite 表：

```txt
email_verification_codes
  id
  email
  code_hash
  expires_at
  attempts
  consumed_at
  created_at
  ip_hash
```

兼容：

- 先保留密码注册/登录接口。
- 前端隐藏密码入口即可。

验收：

- 正确验证码能换 token。
- 过期、错误、重复使用都失败。
- 响应不暴露邮箱是否注册过。

## 任务七：积分、激活码、StoreKit

新增：

```txt
backend/app/api/entitlements.py
backend/app/api/storekit.py
backend/app/models/entitlements.py
backend/app/services/billing/quota.py
backend/app/services/billing/activation.py
backend/app/services/billing/storekit.py
```

积分规则：

```txt
新用户 +10
审查 -2
生成 -3
激活码 +30/+100/+300
StoreKit 购买按产品入账
```

SQLite 表：

```txt
user_credits
  user_id
  balance
  created_at
  updated_at

credit_transactions
  id
  user_id
  amount
  reason
  reference_id
  job_id
  created_at

activation_codes
  id
  code_hash
  credits
  redeemed_by
  redeemed_at
  expires_at
  created_at

storekit_transactions
  id
  user_id
  transaction_id
  product_id
  credits
  raw_payload
  created_at
```

接口：

```txt
GET  /api/entitlements/me
POST /api/entitlements/activate
POST /api/storekit/transactions
```

扣费位置：

- `POST /api/contracts/run`
- `POST /api/contracts/review-jobs`
- `POST /api/contracts/generate-jobs`

扣费策略：

MVP 第一版：

- 创建 job 或同步 run 前预检查余额。
- 余额不足直接返回 402。
- AI 成功并生成结果后，在同一个 DB 事务中扣费并写 `credit_transactions`。
- AI 失败不扣。
- 一个 `job_id` 只能扣费一次。
- 暂不做冻结积分，避免进程崩溃后冻结积分无法释放。

后续更稳版本：

- job 状态完全持久化后，再考虑冻结积分。
- 成功确认扣费。
- 失败或超时释放冻结。

错误：

```txt
402 insufficient_credits
```

验收：

- 新用户自动有 10 积分。
- 审查成功扣 2。
- 生成成功扣 3。
- 审查/生成失败不扣。
- 同一 job 不重复扣费。
- 积分不足返回 402。
- 激活码只可兑换一次。
- StoreKit 同一 transaction 不重复入账。

## App Store 策略

优先走 Apple StoreKit。

权益统一抽象为：

```txt
source = storekit | activation_code | admin_grant
```

业务只看积分余额，不关心来源。

激活码入口通过远程配置控制：

```json
{
  "activation_code_enabled": false,
  "storekit_enabled": true
}
```

如果 App Store 审核对激活码入口敏感，则隐藏激活码入口，但保留后端能力。

Apple 官方资料：

- In-App Purchase: https://developer.apple.com/in-app-purchase/
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/

## 测试计划

### 后端单元/接口测试

```txt
test_review_perspective.py
test_contract_segmenter.py
test_contract_revisions.py
test_jobs_api.py
test_email_code_auth.py
test_entitlements.py
test_storekit_transactions.py
test_db_infrastructure.py
test_file_ownership.py
test_file_cleanup.py
```

### 必测场景

- 文本审查正常返回风险。
- 上传文件后用 file_id 审查。
- 同一个 file_id 连续审查两次。
- 新文件只能由 owner 访问。
- 老 metadata 缺 owner 字段仍可兼容读取。
- 文件 metadata 含 expires_at。
- 审查立场传 party_a/party_b/neutral。
- 生成合同返回 draft 和 blocks。
- 应用建议生成 revision。
- job 成功返回 result。
- job 失败返回 error。
- 同一用户有 running job 时再次创建 job 返回 409。
- 邮箱验证码过期失败。
- 积分不足返回 402。
- AI 失败不扣积分。
- 激活码重复兑换失败。

## 验收命令

```bash
cd backend
.venv/bin/python -m pytest -q
```

## 任务执行顺序

0. 任务零：统一 DB、资源归属、StoredFile 兼容、文件过期字段、积分扣减策略。
1. `review_perspective` 字段和 prompt 注入。
2. `ContractBlock` / `ContractRevision` 模型。
3. `segmenter.py` 分块服务。
4. `generate.py` 返回 blocks。
5. `review.py` 风险绑定 block。
6. `revise.py` 和应用建议接口。
7. `files.storage` 保存完整抽取文本，并接入 owner 校验。
8. `jobs.py` 和 job runner，使用统一 SQLite 持久化。
9. 邮箱验证码登录。
10. 积分、激活码、StoreKit，采用成功后扣费策略。
