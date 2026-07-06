# 契合 iOS 前端实现规划

## 目标

把当前 iOS App 从“AI 结果展示”升级为“合同工作台”：

- 审查结果默认看原文，风险以色块定位。
- 风险详情可查看分析和修改建议。
- 修改建议可编辑、确认，并在本地保留修改状态。
- 生成合同结果可按段落和占位符编辑。
- 审查和生成过程有进度页反馈。
- 后续接入邮箱验证码、积分、激活码和 StoreKit 时，不破坏主流程。

## 当前前端结构

```txt
ios/Qihe/
  App/
    AppRoute.swift
    AppState.swift
    AuthState.swift
    RootView.swift
  Data/
    API/APIClient.swift
    LocalStore/HistoryStore.swift
    Models/ContractModels.swift
  Features/
    Home/HomeView.swift
    Review/ReviewInputView.swift
    Results/ReviewResultView.swift
    Generate/GenerateInputView.swift
    Results/GenerateResultView.swift
    Profile/ProfileView.swift
    History/HistoryView.swift
    Chat/ChatView.swift
    Subject/SubjectView.swift
  DesignSystem/
```

## 前端架构原则

1. 结果页不要直接围绕一整段字符串渲染，要围绕“段落/块/风险/修改”渲染。
2. 任务一和任务二可以先前端本地分段，任务三接后端 blocks。
3. 修改记录先存 SwiftData，后续迁移到后端 revisions。
4. 生成合同和审查建议共用一套编辑交互：点选、编辑、确认、颜色标识。
5. 进度页先做统一组件，任务一/任务二可先用前端假进度，任务四接后端 job。

## 新增前端模块

```txt
ios/Qihe/Features/Review/
  ReviewProgressView.swift
  OriginalRiskDocumentView.swift
  RiskDetailSheet.swift
  RiskEditSheet.swift

ios/Qihe/Features/Generate/
  GenerateProgressView.swift
  GeneratedContractEditorView.swift
  PlaceholderEditSheet.swift

ios/Qihe/Features/Editor/
  ContractSegmentModels.swift
  ContractSegmentEditorView.swift
  SegmentEditSheet.swift
  RevisionBadge.swift

ios/Qihe/Features/Entitlement/
  CreditBalanceView.swift
  ActivationCodeView.swift
  StoreKitPaywallView.swift

ios/Qihe/Data/LocalStore/
  RevisionStore.swift

ios/Qihe/Data/API/
  JobDTO.swift
  EntitlementDTO.swift
```

## 核心前端数据模型

可先放在 `ContractSegmentModels.swift`，后续可迁移到 `ContractModels.swift`。

```swift
struct DocumentSegment: Identifiable, Hashable {
    enum Kind: Hashable {
        case paragraph
        case placeholder(name: String)
    }

    var id: String
    var kind: Kind
    var text: String
    var originalText: String
    var riskIds: [String]
    var revisionState: RevisionState
}

enum RevisionState: String, Codable, Hashable {
    case original
    case draft
    case confirmed
}

struct LocalRevision: Identifiable, Codable, Hashable {
    var id: UUID
    var recordId: UUID
    var segmentId: String
    var riskId: String?
    var beforeText: String
    var afterText: String
    var status: RevisionState
    var createdAt: Date
    var updatedAt: Date
}
```

## 任务一：审查主体验

### 1. ReviewInputView 增加审查立场

文件：

- `ios/Qihe/Features/Review/ReviewInputView.swift`
- `ios/Qihe/Data/API/APIClient.swift`
- `ios/Qihe/Data/Models/ContractModels.swift`

交互：

- 三段选择器：我是甲方 / 我是乙方 / 中立角度。
- 默认值：中立角度。
- 提交审查时带 `review_perspective`。
- 本地历史记录保存该选择。

传参：

```json
{
  "metadata": {
    "review_perspective": "party_a"
  }
}
```

### 2. ReviewResultView 默认展示原文 tab

文件：

- `ios/Qihe/Features/Results/ReviewResultView.swift`
- `ios/Qihe/Features/Review/OriginalRiskDocumentView.swift`

要求：

- 默认选中“原文”tab。
- 原文按段落分块展示。
- 有风险的段落左侧或背景展示风险色块。
- 高风险红色，中风险橙色，低风险蓝色，待确认灰色。
- 右滑从原文 tab 切到风险列表 tab。

任务一原文来源优先级：

```txt
result.source.originalText
payload.requestText
result.source.textPreview
risk.originalExcerpt 拼接
result.summary
```

注意：如果是上传文件，当前后端通常只返回 240 字预览，任务一要接受原文不完整；任务三由后端补全文接口。

### 3. 风险详情和修改

新增：

- `RiskDetailSheet.swift`
- `RiskEditSheet.swift`
- `RevisionStore.swift`

交互：

- 点击有风险的段落块，弹出 `RiskDetailSheet`。
- 展示风险标题、风险等级、风险分析、修改建议、建议替换条款。
- 点击“修改”进入 `RiskEditSheet`。
- `RiskEditSheet` 默认填入：
  - `risk.suggestedReplacement`
  - 否则 `risk.revisionSuggestion`
  - 否则当前段落文本
- 用户确认后：
  - 原文段落变绿色。
  - 写入 SwiftData revision。
  - 风险详情显示“已修改”状态。

### 4. 定位按钮

位置：

- `ReviewResultView` 底部 action bar。

交互：

- 新增“定位”按钮。
- 弹 `confirmationDialog`。
- 列出所有风险项。
- 点选后滚动到对应段落。
- 目标段落闪烁高亮 1 次。

验收：

- 能从风险列表定位到原文段落。
- 原文 tab 和风险 tab 之间切换稳定。
- 修改后退出结果页再回来，修改状态仍在。

## 任务二：生成合同编辑器

### 1. DraftSegment 解析

文件：

- `ios/Qihe/Features/Results/GenerateResultView.swift`
- `ios/Qihe/Features/Generate/GeneratedContractEditorView.swift`
- `ios/Qihe/Features/Editor/ContractSegmentModels.swift`

解析规则：

- 按空行或换行拆普通段落。
- 识别 `【待补充：xxx】`。
- 占位符成为独立 token。
- 普通段落也可编辑。

示例：

```txt
甲方：【待补充：甲方名称】
乙方：【待补充：乙方名称】
```

渲染：

- 未填占位符：amber 高亮。
- 已填占位符：绿色高亮。
- 用户改过的普通段落：绿色边框或绿色标识。

### 2. 占位符编辑

新增：

- `PlaceholderEditSheet.swift`

交互：

- 点击占位符弹 sheet。
- 输入内容后替换占位符。
- 支持清空恢复待补充状态。

### 3. 普通段落编辑

新增：

- `SegmentEditSheet.swift`

交互：

- 点击普通段落弹 `TextEditor`。
- 确认后覆盖段落文本。
- 段落标记为已修改。

### 4. 移除 missingFieldsForm

要求：

- 不再在结果页下方展示独立缺失字段卡片。
- 缺失字段全部内嵌为正文 token。
- 底部“定位”按钮列出所有未填 token。

验收：

- 生成结果页可以直接填缺失字段。
- 普通段落可以编辑。
- 已填内容变绿。
- 定位按钮能滚动到未填项。

## 任务三：接入后端 blocks/revisions

当前任务一/任务二前端本地分段，任务三后端返回：

```txt
blocks: [ContractBlock]
revisions: [ContractRevision]
```

iOS 改动：

- `ContractModels.swift` 增加 DTO。
- `ReviewResultView` 优先使用后端 blocks。
- `GenerateResultView` 优先使用后端 blocks。
- `RevisionStore` 从纯本地变为本地缓存。
- 应用修改建议时调用后端接口。

验收：

- 历史记录恢复时，段落修改状态不丢。
- 导出 Word 使用修改后的 blocks。

## 任务四：真实进度页

新增：

- `ContractProgressView`
- `JobPollingStore`
- `JobDTO`

流程：

```txt
用户提交
→ POST /api/contracts/review-jobs 或 generate-jobs
→ 得到 job_id
→ 每 1.5 秒 GET /api/jobs/{job_id}
→ succeeded 后关闭进度页并展示结果
```

状态：

```swift
enum JobStatus: String, Codable {
    case queued
    case running
    case succeeded
    case failed
}
```

验收：

- 审查/生成都有流程页。
- 步骤文案能变化。
- 失败后用户输入不丢。

## 任务五：邮箱验证码登录

文件：

- `ios/Qihe/Features/Profile/ProfileView.swift`
- `ios/Qihe/App/AuthState.swift`
- `ios/Qihe/Data/API/APIClient.swift`

交互：

- 第一步输入邮箱。
- 点击发送验证码。
- 第二步输入 6 位验证码。
- 60 秒倒计时重发。
- 验证成功后保存 token。

兼容：

- 旧密码登录入口先隐藏，不删除。
- token 存储逻辑复用现有 `AuthState`。

## 任务六：积分、激活码、StoreKit

前端模块：

- `CreditBalanceView`
- `ActivationCodeView`
- `StoreKitPaywallView`

交互：

- Profile 页展示积分余额。
- 审查按钮显示“消耗 2 积分”。
- 生成按钮显示“消耗 3 积分”。
- 积分不足时弹 alert，引导到购买/兑换。
- App Store build 默认展示 StoreKit 购买入口。
- 激活码入口受远程配置控制，审核不稳时隐藏。

验收：

- 余额展示正确。
- 402 错误能引导到兑换/购买页。
- StoreKit 成功后刷新余额。

## UI 验收清单

- 原文 tab 是审查结果默认页。
- 风险段落有明确色块。
- 风险详情 sheet 内容完整。
- 修改建议可编辑并确认。
- 已修改段落有绿色标识。
- 生成合同占位符可直接填写。
- 普通段落可编辑。
- 定位按钮可定位风险/占位符。
- 审查立场选择能保存和传参。
- 进度页不会遮挡系统返回和错误提示。

## 技术验收命令

```bash
cd ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Qihe.xcodeproj \
  -scheme Qihe \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/qihe-AppDerivedData \
  build
```

## 任务执行顺序

1. `ReviewInputView` 审查立场。
2. `GenerateResultView` DraftSegment 编辑器。
3. `ReviewResultView` 原文 tab + 风险详情。
4. SwiftData revision 本地存储。
5. 进度页前端 MVP。
6. 接后端 jobs。
7. 接后端 blocks/revisions。
8. 邮箱验证码。
9. 积分、激活码、StoreKit。
