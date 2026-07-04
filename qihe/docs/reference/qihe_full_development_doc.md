# 契合完整开发文档 v1.0

更新时间：2026-07-04  
产品名：契合  
目标平台：iPhone  
最低系统：iOS 17  
当前状态：开发前定稿文档，尚未开始编码

## 1. 项目目标

`契合` 是一款部署到 iPhone 的 AI 合同审查与生成助手。

第一版目标是做一个边界清晰、体验完整、可以真机测试的 MVP：

- 用户可以自由聊天。
- 用户可以粘贴或上传合同并发起合同审查。
- 用户可以描述需求并生成合同草案。
- 用户可以查看审查报告，包括原文、风险、主体信息。
- 用户可以查看生成合同，包括待补充信息、签署前清单。
- 审查报告和生成合同都可以导出 Word。
- 历史记录只保存在 iPhone 本地。

## 2. 已确认决策

### 2.1 产品范围

第一版包含：

- 自由聊天
- 合同审查
- 合同生成
- PDF / Word / TXT 上传
- 审查报告 Word 导出
- 合同草案 Word 导出
- 本地历史

第一版不包含：

- 登录
- 会员
- 云端历史
- 图片上传
- 图片 OCR
- 法律研究
- 法条检索
- 案例检索
- 类案分析
- 工商检索
- 客服
- 底部导航

### 2.2 技术选型

iPhone App：

- SwiftUI
- iOS 17+
- Swift Concurrency
- SwiftData
- FileManager
- Document Picker
- Share Sheet

后端：

- Python
- FastAPI
- Pydantic
- httpx
- python-docx
- pypdf 或 pdfplumber
- python-multipart

AI 能力：

- 千问，OpenAI 兼容格式
- 聊天：千问
- 合同审查：千问
- 合同生成：第一版千问
- Dify：只预留合同生成 provider，不作为第一版必需能力

部署：

- 第一阶段本地和测试环境
- iPhone 真机调试
- 后续 TestFlight

## 3. 视觉设计基准

当前前端设计按 v3 执行：`文书 · 印鉴 × 法务藏青`。

设计源文件：

- `outputs/qihe_frontend_prototype.html`
- `outputs/qihe_frontend_design_spec.md`

核心视觉规则：

- 主背景：暖白纸色。
- 标题：宋体气质。
- 品牌：朱砂印章 `契`。
- 主操作：法务藏青。
- 高风险：朱砂。
- 中风险：赭黄。
- 完成状态：松绿。
- 图标：SF Symbols 风格线性图标。

核心颜色：

```txt
墨色        #1D2129
法务藏青    #23405F
朱砂        #C23528
纸色        #F7F5F0
卡片纸色    #FEFDFB
线色        #E5E1D8
强线色      #D0CBBE
赭黄        #B07F1E
松绿        #3D7A5C
```

字体规则：

- 标题、合同正文、印章：宋体类字体。
- UI 文本：系统无衬线字体。

## 4. 总体架构

```txt
iPhone App / SwiftUI
  |
  | HTTPS JSON / Multipart / Word download
  v
FastAPI Backend
  |
  | OpenAI-compatible API
  v
Qwen

FastAPI Backend
  |
  | optional future provider
  v
Dify
```

后端只做 AI 网关、文件处理、结构化整理、Word 导出。

前端只做交互、展示、本地历史、文件选择、导出分享。

## 5. 仓库结构建议

当前还未开始编程。开始后建议使用一个 monorepo：

```txt
qihe/
  backend/
    app/
      main.py
      core/
        config.py
        errors.py
      api/
        health.py
        chat.py
        files.py
        contracts.py
      models/
        chat.py
        files.py
        contracts.py
        errors.py
      services/
        llm/
          base.py
          qwen.py
          dify.py
        files/
          extractor.py
          storage.py
        contracts/
          review.py
          generate.py
          export_word.py
      prompts/
        intent.md
        chat.md
        review.md
        generate.md
      tests/
    pyproject.toml
    .env.example

  ios/
    Qihe/
      QiheApp.swift
      App/
      DesignSystem/
      Features/
        Home/
        History/
        Chat/
        Review/
        Generate/
        Results/
      Data/
        API/
        LocalStore/
        Models/
      Resources/
    Qihe.xcodeproj

  docs/
    api.md
    deployment.md
    prompts.md
```

## 6. 后端设计

### 6.1 后端职责

后端负责：

- 千问 API 调用
- 意图识别
- 合同审查
- 合同生成
- 文件上传
- PDF / Word / TXT 文本抽取
- 结构化 JSON 校验
- Word 导出
- 统一错误处理

后端不负责：

- 登录
- 会员
- 云端历史
- 用户身份系统
- 图片 OCR
- 案例 / 法规 / 工商检索

### 6.2 环境变量

```env
APP_ENV=local
APP_NAME=qihe-api

CHAT_MODEL_API_KEY=
CHAT_MODEL_BASE_URL=
CHAT_MODEL_NAME=

GENERATE_PROVIDER=qwen

DIFY_API_BASE_URL=https://api.dify.ai/v1
DIFY_API_KEY=

UPLOAD_MAX_MB=20
REQUEST_TIMEOUT_MS=60000
FILE_TTL_SECONDS=86400

CORS_ALLOW_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
```

说明：

- `CHAT_MODEL_*` 使用千问 OpenAI 兼容接口。
- `GENERATE_PROVIDER=qwen` 是第一版默认值。
- `DIFY_*` 只作为未来预留。
- 后端不把任何模型 Key 下发给 iPhone App。

### 6.3 后端接口列表

```txt
GET  /api/health
POST /api/chat
POST /api/files/upload
POST /api/contracts/run
POST /api/contracts/export/word
```

### 6.4 通用错误格式

```json
{
  "type": "error",
  "code": "DIFY_TIMEOUT",
  "message": "处理时间较长，请稍后重试。",
  "detail": {}
}
```

错误码：

```txt
VALIDATION_ERROR
INVALID_FILE_TYPE
FILE_TOO_LARGE
FILE_EMPTY
FILE_EXTRACT_FAILED
FILE_NOT_FOUND
MODEL_TIMEOUT
MODEL_BAD_RESPONSE
MODEL_JSON_REPAIR_FAILED
CONTRACT_MODE_INVALID
EXPORT_WORD_FAILED
DIFY_TIMEOUT
DIFY_BAD_RESPONSE
INTERNAL_ERROR
```

前端展示原则：

- 用户只看 `message`。
- `code` 用于前端分支和调试。
- `detail` 不展示给普通用户。

## 7. API 详细设计

### 7.1 健康检查

`GET /api/health`

返回：

```json
{
  "status": "ok",
  "app": "qihe-api",
  "env": "local"
}
```

### 7.2 自由聊天

`POST /api/chat`

用途：

- 普通聊天。
- 判断用户是否要进入合同审查或合同生成。
- 不直接执行合同任务。

请求：

```json
{
  "message": "我想写一份租房合同",
  "local_thread_id": "local_123",
  "context": [
    {
      "role": "user",
      "content": "你好"
    },
    {
      "role": "assistant",
      "content": "你好，我可以帮你审查或生成合同。"
    }
  ]
}
```

返回：普通聊天

```json
{
  "type": "chat",
  "intent": "chat",
  "reply": "可以，你可以把合同内容发给我，或者描述你想生成的合同。",
  "prefill": {}
}
```

返回：引导生成

```json
{
  "type": "route",
  "intent": "generate",
  "reply": "我会按合同生成来处理。你可以补充租期、租金、押金和双方身份。",
  "prefill": {
    "requirements": "我想写一份租房合同",
    "contract_type": "房屋租赁合同"
  }
}
```

返回：不确定

```json
{
  "type": "need_input",
  "intent": "unknown",
  "reply": "你是想审查已有合同，还是生成一份新合同？",
  "options": ["review", "generate"],
  "prefill": {}
}
```

字段枚举：

```txt
type: chat | route | need_input | error
intent: chat | review | generate | unknown
```

### 7.3 文件上传

`POST /api/files/upload`

Content-Type：

```txt
multipart/form-data
```

字段：

```txt
file: binary
```

允许文件：

```txt
.pdf
.doc
.docx
.txt
```

不允许：

```txt
图片、压缩包、音视频、可执行文件
```

返回：

```json
{
  "file_id": "local_file_8f4a9d",
  "filename": "租赁合同.pdf",
  "mime_type": "application/pdf",
  "size": 123456,
  "text_excerpt": "合同编号：...甲方：...",
  "text_length": 5820
}
```

后端处理：

1. 校验大小。
2. 校验扩展名。
3. 校验 MIME。
4. 读取文件。
5. 抽取文本。
6. 临时保存文件和文本。
7. 返回 `file_id`。

注意：

- 第一版后端可以用临时本地文件存储。
- 不做云端永久保存。
- 文件过期后自动清理。

### 7.4 合同任务执行

`POST /api/contracts/run`

用途：

- 合同审查。
- 合同生成。

请求：

```json
{
  "mode": "review",
  "query": "帮我看看这份合同有没有风险",
  "contract_text": "合同正文...",
  "file_id": "local_file_8f4a9d",
  "contract_type": "房屋租赁合同",
  "role": "甲方（我方）",
  "focus_areas": [],
  "requirements": "",
  "conversation_id": "",
  "jurisdiction": "中国大陆",
  "output_style": "普通用户可读"
}
```

字段规则：

- `mode` 只允许 `review` 或 `generate`。
- 审查时 `contract_text` 和 `file_id` 至少提供一个。
- 生成时 `requirements` 或 `query` 至少提供一个。
- `file_id` 存在时，后端用文件抽取文本补齐 `contract_text`。

审查返回：

```json
{
  "type": "review_result",
  "intent": "review",
  "status": "complete",
  "conversation_id": "conv_local_123",
  "message_id": "msg_123",
  "result": {
    "title": "合同审查报告",
    "summary": "这份合同存在 3 个重点风险。",
    "score": 76,
    "grade": "C",
    "grade_label": "中等风险",
    "review_basis": "中国大陆现行法律",
    "original_text": "合同原文",
    "facts": {
      "party_a": "上海某某公司",
      "party_b": "",
      "amount": "",
      "term": "",
      "contract_type": "房屋租赁合同",
      "jurisdiction": "中国大陆"
    },
    "clause_reviews": [
      {
        "id": "risk_1",
        "risk_level": "high",
        "clause_title": "付款与验收",
        "clause_ref": "第四条 付款方式 / 第六条 验收",
        "issue": "尾款支付与验收标准绑定不清。",
        "impact": "可能产生付款争议。",
        "suggestion": "补充验收标准和付款前置条件。",
        "replacement_text": "乙方完成交付后，甲方应在约定期限内验收；经甲方书面确认验收合格后，双方共同签署验收单，甲方再支付对应尾款。",
        "legal_basis": [
          "《民法典》第五百零九条",
          "《民法典》第六百二十一条"
        ]
      }
    ],
    "disclaimer": "AI 辅助审查，不构成法律意见。"
  }
}
```

生成返回：

```json
{
  "type": "generate_result",
  "intent": "generate",
  "status": "complete",
  "conversation_id": "conv_local_456",
  "message_id": "msg_456",
  "result": {
    "contract_title": "房屋租赁合同",
    "summary": "已生成一份房屋租赁合同草案。",
    "contract_markdown": "# 房屋租赁合同\n\n甲方：...",
    "missing_fields": ["甲方完整名称", "租赁期限", "租金金额"],
    "signing_checklist": ["确认双方主体信息", "确认租金和押金"],
    "disclaimer": "AI 辅助起草，不构成法律意见。"
  }
}
```

### 7.5 Word 导出

`POST /api/contracts/export/word`

用途：

- 导出审查报告 Word。
- 导出生成合同 Word。

请求：审查报告

```json
{
  "type": "review",
  "title": "房屋租赁合同审查报告",
  "result": {
    "title": "合同审查报告",
    "summary": "这份合同存在 3 个重点风险。",
    "score": 76,
    "grade": "C",
    "grade_label": "中等风险",
    "review_basis": "中国大陆现行法律",
    "facts": {},
    "clause_reviews": [],
    "disclaimer": "AI 辅助审查，不构成法律意见。"
  }
}
```

请求：生成合同

```json
{
  "type": "generate",
  "title": "房屋租赁合同",
  "result": {
    "contract_title": "房屋租赁合同",
    "summary": "已生成一份房屋租赁合同草案。",
    "contract_markdown": "# 房屋租赁合同\n\n甲方：...",
    "missing_fields": [],
    "signing_checklist": [],
    "disclaimer": "AI 辅助起草，不构成法律意见。"
  }
}
```

返回：

```txt
Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document
Content-Disposition: attachment; filename="房屋租赁合同.docx"
```

iPhone 端收到二进制后：

1. 写入临时文件。
2. 打开分享面板。
3. 用户可以保存到文件、微信、邮件、WPS 等。

## 8. 千问调用策略

### 8.1 Provider 抽象

后端内部统一抽象：

```txt
LLMProvider
  ├─ chat(messages) -> text
  ├─ chat_json(messages, schema_name) -> dict
  └─ health() -> bool
```

第一版实现：

```txt
QwenProvider
```

未来预留：

```txt
DifyGenerateProvider
```

### 8.2 JSON 稳定性

合同审查和合同生成必须返回稳定 JSON。后端不能把模型原文直接返回给 iPhone。

处理流程：

1. 构造严格提示词。
2. 要求模型只输出 JSON。
3. 后端解析 JSON。
4. Pydantic 校验。
5. 缺字段则补默认值。
6. JSON 无法解析时执行一次修复提示。
7. 修复仍失败则返回 `MODEL_BAD_RESPONSE`。

### 8.3 法条依据边界

第一版没有法规检索能力，因此 `legal_basis` 只是大模型审查报告中的参考字段。

规则：

- 有值则展示。
- 无值则隐藏。
- 不做“点击法条查看详情”。
- 不做法条搜索。
- 不把它包装成权威法律检索结果。

## 9. 文件处理设计

### 9.1 支持类型

```txt
PDF: .pdf
Word: .doc, .docx
Text: .txt
```

### 9.2 文本抽取策略

PDF：

- 优先 `pypdf`。
- 如果效果差，切换或补充 `pdfplumber`。
- 扫描版 PDF 第一版不支持 OCR，返回 `FILE_EXTRACT_FAILED`。

Word：

- `.docx` 使用 `python-docx` 抽取段落和表格文本。
- `.doc` 如果处理成本高，第一版可以提示用户转换为 `.docx`，或后端通过可用工具转换。

TXT：

- 尝试 UTF-8。
- 兼容 GBK。
- 读取失败返回 `FILE_EXTRACT_FAILED`。

### 9.3 文件安全

后端必须做：

- 限制大小。
- 限制扩展名。
- 限制 MIME。
- 防止双扩展名伪装。
- 不执行文件内容。
- 临时文件定期清理。

## 10. Word 导出设计

### 10.1 审查报告 Word 结构

```txt
合同审查报告

一、摘要
二、总体评分
三、识别信息
四、风险条款
  1. 风险标题
  2. 风险等级
  3. 涉及条款
  4. 风险分析
  5. 影响
  6. 修订建议
  7. 建议替换条款
  8. 法条依据
五、免责声明
```

### 10.2 合同草案 Word 结构

```txt
合同标题

合同正文

待补充信息

签署前清单

免责声明
```

### 10.3 Word 样式

第一版样式原则：

- 标题居中。
- 一级标题加粗。
- 正文使用宋体。
- 风险等级可以用文字标注，不依赖复杂颜色。
- 免责声明放在末尾。

## 11. iPhone App 设计

### 11.1 iOS 职责

iPhone App 负责：

- SwiftUI 界面。
- 本地历史。
- 文件选择。
- API 调用。
- 结果展示。
- Word 下载和分享。
- 错误状态。

iPhone App 不负责：

- 保存模型 Key。
- 直接调用千问。
- 直接调用 Dify。
- 云端历史。
- 文件文本抽取。

### 11.2 iOS 模块结构

```txt
Qihe/
  App/
    AppState.swift
    Router.swift

  DesignSystem/
    QHColor.swift
    QHFont.swift
    QHSpacing.swift
    QHSeal.swift
    QHButton.swift
    QHCard.swift
    QHTextField.swift

  Data/
    API/
      APIClient.swift
      APIError.swift
      ChatAPI.swift
      FileAPI.swift
      ContractAPI.swift
    Models/
      ChatModels.swift
      FileModels.swift
      ContractModels.swift
      HistoryModels.swift
    LocalStore/
      HistoryStore.swift
      ExportFileStore.swift

  Features/
    Home/
      HomeView.swift
      HomeViewModel.swift
    History/
      HistoryDrawerView.swift
      HistoryViewModel.swift
    Chat/
      ChatView.swift
      ChatViewModel.swift
    Review/
      ReviewFormView.swift
      ReviewViewModel.swift
    Generate/
      GenerateFormView.swift
      GenerateViewModel.swift
    Results/
      ReviewResultView.swift
      GenerateResultView.swift
      RiskCardView.swift
      SubjectFactsView.swift
      ContractSheetView.swift
```

### 11.3 本地历史

使用 SwiftData 保存结构化历史。

历史模型：

```json
{
  "id": "local_record_123",
  "type": "review",
  "title": "房屋租赁合同审查",
  "created_at": "2026-07-03T18:30:00+08:00",
  "status": "complete",
  "conversation_id": "conv_xxx",
  "messages": [],
  "result": {}
}
```

规则：

- 首页只显示最新 3 条。
- 历史抽屉显示全部。
- 删除和清空只影响本机。
- 合同原文可以保存到本地，用户可清空。
- 不上传云端。

### 11.4 页面导航

建议使用 `NavigationStack` + `Router`。

路由：

```txt
home
chat(localRecordId?)
review(prefill?)
generate(prefill?)
reviewResult(recordId)
generateResult(recordId)
```

首页动作：

- 点击菜单：打开历史抽屉。
- 点击新建：清空当前输入，创建新本地会话状态。
- 点击合同审查：进入审查页。
- 点击合同生成：进入生成页。
- 点击发送：调用 `/api/chat`。

### 11.5 文件选择

允许类型：

```txt
pdf
doc
docx
txt
```

iOS 行为：

1. 用户点击附件。
2. 打开 Document Picker。
3. 前端先做扩展名检查。
4. 上传到 `/api/files/upload`。
5. 保存返回的 `file_id`。

禁止：

- 图片选择器。
- 相机入口。
- 相册入口。

### 11.6 Word 导出

流程：

1. 用户点击 `导出`。
2. iPhone 调用 `/api/contracts/export/word`。
3. 后端返回 `.docx`。
4. iPhone 写入临时目录。
5. 打开分享面板。

导出文件命名：

```txt
审查报告：{合同标题或记录标题}_审查报告.docx
生成合同：{合同标题}_草案.docx
```

## 12. 页面开发说明

### 12.1 首页

元素：

- 顶部菜单按钮。
- 顶部新建按钮。
- 朱砂印章。
- `契合` 标题。
- `AI 合同审查与生成助手` 副标题。
- 大输入框。
- 附件按钮。
- 发送按钮。
- 合同审查入口。
- 合同生成入口。
- 信任说明。
- 最近记录。

验收：

- 第一屏只看到两个核心功能。
- 不出现底部导航。
- 不出现会员、客服、法条、案例等入口。

### 12.2 历史抽屉

元素：

- 小印章。
- `本地保存 · 不上传`。
- 历史列表。
- 搜索。
- 清空历史。

验收：

- 断网也能查看本地历史。
- 清空后首页最近记录同步消失。

### 12.3 聊天页

元素：

- 顶部品牌。
- 用户气泡。
- AI 气泡。
- 路由卡片。
- 审查流程节点。
- 底部输入框。

验收：

- 普通聊天正常回复。
- 识别为审查时引导进审查页。
- 识别为生成时引导进生成页。
- 不确定时出现二选一。

### 12.4 合同审查页

元素：

- 粘贴合同文本。
- 上传 PDF / Word / TXT。
- 更多信息。
- 开始审查。

状态：

- 默认。
- 已上传文件。
- 上传失败。
- 文本为空。
- 审查中。
- 审查失败。

验收：

- 没有合同文本且没有文件时不能提交。
- 图片不能被选择。
- 审查中展示流程。

### 12.5 合同生成页

元素：

- 生成需求输入。
- 补充要求。
- 生成合同。

状态：

- 默认。
- 生成中。
- 生成失败。
- 生成成功。

验收：

- 需求为空不能提交。
- 生成成功后进入生成结果页。

### 12.6 审查结果页

Tab：

- 原文
- 风险
- 主体

风险页：

- 摘要。
- 评分。
- 风险等级。
- 风险卡。
- 法条依据展示行。
- 导出 Word。

主体页：

- 有识别结果时展示字段。
- 没识别到时展示空状态。

验收：

- 不展示模型原始 JSON。
- `legal_basis` 为空时隐藏法条依据行。
- 导出 Word 可打开。

### 12.7 生成结果页

元素：

- 合同草案。
- 待补充字段。
- 签署前清单。
- 复制全文。
- 导出 Word。
- 继续修改。

验收：

- 复制全文复制的是合同正文。
- 导出 Word 可打开。
- 继续修改回到生成对话或生成表单，并带上原草案上下文。

## 13. 状态管理

### 13.1 AppState

全局状态：

- 当前路由。
- 当前会话。
- 当前上传文件。
- 网络状态。
- Toast / Alert。

### 13.2 ViewModel 规则

每个页面一个 ViewModel：

- 负责用户输入。
- 负责调用 API。
- 负责 loading / error / success 状态。
- 不直接写 UI 样式。

### 13.3 APIClient 规则

APIClient 统一处理：

- Base URL。
- JSON 编码解码。
- multipart 上传。
- Word 文件下载。
- 超时。
- HTTP 错误映射。

## 14. 安全与隐私

必须做到：

- 千问 API Key 只在后端。
- Dify Key 只在后端。
- iPhone 不保存任何模型 Key。
- 历史只保存在本地。
- 用户可以清空历史。
- 后端不做云端历史。
- 临时文件定期清理。

用户提示：

- 首页信任说明：`历史仅本地保存`。
- 历史抽屉：`本地保存 · 不上传`。
- 审查结果免责声明：`AI 辅助审查，不构成法律意见。`
- 生成结果免责声明：`AI 辅助起草，不构成法律意见。`

## 15. 测试计划

### 15.1 后端测试

接口测试：

- `/api/health` 返回正常。
- `/api/chat` 可返回 chat / route / need_input。
- `/api/files/upload` 支持 PDF / DOCX / TXT。
- `/api/files/upload` 拒绝图片。
- `/api/contracts/run` 审查返回稳定 JSON。
- `/api/contracts/run` 生成返回稳定 JSON。
- `/api/contracts/export/word` 返回可打开 Word。

异常测试：

- 空文件。
- 超大文件。
- 错误扩展名。
- 模型超时。
- 模型返回非 JSON。
- 文件不存在。

### 15.2 iPhone 测试

页面测试：

- 首页。
- 历史抽屉。
- 聊天页。
- 审查页。
- 生成页。
- 审查结果。
- 生成结果。

真机重点：

- iPhone 屏幕安全区。
- 键盘弹起。
- 长合同滚动。
- 文件选择。
- Word 分享。
- 断网错误。
- 后台切回。

### 15.3 验收测试

核心路径 1：合同审查

```txt
首页 -> 合同审查 -> 上传 PDF -> 开始审查 -> 查看风险 -> 导出 Word
```

核心路径 2：合同生成

```txt
首页 -> 合同生成 -> 输入需求 -> 生成合同 -> 复制全文 -> 导出 Word
```

核心路径 3：聊天引导

```txt
首页输入“我想写一份租房合同” -> /api/chat -> route generate -> 进入合同生成
```

核心路径 4：本地历史

```txt
完成审查 -> 返回首页 -> 最近记录出现 -> 重启 App -> 历史仍存在 -> 清空历史
```

## 16. 开发阶段

### 阶段一：项目骨架

后端：

- 创建 FastAPI 项目。
- 配置环境变量。
- 实现健康检查。
- 定义 Pydantic 模型。
- 定义错误格式。

iPhone：

- 创建 SwiftUI 项目。
- 设置 iOS 17。
- 建 DesignSystem。
- 建基础路由。

验收：

- 后端服务能启动。
- iPhone App 能跑起来。
- 首页空页面可显示。

### 阶段二：后端 AI 能力

任务：

- 实现 QwenProvider。
- 实现 `/api/chat`。
- 实现合同审查。
- 实现合同生成。
- 实现 JSON 校验和修复。

验收：

- 聊天可用。
- 审查返回 review_result。
- 生成返回 generate_result。
- 错误返回统一格式。

### 阶段三：文件和 Word

任务：

- 文件上传。
- 文本抽取。
- 临时文件存储。
- 审查报告 Word 导出。
- 合同草案 Word 导出。

验收：

- PDF / DOCX / TXT 能上传。
- 图片被拒绝。
- Word 可打开。

### 阶段四：iPhone UI

任务：

- v3 设计系统。
- 首页。
- 历史抽屉。
- 聊天页。
- 审查页。
- 生成页。
- 审查结果页。
- 生成结果页。

验收：

- UI 符合 v3 原型。
- 不出现越界入口。
- 页面状态完整。

### 阶段五：联调

任务：

- iPhone 调 `/api/chat`。
- iPhone 上传文件。
- iPhone 发起审查。
- iPhone 发起生成。
- iPhone 导出 Word。
- 本地历史保存结果。

验收：

- 四条核心路径跑通。

### 阶段六：真机和测试发布

任务：

- 真机测试。
- 错误处理。
- 性能检查。
- 大文本检查。
- TestFlight 准备。

验收：

- 可交付测试版。

## 17. 任务清单

### 后端任务清单

- [ ] 创建 `backend/` 项目。
- [ ] 配置 FastAPI。
- [ ] 配置 `.env.example`。
- [ ] 定义错误码。
- [ ] 定义 Chat schema。
- [ ] 定义 File schema。
- [ ] 定义 Contract schema。
- [ ] 实现 QwenProvider。
- [ ] 实现 JSON repair。
- [ ] 实现 `/api/health`。
- [ ] 实现 `/api/chat`。
- [ ] 实现 `/api/files/upload`。
- [ ] 实现 PDF 抽取。
- [ ] 实现 DOCX 抽取。
- [ ] 实现 TXT 抽取。
- [ ] 实现 `/api/contracts/run` review。
- [ ] 实现 `/api/contracts/run` generate。
- [ ] 实现 `/api/contracts/export/word` review。
- [ ] 实现 `/api/contracts/export/word` generate。
- [ ] 编写后端测试。

### iPhone 任务清单

- [ ] 创建 SwiftUI 项目。
- [ ] 设置 iOS 17。
- [ ] 建 DesignSystem token。
- [ ] 实现 `QiheSeal`。
- [ ] 实现基础按钮和卡片。
- [ ] 实现 APIClient。
- [ ] 实现本地历史 store。
- [ ] 实现首页。
- [ ] 实现历史抽屉。
- [ ] 实现聊天页。
- [ ] 实现合同审查页。
- [ ] 实现合同生成页。
- [ ] 实现文件选择。
- [ ] 实现审查结果页。
- [ ] 实现生成结果页。
- [ ] 实现 Word 下载和分享。
- [ ] 实现错误状态。
- [ ] 真机测试。

## 18. 关键验收标准

产品验收：

- App 名称为 `契合`。
- 首页只出现合同审查和合同生成两个核心入口。
- 上传入口只支持 PDF / Word / TXT。
- 不出现图片上传。
- 不出现会员、客服、法条检索、案例、类案、法律研究。
- 历史记录只在本地。
- 用户可以清空历史。
- 审查报告能导出 Word。
- 合同草案能导出 Word。

技术验收：

- iPhone 不持有模型 Key。
- 后端能统一处理千问超时。
- 后端不返回模型原始 JSON。
- 后端返回稳定 schema。
- 文件抽取失败有明确错误。
- Word 文件能被 iPhone 分享和打开。

设计验收：

- 符合 v3：文书、印鉴、法务藏青。
- 主按钮使用法务藏青。
- 印章和高风险使用朱砂。
- 宋体只用于品牌、标题、文书，不滥用。
- 长文本不溢出。
- iPhone 安全区适配正常。

## 19. 后续可扩展项

第一版不做，但架构预留：

- Dify 合同生成 provider。
- 流式生成。
- 云端账号。
- 多设备同步。
- 模板库。
- OCR。
- 法规检索。
- 案例检索。
- 付费会员。

这些功能上线前必须重新评估产品边界和合规风险。

## 20. 开始编程后的第一步

当用户明确说“开始编程”后，建议按下面顺序执行：

1. 创建 `backend/` FastAPI 骨架。
2. 创建 `.env.example`。
3. 定义 Pydantic schema。
4. 实现 `/api/health`。
5. 实现 QwenProvider。
6. 实现 `/api/chat`。
7. 再创建 SwiftUI 项目骨架。

当前文档只用于开发计划和交付对齐，不代表已经开始编码。
