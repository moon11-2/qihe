# 契合后端开发文档

版本：v0.1  
适用端：uni-app H5、iOS WKWebView wrapper  
当前阶段：前端已可用 Mock；后端目标是提供安全稳定的 Dify/AI 代理能力  
最后更新：2026-07-03

## 1. 文档目的

本文档给后端工程师、AI 编程助手和接口联调人员使用。目标是把「契合」移动端 AI 合同助手从本地 Mock 模式接到真实后端。

必须先理解当前产品边界：

- 核心功能只有两类：合同审查、合同生成。
- 首页可以自由输入，Dify 工作流内部可以有 `consult` 兜底分支处理合同知识咨询、普通闲聊和需求澄清；但它不是第三个产品核心功能。
- 前端提交给后端的业务模式只有 `auto`、`review`、`generate`。
- 后端返回给前端的 AI 结果允许 `intent=review`、`intent=generate` 或 `intent=consult`。其中 `consult` 只用于首页聊天/兜底，不进入底部 Tab 或结果页主流程。
- 历史记录当前先本地保存；云同步不是第一阶段必需。
- Dify API Key、模型供应商 Key、Cookie、Token 只能在服务端保存，不能进入前端代码、App 包、GitHub 或日志。

## 2. 系统角色和职责

### 2.1 前端职责

前端负责：

- 收集用户输入、合同正文、文件、本地选择的合同类型和身份。
- 在首页做轻量意图识别，判断进入审查、生成或本地闲聊引导。
- 调用后端代理接口。
- 解析后端返回的 Dify 兼容响应。
- 展示审查结果页、生成结果页、本地历史和设置页。

前端不负责：

- 保存真实 Dify API Key。
- 直接调用 Dify 官方接口。
- 在生产环境解析 PDF/DOCX 正文。
- 判断法律结论的最终有效性。

### 2.2 后端职责

后端负责：

- 暴露 HTTPS API 给 H5/iOS WebView。
- 读取服务端环境变量里的 Dify API Key。
- 转发聊天请求到 Dify App API。
- 转发文件上传到 Dify 文件接口。
- 聚合 Dify 流式响应或兼容 blocking 响应。
- 返回稳定的、前端可解析的 JSON。
- 做超时、错误码、日志脱敏、文件大小限制和基础鉴权。

后端不负责：

- 在第一阶段开发完整账号体系。
- 在第一阶段开发云历史记录。
- 在第一阶段替代律师做法律意见背书。

## 3. 第一阶段必须实现

必须实现以下接口：

| 优先级 | 接口 | 说明 |
| --- | --- | --- |
| P0 | `GET /health` | 健康检查 |
| P0 | `POST /api/dify/chat-messages` | Dify Chat Messages 兼容代理 |
| P0 | `POST /api/dify/files/upload` | Dify 文件上传兼容代理 |

建议第二阶段再实现：

| 优先级 | 接口 | 说明 |
| --- | --- | --- |
| P1 | `POST /api/v1/contracts/analyze` | 业务封装接口，隐藏 Dify 细节 |
| P1 | `POST /api/v1/files` | 业务文件上传接口 |
| P2 | `/api/v1/records` | 云历史记录 |
| P2 | `/api/v1/settings` | 用户设置 |

## 4. 运行环境变量

服务端必须支持以下环境变量：

```env
DIFY_API_BASE_URL=https://api.dify.ai/v1
DIFY_API_KEY=replace-with-server-side-dify-app-key
PORT=3000
REQUEST_TIMEOUT_MS=180000
UPLOAD_MAX_SIZE_MB=20
ALLOWED_ORIGINS=https://your-web-domain.example
```

条款 B-ENV-01：`DIFY_API_KEY` 只能从服务端环境变量读取。  
条款 B-ENV-02：不得将 `DIFY_API_KEY` 返回给前端。  
条款 B-ENV-03：不得在日志中输出 `DIFY_API_KEY`、用户完整合同正文、身份证号、手机号、银行卡号。  
条款 B-ENV-04：开发环境可以允许 `http://127.0.0.1:*`，生产环境必须使用 HTTPS allowlist。  

## 5. 当前前端请求字段

前端服务层文件：`src/services/dify.ts`

当前 TypeScript 结构：

```ts
type DifyIntent = "review" | "generate" | "consult";
type DifyMode = "auto" | "review" | "generate";

interface ContractAnalysisPayload {
  mode: DifyMode;
  query: string;
  contractText: string;
  contractType: string;
  role: string;
  focusAreas: string[];
  requirements: string;
  jurisdiction?: string;
  outputStyle?: string;
  conversationId?: string;
  file?: {
    name: string;
    path: string;
    size?: number;
    type?: string;
  } | null;
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 | 后端处理 |
| --- | --- | --- | --- | --- |
| `mode` | `auto/review/generate` | 是 | 前端希望处理模式 | 原样传 Dify；`auto` 由 Dify 判断为审查、生成或咨询兜底 |
| `query` | string | 是 | 用户原始输入 | 作为 Dify `query` |
| `contractText` | string | 是 | 合同正文或生成需求 | 映射到 Dify `inputs.contract_text` |
| `contractType` | string | 是 | 合同类型，可能是“不确定”或自定义 | 映射到 `inputs.contract_type` |
| `role` | string | 是 | 用户身份或立场 | 映射到 `inputs.role` |
| `focusAreas` | string[] | 否 | 关注点 | 后端可 join 成中文逗号 |
| `requirements` | string | 否 | 额外要求 | 映射到 `inputs.requirements` |
| `jurisdiction` | string | 否 | 默认中国大陆 | 缺省填“中国大陆” |
| `outputStyle` | string | 否 | 默认普通用户可读 | 缺省填“普通用户可读” |
| `conversationId` | string | 否 | Dify 多轮会话 ID | 传给 Dify `conversation_id` |
| `file` | object/null | 否 | 前端本地文件信息 | 实际文件先走上传接口 |

## 6. 枚举和业务口径

### 6.1 模式枚举

前端请求后端时仍只需要三种模式：

```json
["auto", "review", "generate"]
```

其中 `auto` 允许 Dify 内部三分支路由：

```json
["review", "generate", "consult"]
```

口径：`review` 和 `generate` 是产品主线；`consult` 是 Dify 内部兜底线，用于首页闲聊、合同知识咨询、需求不明确时的引导追问。禁止新增独立的 `revise`、`chat`、`qa` 等第四类核心模式。

### 6.2 合同类型建议

前端当前类型抽屉包含：

```json
[
  "不确定",
  "买卖/采购合同",
  "租赁/房屋合同",
  "服务/委托合同",
  "技术/软件合同",
  "劳动/用工合同",
  "工程/装修合同",
  "借款/担保合同",
  "合伙/合作合同",
  "自定义"
]
```

后端应兼容历史或 Dify 中可能出现的同义名称，例如：

- `房屋租赁合同` 等价于 `租赁/房屋合同`
- `技术/软件合同` 可覆盖软件开发、系统开发、技术服务
- `不确定` 表示允许 AI 根据文本推断

### 6.3 用户身份建议

前端当前简化为：

```json
["甲方", "乙方", "中立", "未知"]
```

后端和 Dify Prompt 可以扩展理解：

- `甲方`：默认我方/委托方/出租方/付款方，需结合文本判断。
- `乙方`：默认对方/服务方/承租方/收款方，需结合文本判断。
- `中立`：尽量同时提示双方风险。
- `未知`：不要假设用户立场，先给中立提示。

## 7. 接口一：健康检查

```http
GET /health
```

成功响应：

```json
{
  "ok": true,
  "service": "qihe-api",
  "version": "0.1.0",
  "difyConfigured": true,
  "time": "2026-07-03T12:00:00.000Z"
}
```

条款 B-HEALTH-01：`/health` 不需要鉴权。  
条款 B-HEALTH-02：`difyConfigured` 可以返回布尔值，但不能返回 Key 内容。  
条款 B-HEALTH-03：健康检查不得触发真实 Dify 调用。  

## 8. 接口二：Dify 聊天代理

当前前端默认调用路径：

```http
POST /api/dify/chat-messages
Content-Type: application/json
```

### 8.1 前端请求示例

```json
{
  "inputs": {
    "mode": "generate",
    "contract_text": "生成一份租房合同，我是房东，租期一年，押一付三，想保护出租方权益。",
    "contract_type": "租赁/房屋合同",
    "role": "甲方",
    "focus_areas": "双方信息，价款报酬，履行安排，违约责任",
    "requirements": "需包含条款：双方信息、价款报酬、履行安排、违约责任\n补充约定：押一付三，保护出租方权益",
    "jurisdiction": "中国大陆",
    "output_style": "普通用户可读"
  },
  "query": "生成一份租房合同，我是房东，租期一年，押一付三，想保护出租方权益。",
  "response_mode": "blocking",
  "conversation_id": "",
  "user": "qihe-h5-1780000000000-abcd12"
}
```

### 8.2 后端转发到 Dify

后端请求 Dify：

```http
POST {DIFY_API_BASE_URL}/chat-messages
Authorization: Bearer {DIFY_API_KEY}
Content-Type: application/json
```

后端转发 Body：

```json
{
  "inputs": {
    "mode": "generate",
    "contract_text": "生成一份租房合同...",
    "contract_type": "租赁/房屋合同",
    "role": "甲方",
    "focus_areas": "双方信息，价款报酬，履行安排，违约责任",
    "requirements": "需包含条款：双方信息、价款报酬、履行安排、违约责任",
    "jurisdiction": "中国大陆",
    "output_style": "普通用户可读"
  },
  "query": "生成一份租房合同...",
  "response_mode": "streaming",
  "conversation_id": "",
  "user": "qihe-h5-1780000000000-abcd12"
}
```

条款 B-CHAT-01：前端可以传 `response_mode=blocking`，后端内部建议改用 `streaming` 调 Dify，再聚合成兼容 blocking 的响应。  
条款 B-CHAT-02：如果后端直接使用 blocking，需要设置至少 180 秒超时。  
条款 B-CHAT-03：后端返回给前端时必须保留 `conversation_id`。  
条款 B-CHAT-04：后端返回 `answer` 时应保持字符串形式，字符串内容必须是 JSON 对象文本。  
条款 B-CHAT-05：Dify 返回非 JSON 文本时，后端应尽量包装成合法 JSON，而不是直接把散文返回给前端。  

### 8.3 前端期望的 Dify 兼容响应

```json
{
  "event": "message",
  "task_id": "task-id",
  "id": "message-id",
  "message_id": "message-id",
  "conversation_id": "conversation-id",
  "mode": "advanced-chat",
  "answer": "{\"intent\":\"generate\",\"status\":\"complete\",\"result_type\":\"contract_draft\",\"contract_title\":\"房屋租赁合同\"}"
}
```

前端会执行：

1. 取 `answer` 字符串。
2. 去除可能的 Markdown fence 或 `<think>...</think>`。
3. `JSON.parse(answer)`。
4. 如果 `intent` 不是 `review/generate/consult`，前端会按 fallback 修正，但后端不应依赖这个兜底。

## 9. 接口三：文件上传代理

```http
POST /api/dify/files/upload
Content-Type: multipart/form-data
```

前端表单字段：

| 字段 | 说明 |
| --- | --- |
| `file` | 文件本体 |
| `user` | 前端生成的用户 ID |

支持文件类型：

```json
[".pdf", ".docx", ".txt", ".md"]
```

暂不承诺：

```json
[".doc", ".pages", ".wps", ".jpg", ".png"]
```

后端转发 Dify：

```http
POST {DIFY_API_BASE_URL}/files/upload
Authorization: Bearer {DIFY_API_KEY}
Content-Type: multipart/form-data
```

成功响应保持 Dify 文件结果：

```json
{
  "id": "upload-file-id",
  "name": "合同.pdf",
  "size": 123456,
  "extension": "pdf",
  "mime_type": "application/pdf"
}
```

条款 B-FILE-01：单文件默认最大 20 MB。  
条款 B-FILE-02：后端必须校验扩展名和 MIME，但不能只信任前端 MIME。  
条款 B-FILE-03：后端第一阶段只做转发，不长期保存合同文件。  
条款 B-FILE-04：若为了调试临时保存文件，必须设置自动清理策略。  
条款 B-FILE-05：文件上传失败时返回标准错误结构，不返回上游完整敏感报文。  

## 10. AI 输出 JSON 契约

### 10.1 通用结构

后端传给前端的 `answer` 字符串必须能解析成以下结构之一。

```ts
type Intent = "review" | "generate" | "consult";
type Status = "complete" | "need_input";

interface ContractResult {
  intent: Intent;
  status?: Status | string;
  result_type?: string;
  title?: string;
  contract_title?: string;
  contract_type?: string;
  role?: string;
  score?: number;
  grade?: "A" | "B" | "C" | "D" | "E" | string;
  grade_label?: string;
  risk_level?: "low" | "medium" | "high" | "unknown" | string;
  score_explanation?: string;
  summary?: string;
  markdown_report?: string;
  contract_markdown?: string;
  missing_fields?: string[];
  followup_questions?: string[];
  key_findings?: Array<Record<string, unknown>>;
  clause_reviews?: Array<Record<string, unknown>>;
  suggested_revisions?: Array<Record<string, unknown>>;
  risk_notes?: Array<string | Record<string, unknown>>;
  signing_checklist?: Array<string | Record<string, unknown>>;
  signature_checklist?: Array<string | Record<string, unknown>>;
  facts?: Record<string, unknown>;
  information_completeness?: Record<string, unknown>;
  legal_references?: Array<Record<string, unknown>>;
  recommended_mode?: "auto" | "review" | "generate" | "consult";
  disclaimer?: string;
}
```

条款 B-OUT-01：顶层必须有 `intent`。  
条款 B-OUT-02：`intent` 只能是 `review`、`generate` 或 `consult`。  
条款 B-OUT-03：AI 不确定是审查还是生成时，如果用户提供了已有合同文本，优先 `review`；如果用户表达“生成/起草/写一份”，优先 `generate`；如果只是闲聊、合同知识咨询或需求无法判断，返回 `consult`。  
条款 B-OUT-04：输出必须是 JSON 对象，不要输出数组作为顶层。  
条款 B-OUT-05：JSON 外不要加解释性自然语言。  
条款 B-OUT-06：可以在字符串字段中使用 Markdown，例如 `contract_markdown`、`markdown_report`。  
条款 B-OUT-07：所有法律结论必须带免责声明。  

### 10.2 审查结果结构

审查结果最小可用示例：

```json
{
  "intent": "review",
  "status": "complete",
  "result_type": "review_report",
  "title": "技术/软件合同审查报告",
  "contract_type": "技术/软件合同",
  "role": "甲方",
  "score": 76,
  "grade": "C",
  "grade_label": "中等风险，风险可控，但关键条款应修改后再使用",
  "risk_level": "medium",
  "score_explanation": "主体和履行事项基本可识别，但付款、验收、违约和争议解决仍需要补强。",
  "summary": "这份合同可以作为沟通基础，但建议先修改付款验收、违约责任和争议解决条款，再进入签署流程。",
  "facts": {
    "合同类型": "技术/软件合同",
    "我方身份": "甲方",
    "审查地区": "中国大陆",
    "文本来源": "粘贴文本"
  },
  "clause_reviews": [
    {
      "clause_title": "付款与验收",
      "risk_level": "medium",
      "issue": "付款节点没有和交付验收结果绑定，可能出现对方未完成交付但仍主张付款的争议。",
      "suggestion": "把付款触发条件写成验收合格后支付，并补充发票、逾期付款和异议处理。",
      "replacement_text": "甲方应在乙方交付成果并经甲方书面验收合格后 7 个工作日内支付对应款项；乙方应同步提供合法有效发票。"
    }
  ],
  "missing_fields": ["对方主体证照信息", "明确签署日期"],
  "followup_questions": ["是否需要我把重点风险改成可直接替换的条款？"],
  "markdown_report": "# 审查结论\n\n这份合同当前可作为沟通基础，但不建议直接签署。",
  "legal_references": [
    {
      "title": "法规知识库未连接",
      "verification_status": "not_connected"
    }
  ],
  "disclaimer": "AI 辅助审查，不构成律师法律意见；重要合同请交由专业律师复核。"
}
```

字段注释：

| 字段 | 前端用途 | 备注 |
| --- | --- | --- |
| `score` | 风险页安全分 | 0-100 |
| `grade` | 风险页等级 | A-E |
| `risk_level` | 风险页风险标签 | 建议用 `low/medium/high/unknown` |
| `summary` | 审查摘要卡 | 普通用户可读，不要写成律师函 |
| `clause_reviews` | 风险卡列表 | 前端取前 5 条 |
| `clause_reviews[].clause_title` | 风险卡标题 | 没有时前端兜底为“风险 1” |
| `clause_reviews[].issue` | 风险卡说明 | 描述问题和影响 |
| `clause_reviews[].replacement_text` | 查看建议展开内容 | 可直接替换条款 |
| `facts` | 主体页 | 当前前端支持对象形式 |
| `markdown_report` | 复制结果 | 完整审查报告 |

### 10.3 生成结果结构

生成结果最小可用示例：

```json
{
  "intent": "generate",
  "status": "complete",
  "result_type": "contract_draft",
  "contract_title": "房屋租赁合同",
  "contract_type": "租赁/房屋合同",
  "role": "甲方",
  "score": 74,
  "grade": "C",
  "grade_label": "可作为初稿，但关键商业信息需补齐",
  "summary": "已按普通用户可读格式生成房屋租赁合同草案，当前仍需补齐主体、金额和履行期限。",
  "missing_fields": [
    "承租方姓名/证件号",
    "房屋地址和面积",
    "租金金额和付款日",
    "租期起止日"
  ],
  "followup_questions": [
    "租金每月多少？",
    "租期从哪天到哪天？",
    "押金金额和退还条件是什么？"
  ],
  "contract_markdown": "# 房屋租赁合同\n\n甲方：[我方信息]\n\n乙方：[待补充]\n\n第一条 合同目的\n\n双方就房屋租赁事宜达成本合同。",
  "risk_notes": [
    "当前缺少关键商业信息，正式使用前必须补齐。",
    "正式签署前建议结合真实交易背景再做一次审查。"
  ],
  "signing_checklist": [
    "确认双方身份信息",
    "补齐房屋地址和交接清单",
    "补齐租金、押金和退还条件",
    "明确维修责任和提前解约条件"
  ],
  "legal_references": [
    {
      "title": "法规知识库未连接",
      "verification_status": "not_connected"
    }
  ],
  "disclaimer": "AI 辅助起草，不构成律师法律意见；重要合同请交由专业律师复核。"
}
```

字段注释：

| 字段 | 前端用途 | 备注 |
| --- | --- | --- |
| `contract_title` | 生成结果页标题 | 必填，展示在合同正文卡片 |
| `grade_label` | 生成摘要标题 | 用一句话说明草案成熟度 |
| `summary` | 生成摘要正文 | 普通用户可读 |
| `contract_markdown` | 合同正文 | 必填，支持 Markdown |
| `missing_fields` | 待补充信息卡 | 数组 |
| `signing_checklist` | 签署前清单卡 | 数组 |
| `disclaimer` | 页底免责声明 | 必填 |

## 11. 信息不足时的输出

如果输入不足，不要编造完整合同或完整审查结论。返回 `status=need_input`。

审查信息不足示例：

```json
{
  "intent": "review",
  "status": "need_input",
  "result_type": "review_report",
  "title": "合同审查",
  "contract_type": "不确定",
  "role": "未知",
  "score": 0,
  "grade": "E",
  "grade_label": "信息严重不足，暂不能完成可靠审查",
  "risk_level": "unknown",
  "summary": "请先提供合同正文或上传合同文件。",
  "missing_fields": ["合同正文"],
  "followup_questions": ["请粘贴合同全文，或上传 PDF/DOCX/TXT 文件。"],
  "markdown_report": "请先提供合同正文。",
  "disclaimer": "AI 辅助审查，不构成律师法律意见；重要合同请交由专业律师复核。"
}
```

生成信息不足示例：

```json
{
  "intent": "generate",
  "status": "need_input",
  "result_type": "contract_draft",
  "contract_title": "合同草案",
  "contract_type": "不确定",
  "role": "未知",
  "score": 0,
  "grade": "E",
  "grade_label": "信息严重不足，暂不能生成可靠合同",
  "summary": "请补充合同类型、双方身份、交易内容、金额和期限。",
  "missing_fields": ["合同类型", "双方身份", "金额", "履行期限"],
  "followup_questions": [
    "你想生成什么类型的合同？",
    "你是甲方还是乙方？",
    "合同金额和履行期限是什么？"
  ],
  "contract_markdown": "",
  "disclaimer": "AI 辅助起草，不构成律师法律意见；重要合同请交由专业律师复核。"
}
```

## 12. 错误响应格式

后端非 2xx 响应统一格式：

```json
{
  "code": "VALIDATION_ERROR",
  "message": "合同正文不能为空",
  "requestId": "req_20260703_abcdef",
  "detail": {
    "field": "contract_text"
  }
}
```

建议错误码：

| HTTP | code | 含义 | 前端表现 |
| --- | --- | --- | --- |
| 400 | `VALIDATION_ERROR` | 参数错误 | Toast |
| 400 | `UNSUPPORTED_FILE_TYPE` | 文件类型不支持 | Toast |
| 413 | `FILE_TOO_LARGE` | 文件过大 | Toast |
| 401 | `UNAUTHORIZED` | 未登录或 token 无效 | 后续登录页 |
| 403 | `QUOTA_EXHAUSTED` | 无额度 | 后续会员页 |
| 408 | `REQUEST_TIMEOUT` | AI 请求超时 | Toast + 可重试 |
| 429 | `RATE_LIMITED` | 请求过频 | Toast |
| 502 | `DIFY_UPSTREAM_ERROR` | Dify 上游错误 | Toast |
| 503 | `AI_SERVICE_UNAVAILABLE` | AI 服务不可用 | Toast |
| 500 | `INTERNAL_ERROR` | 服务端错误 | Toast |

条款 B-ERR-01：错误响应不要包含完整合同正文。  
条款 B-ERR-02：错误响应可以包含 `requestId`，便于后端排查。  
条款 B-ERR-03：Dify 上游错误只返回必要摘要，不要把上游 Authorization、Cookie、完整堆栈暴露给前端。  

## 13. 日志和安全

必须遵守：

- 合同正文默认视为敏感信息。
- 文件默认视为敏感文件。
- 日志只记录摘要，不记录完整正文。
- 生产环境必须启用 HTTPS。
- 生产环境必须配置 CORS allowlist。
- 生产环境必须设置请求体大小限制。
- 上传文件必须限类型、限大小。
- 服务端不要把完整 prompt、完整合同正文、完整模型响应长期落盘，除非产品明确需要并有隐私策略。

建议日志字段：

```json
{
  "requestId": "req_20260703_abcdef",
  "user": "qihe-h5-1780000000000-abcd12",
  "mode": "review",
  "contractType": "技术/软件合同",
  "role": "甲方",
  "textLength": 5300,
  "hasFile": false,
  "difyConversationId": "conv_xxx",
  "durationMs": 18420,
  "status": "success"
}
```

禁止日志字段：

```json
[
  "DIFY_API_KEY",
  "Authorization",
  "Cookie",
  "fullContractText",
  "fullUploadedFileContent",
  "idCardNumber",
  "bankCardNumber"
]
```

## 14. Dify Prompt 输出要求

如果后端或 Dify 工作流需要系统提示词，应明确要求模型：

```text
你是“契合”的合同审查与生成助手。
产品主线只处理两类任务：合同审查 review、合同生成 generate；Dify 内部可用 consult 做首页闲聊、合同知识咨询和需求澄清兜底。
最终回答必须是一个合法 JSON 对象，不要在 JSON 外输出解释文字。
顶层字段 intent 只能是 review、generate 或 consult。
如果用户提供已有合同文本并要求检查风险，输出 review。
如果用户要求起草、生成、拟一份合同，输出 generate。
如果用户只是闲聊、咨询合同知识、询问能做什么或需求无法判断，输出 consult，不要强行生成或审查。
如果信息不足，status 输出 need_input，并用 missing_fields 和 followup_questions 说明需要补充什么。
所有输出必须普通用户可读，不要只写法律术语。
所有结果必须包含 disclaimer。
不要编造法规条文编号；没有法规知识库时，legal_references 标记为 not_connected。
```

## 15. 业务封装接口建议

如果不想长期让前端感知 Dify 兼容接口，第二阶段可以增加：

```http
POST /api/v1/contracts/analyze
Content-Type: application/json
```

请求：

```json
{
  "mode": "auto",
  "query": "我是房东，我想做个租房合同",
  "contractText": "我是房东，我想做个租房合同",
  "contractType": "租赁/房屋合同",
  "role": "甲方",
  "focusAreas": ["双方信息", "价款报酬", "履行安排", "违约责任"],
  "requirements": "需包含条款：双方信息、价款报酬、履行安排、违约责任",
  "jurisdiction": "中国大陆",
  "outputStyle": "普通用户可读",
  "conversationId": ""
}
```

响应：

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "result": {
      "intent": "generate",
      "status": "complete",
      "result_type": "contract_draft"
    },
    "conversationId": "conversation-id",
    "messageId": "message-id",
    "rawAnswer": "{}",
    "source": "dify"
  }
}
```

第一阶段前端不强依赖这个接口；当前已经能直接适配 `/api/dify/chat-messages`。

## 16. 验收清单

后端完成后，用以下清单验收：

- `GET /health` 返回 200，且不泄露任何密钥。
- 没有 `.env.local`、API Key、Cookie、Token 进入 Git。
- `POST /api/dify/chat-messages` 可以完成生成合同请求。
- `POST /api/dify/chat-messages` 可以完成审查合同请求。
- `POST /api/dify/chat-messages` 可以完成首页 consult 兜底回复。
- 返回 `answer` 是可 JSON.parse 的字符串。
- `answer.intent` 只出现 `review`、`generate` 或 `consult`。
- 生成结果包含 `contract_markdown`。
- 审查结果包含 `summary` 和 `clause_reviews`。
- 文件上传接口支持 PDF/DOCX/TXT/MD。
- 文件超过限制时返回标准错误。
- Dify 超时时返回标准错误，不让前端无限等待。
- 服务端日志不包含完整合同正文和密钥。
- iOS WebView 访问本机/线上代理时 CORS、HTTPS、超时设置正常。

## 17. 联调示例

生成合同测试输入：

```json
{
  "mode": "generate",
  "query": "生成一份租房合同，我是房东，租期一年，押一付三，想保护出租方权益。",
  "contractText": "生成一份租房合同，我是房东，租期一年，押一付三，想保护出租方权益。",
  "contractType": "租赁/房屋合同",
  "role": "甲方",
  "focusAreas": ["双方信息", "价款报酬", "履行安排", "违约责任"],
  "requirements": "需包含条款：双方信息、价款报酬、履行安排、违约责任\n补充约定：押一付三，保护出租方权益",
  "jurisdiction": "中国大陆",
  "outputStyle": "普通用户可读"
}
```

审查合同测试输入：

```json
{
  "mode": "review",
  "query": "请审查这份合同：甲方委托乙方开发小程序，合同金额50000元，乙方完成后付款，违约责任双方协商解决。",
  "contractText": "甲方委托乙方开发小程序，合同金额50000元，乙方完成后付款，违约责任双方协商解决。",
  "contractType": "技术/软件合同",
  "role": "甲方",
  "focusAreas": ["付款风险", "违约责任", "争议解决"],
  "requirements": "审查重点：付款风险、违约责任、争议解决",
  "jurisdiction": "中国大陆",
  "outputStyle": "普通用户可读"
}
```

非合同闲聊测试：

```json
{
  "input": "你好"
}
```

期望：前端本地回复引导语，不调用后端业务接口。
