# 契合 v0.1 后端接口交接清单

本文档按当前已有「契合」原型整理，不包含后续大改版需求。当前前端是 uni-app Vue3 + TypeScript，核心能力是：

- 首页自然语言输入，自动判断审查 / 生成；非合同任务在前端做闲聊式引导
- 功能页手动选择「审查合同」或「生成合同」
- 可粘贴合同文本或描述生成需求
- 可上传 PDF / DOCX / TXT / MD 合同文件
- 结果页展示 Dify 返回的 JSON 结果
- 本地记录、设置页目前主要是前端本地状态

## 一、后端最少必须提供

如果只是让当前 App 能稳定内测，后端最少提供 3 个能力：

1. Dify 安全代理
2. 文件上传代理
3. 健康检查

推荐链路：

```text
App / H5 / iOS WebView
  -> 业务后端 HTTPS API
  -> Dify App API
```

Dify App API Key 只能放服务端环境变量，不能放前端代码、App 包、GitHub。

## 二、环境变量

后端需要保存：

```env
DIFY_API_BASE_URL=https://api.dify.ai/v1
DIFY_API_KEY=契合的Dify App API Key
PORT=3000
```

可选：

```env
REQUEST_TIMEOUT_MS=180000
UPLOAD_MAX_SIZE_MB=20
ALLOWED_ORIGINS=https://你的前端域名
```

## 三、当前前端输入字段

前端提交给 AI 的业务字段如下：

```ts
type Mode = "auto" | "review" | "generate";

interface ContractAnalysisPayload {
  mode: Mode;
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

字段解释：

| 字段 | 说明 |
| --- | --- |
| `mode` | `auto` 首页自动判断；`review` 审查；`generate` 生成 |
| `query` | 用户原始问题，首页输入时有值 |
| `contractText` | 合同正文，或生成需求文本 |
| `contractType` | 合同类型 |
| `role` | 用户身份 / 立场 |
| `focusAreas` | 审查关注重点或生成包含条款 |
| `requirements` | 补充说明 |
| `jurisdiction` | 默认中国大陆 |
| `outputStyle` | 默认普通用户可读 |
| `conversationId` | Dify 多轮会话 id，连续追问时复用 |
| `file` | 前端本地文件信息，实际上传走 multipart |

## 四、枚举值

### 合同类型

```json
[
  "买卖/采购合同",
  "房屋租赁合同",
  "劳动/用工合同",
  "服务/委托合同",
  "承揽/加工定作合同",
  "建设工程合同",
  "技术/软件合同",
  "借款/担保合同",
  "其他类型（不确定）",
  "自定义类型"
]
```

### 用户身份

```json
["甲方（我方）", "乙方（对方）", "中立审查", "未知"]
```

首页自动判断时，前端会根据关键词推断：

- 房东 / 出租方 / 出租人：`出租方（我方）`
- 租客 / 承租方 / 承租人：`承租方（我方）`
- 甲方：`甲方（我方）`
- 乙方：`乙方（我方）`

### 审查关注重点

```json
[
  "签约主体",
  "合同事项",
  "付款风险",
  "交付验收",
  "质量标准",
  "违约责任",
  "解除终止",
  "争议解决"
]
```

### 生成包含条款

```json
[
  "双方信息",
  "合作内容",
  "价款报酬",
  "履行安排",
  "交付验收",
  "质量标准",
  "违约责任",
  "争议解决"
]
```

## 五、Dify 代理接口

### 1. 健康检查

```http
GET /health
```

响应：

```json
{
  "ok": true,
  "service": "hetongbang-api"
}
```

### 2. 发送合同处理请求

当前前端可直接适配 Dify 兼容路径：

```http
POST /api/dify/chat-messages
Content-Type: application/json
```

请求体：

```json
{
  "inputs": {
    "mode": "auto",
    "contract_text": "我是房东，我想做个租房合同",
    "contract_type": "房屋租赁合同",
    "role": "出租方（我方）",
    "focus_areas": "双方信息，合作内容，价款报酬，履行安排",
    "requirements": "",
    "jurisdiction": "中国大陆",
    "output_style": "普通用户可读"
  },
  "query": "我是房东，我想做个租房合同",
  "response_mode": "blocking",
  "conversation_id": "",
  "user": "hetongbang-h5-xxxxxx"
}
```

后端处理要求：

- 后端加上请求头：`Authorization: Bearer ${DIFY_API_KEY}`
- 不把 Dify Key 返回给前端
- 建议服务端实际调用 Dify 时使用 `response_mode=streaming`，再聚合成 blocking 响应返回给前端，避免 60 秒超时
- 需要保留并返回 Dify 的 `conversation_id`
- 超时时间建议至少 180 秒

响应体保持 Dify chat-message 形态：

```json
{
  "event": "message",
  "task_id": "task-id",
  "id": "message-id",
  "message_id": "message-id",
  "conversation_id": "conversation-id",
  "mode": "advanced-chat",
  "answer": "{\"intent\":\"generate\",\"status\":\"complete\",\"result_type\":\"contract_draft\"}"
}
```

前端会解析 `answer` 字符串中的 JSON。

### 3. 文件上传

```http
POST /api/dify/files/upload
Content-Type: multipart/form-data
```

表单字段：

| 字段 | 说明 |
| --- | --- |
| `file` | 文件本体 |
| `user` | 前端生成的用户 id |

支持文件：

```json
[".pdf", ".docx", ".txt", ".md"]
```

建议限制：

- 单文件最大 20 MB
- 第一版不承诺 `.doc` 老格式
- 文件只转发给 Dify，除非后端要做记录归档

响应保持 Dify 文件上传结果：

```json
{
  "id": "upload-file-id",
  "name": "合同.pdf",
  "size": 123456,
  "extension": "pdf",
  "mime_type": "application/pdf"
}
```

后续 `/chat-messages` 里的 `inputs.contract_file`：

```json
{
  "type": "document",
  "transfer_method": "local_file",
  "upload_file_id": "upload-file-id"
}
```

## 六、建议后端封装的业务接口

如果后端不想暴露 Dify 兼容路径，可以再封装一层业务接口。前端后续改动会更小。

### 1. 提交合同审查 / 生成

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
  "contractType": "房屋租赁合同",
  "role": "出租方（我方）",
  "focusAreas": ["双方信息", "合作内容", "价款报酬", "履行安排"],
  "requirements": "",
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
    "result": {},
    "conversationId": "conversation-id",
    "messageId": "message-id",
    "rawAnswer": "{}",
    "source": "dify"
  }
}
```

其中 `data.result` 使用第七节的输出结构。

### 2. 上传合同文件

```http
POST /api/v1/files
Content-Type: multipart/form-data
```

响应：

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "fileId": "upload-file-id",
    "name": "合同.pdf",
    "size": 123456,
    "mimeType": "application/pdf",
    "extension": "pdf"
  }
}
```

### 3. 继续追问

当前结果页追问在 Mock 模式下由前端本地解释；Dify 模式下会再次调用当前模式的处理接口，并传入上一次 `conversationId`。后端可以继续兼容 `/api/dify/chat-messages`，也可以提供独立接口：

```http
POST /api/v1/conversations/{conversationId}/messages
```

请求：

```json
{
  "query": "这份合同里押金条款怎么改？",
  "mode": "review",
  "contractType": "租赁/房屋合同",
  "role": "甲方",
  "focusAreas": ["付款风险", "违约责任", "争议解决"],
  "requirements": "当前结果摘要：...\n用户追问：这份合同里押金条款怎么改？",
  "conversationId": "conversation-id"
}
```

响应同 `/api/v1/contracts/analyze`。

## 七、AI 输出结构

输出允许三类，其中 `consult` 只作为首页自由输入的聊天/兜底分支，不是第三个底部功能或核心业务入口：

```ts
type Intent = "review" | "generate" | "consult";
type Status = "complete" | "need_input";
```

### 通用字段

```ts
interface ContractResult {
  intent: "review" | "generate" | "consult";
  status?: "complete" | "need_input" | string;
  result_type?: string;
  title?: string;
  contract_title?: string;
  contract_type?: string;
  role?: string;
  score?: number;
  grade?: "A" | "B" | "C" | "D" | "E" | string;
  grade_label?: string;
  risk_level?: string;
  score_explanation?: string;
  summary?: string;
  markdown_report?: string;
  contract_markdown?: string;
  answer_markdown?: string;
  missing_fields?: string[];
  followup_questions?: string[];
  key_findings?: Array<Record<string, unknown>>;
  clause_reviews?: Array<Record<string, unknown>>;
  suggested_revisions?: Array<Record<string, unknown>>;
  risk_notes?: Array<string | Record<string, unknown>>;
  signing_checklist?: Array<string | Record<string, unknown>>;
  signature_checklist?: Array<string | Record<string, unknown>>;
  facts?: Record<string, unknown> | Array<Record<string, unknown>>;
  information_completeness?: Record<string, unknown>;
  legal_references?: Array<Record<string, unknown>>;
  recommended_mode?: "auto" | "review" | "generate" | "consult";
  disclaimer?: string;
}
```

### 审查结果必备字段

```json
{
  "intent": "review",
  "status": "complete",
  "result_type": "review_report",
  "title": "合同审查报告",
  "contract_type": "技术/软件合同",
  "role": "甲方（我方）",
  "score": 76,
  "grade": "C",
  "grade_label": "中等风险，风险可控，但关键条款应修改后再使用",
  "risk_level": "medium",
  "summary": "这份合同可以作为谈判基础，但不建议直接签署。",
  "key_findings": [],
  "clause_reviews": [],
  "suggested_revisions": [],
  "signature_checklist": [],
  "missing_fields": [],
  "followup_questions": [],
  "markdown_report": "# 审查结论\n\n...",
  "legal_references": [],
  "disclaimer": "AI 辅助审查，不构成律师法律意见；重要合同请交由专业律师复核。"
}
```

### 生成结果必备字段

```json
{
  "intent": "generate",
  "status": "complete",
  "result_type": "contract_draft",
  "contract_title": "房屋租赁合同",
  "contract_type": "房屋租赁合同",
  "role": "出租方（我方）",
  "score": 72,
  "grade": "C",
  "grade_label": "可作为初稿，但关键商业信息需补齐",
  "summary": "已生成房屋租赁合同草案。",
  "missing_fields": [],
  "followup_questions": [],
  "assumptions": [],
  "facts_to_confirm": [],
  "clause_outline": [],
  "contract_markdown": "# 房屋租赁合同\n\n...",
  "risk_notes": [],
  "signing_checklist": [],
  "legal_references": [],
  "next_steps": [],
  "disclaimer": "AI 辅助起草，不构成律师法律意见；重要合同请交由专业律师复核。"
}
```

### 五档评分

| grade | score | 审查含义 | 生成含义 |
| --- | --- | --- | --- |
| A | 90-100 | 低风险，基本可直接使用或签署前做常规确认 | 信息充分，草案结构完整 |
| B | 80-89 | 较低风险，整体可用，但建议优化若干条款 | 整体可用，少量字段需补齐 |
| C | 70-79 | 中等风险，风险可控，但关键条款应修改后再使用 | 可作为初稿，关键商业信息需补齐 |
| D | 60-69 | 较高风险，不建议直接签署或发送 | 信息不足较多，仅适合作为框架 |
| E | 0-59 | 重大风险、信息严重不足或风险不可控 | 信息严重不足，不应生成完整合同 |

## 八、记录相关接口

当前记录页是前端本地 `uni.setStorageSync("qihe-history")`。如果后端要接管记录，需要提供：

### 1. 创建记录

```http
POST /api/v1/records
```

请求：

```json
{
  "title": "房屋租赁合同",
  "meta": "出租方（我方） | 双方信息 / 价款报酬",
  "risk": "C级",
  "riskClass": "medium",
  "fileType": "W",
  "fileClass": "word",
  "result": {}
}
```

响应：

```json
{
  "code": 0,
  "data": {
    "id": "record-id",
    "createdAt": "2026-07-03T10:00:00.000Z"
  }
}
```

### 2. 获取记录列表

```http
GET /api/v1/records?page=1&pageSize=20
```

响应：

```json
{
  "code": 0,
  "data": {
    "items": [
      {
        "id": "record-id",
        "title": "房屋租赁合同",
        "meta": "出租方（我方） | 双方信息 / 价款报酬",
        "risk": "C级",
        "riskClass": "medium",
        "fileType": "W",
        "fileClass": "word",
        "createdAt": "2026-07-03T10:00:00.000Z"
      }
    ],
    "total": 1
  }
}
```

### 3. 获取记录详情

```http
GET /api/v1/records/{id}
```

响应需要包含 `result` 完整对象。

### 4. 删除记录

```http
DELETE /api/v1/records/{id}
```

### 5. 批量删除记录

```http
POST /api/v1/records/batch-delete
```

请求：

```json
{
  "ids": ["record-id-1", "record-id-2"]
}
```

## 九、设置相关接口

当前设置页是前端本地状态。后端可选提供：

### 获取设置

```http
GET /api/v1/settings
```

响应：

```json
{
  "code": 0,
  "data": {
    "autoSaveResults": false,
    "privacyMode": true,
    "notifyEnabled": false,
    "outputStyle": "专业清晰",
    "jurisdiction": "中国大陆"
  }
}
```

### 更新设置

```http
PATCH /api/v1/settings
```

请求：

```json
{
  "autoSaveResults": true,
  "privacyMode": true,
  "notifyEnabled": false
}
```

## 十、账号相关接口

当前原型显示“未登录”。如果后端要做账号体系，至少需要：

```http
GET /api/v1/me
POST /api/v1/auth/login
POST /api/v1/auth/logout
POST /api/v1/auth/refresh
```

`GET /api/v1/me` 响应示例：

```json
{
  "code": 0,
  "data": {
    "id": "user-id",
    "nickname": "岚天",
    "phone": "",
    "membership": "free",
    "remainingQuota": 20
  }
}
```

## 十一、任务状态接口

如果后端把 AI 调用做成异步任务，可提供：

```http
POST /api/v1/tasks
GET /api/v1/tasks/{taskId}
POST /api/v1/tasks/{taskId}/cancel
```

状态枚举：

```json
["queued", "running", "succeeded", "failed", "canceled"]
```

当前前端还没有任务轮询 UI。如果后端采用异步任务，前端需要小改。

## 十二、错误码建议

统一错误格式：

```json
{
  "code": 40001,
  "message": "合同正文不能为空",
  "detail": {}
}
```

建议错误码：

| code | 含义 |
| --- | --- |
| `0` | 成功 |
| `40001` | 参数错误 |
| `40002` | 文件类型不支持 |
| `40003` | 文件过大 |
| `40101` | 未登录 |
| `40301` | 无权限或额度不足 |
| `40801` | AI 请求超时 |
| `42901` | 请求过于频繁 |
| `50001` | 服务端错误 |
| `50201` | Dify 上游错误 |
| `50301` | AI 服务暂不可用 |

## 十三、安全要求

后端必须做到：

- Dify API Key 只放服务端环境变量
- 前端永远不能拿到 Dify API Key
- 上传文件限制类型和大小
- 记录用户请求日志时不要明文长期保存完整合同，除非产品明确需要
- 合同文本属于敏感信息，生产环境建议加密存储
- 服务端日志不要打印完整合同正文、身份证号、手机号、银行卡号等敏感内容
- HTTPS 必须开启
- App 调用后端建议加用户 token 或设备 token

## 十四、当前前端需要改的配置

后端域名确定后，前端只需要改：

```env
VITE_DIFY_ENABLED=true
VITE_DIFY_PROXY_PATH=https://api.example.com/api/dify
```

如果使用业务封装接口 `/api/v1/contracts/analyze`，则需要小改 `src/services/dify.ts`，把 Dify 兼容请求换成业务接口请求。

## 十五、给后端的优先级

第一阶段必须做：

- `GET /health`
- `POST /api/dify/chat-messages`
- `POST /api/dify/files/upload`
- 服务端 Dify Key 管理
- streaming 聚合，避免 60 秒超时

第二阶段建议做：

- `POST /api/v1/contracts/analyze`
- `POST /api/v1/files`
- 记录列表 / 记录详情 / 删除记录
- 用户设置

第三阶段再做：

- 登录注册
- 会员额度
- 合同记录云同步
- 异步任务状态
- 法规知识库引用
- 运营后台和日志审计
