# 契合前端页面开发文档

版本：v0.1  
技术栈：uni-app Vue3 + TypeScript H5  
目标端：H5、iOS WKWebView wrapper  
主文件：`src/pages/index/index.vue`  
服务层：`src/services/dify.ts`  
最后更新：2026-07-03

## 1. 当前产品边界

「契合」是移动端 AI 合同助手原型，当前只保留两个核心功能：

- 合同审查
- 合同生成

首页保留自由输入框。用户可以闲聊，但闲聊不是第三个核心功能；当前前端对非合同输入只显示引导回复，不进入后端结果页。

底部 Tab 固定为：

```json
["主页", "功能", "历史", "设置"]
```

历史记录第一阶段只保存到本地 `uni.setStorageSync("qihe-history")`。

## 2. 项目关键路径

| 路径 | 用途 |
| --- | --- |
| `src/pages/index/index.vue` | 当前全部主界面、页面状态和交互 |
| `src/services/dify.ts` | Dify/Mock 统一服务层 |
| `src/pages.json` | uni-app 页面配置 |
| `src/App.vue` | App 外层 |
| `src/manifest.json` | uni-app manifest |
| `docs/backend-development-spec.md` | 后端开发文档 |
| `docs/frontend-pages-development-spec.md` | 本文档 |
| `docs/qa/` | 390px 和 iOS QA 截图 |
| `ios/HetongBang/HetongBang.xcodeproj` | iOS WKWebView wrapper |
| `scripts/sync-ios-webapp.sh` | H5 构建产物同步到 iOS wrapper |

## 3. 本地启动和验收命令

启动 H5：

```bash
npm run dev:h5 -- --host 127.0.0.1
```

访问：

```text
http://127.0.0.1:5173/
```

类型检查：

```bash
npm run type-check
```

H5 构建：

```bash
npm run build:h5
```

同步到 iOS wrapper：

```bash
npm run sync:ios
```

带本地 Dify proxy 同步到 iOS wrapper：

```bash
npm run sync:ios:dify
```

条款 F-CMD-01：前端改动后至少跑 `npm run type-check`。  
条款 F-CMD-02：影响 H5/iOS 展示的改动还应跑 `npm run build:h5`。  
条款 F-CMD-03：需要在 iPhone/Xcode 验证时再跑 `npm run sync:ios`。  

## 4. 页面状态机

当前 `index.vue` 使用单文件状态机，不使用多页面路由。

核心类型：

```ts
type RootScreen = "home" | "features" | "history" | "settings";
type Screen = RootScreen | "review" | "generate" | "reviewResult" | "generateResult";
type Mode = "auto" | "review" | "generate";
type HistoryType = "review" | "generate";
```

页面状态：

| screen | 页面 | 入口 | 说明 |
| --- | --- | --- | --- |
| `home` | 主页 | 默认 | 品牌、聊天输入、快捷审查/生成、最近记录 |
| `features` | 功能页 | 底部 Tab | 顶部左右按钮切换审查/生成工作台 |
| `history` | 历史页 | 底部 Tab | 本地历史记录、搜索、空状态 |
| `settings` | 设置页 | 底部 Tab | 账号、隐私、通用设置、帮助、关于、清空历史 |
| `review` | 独立审查页 | 主页快捷入口/澄清入口 | 粘贴文本或上传文件，更多信息折叠 |
| `generate` | 独立生成页 | 主页快捷入口/继续修改 | 描述需求，补充要求折叠 |
| `reviewResult` | 审查结果页 | 调用完成/历史详情 | 原文、风险、主体三个 Tab |
| `generateResult` | 生成结果页 | 调用完成/历史详情 | 摘要、合同正文、待补信息、签署清单 |

根页面判定：

```ts
const isRootScreen = computed(() => {
  return ["home", "features", "history", "settings"].includes(screen.value);
});
```

底部 Tab 只在 `isRootScreen=true` 时显示。

## 5. 主页

### 5.1 页面结构

主页包含：

- 顶部轻科技背景。
- Logo mark。
- 产品名“契合”。
- 副标题“AI合同审查与生成助手”。
- 聊天消息流。
- 主输入框。
- 文件按钮。
- 发送按钮。
- 快捷按钮：合同审查、合同生成。
- 最近记录。
- 底部 Tab。

### 5.2 首页输入逻辑

函数：

```ts
sendHomeMessage()
inferMode(text)
```

当前识别规则：

| 输入特征 | 结果 |
| --- | --- |
| 包含“生成、起草、草拟、拟一份、写一份、做个、做一份、模板、草案、协议” | `generate` |
| 包含“审查、审核、检查、风险、能不能签、有没有问题、看看、上传、文件、合同内容、条款” | `review` |
| 包含“合同、协议、租房、租赁、服务”但意图不明确 | `clarify` |
| 其他 | 首页本地闲聊引导 |

`clarify` 不是后端模式，只是前端本地消息类型。澄清气泡会显示两个按钮：

- 合同审查
- 合同生成

### 5.3 首页交互示例

生成：

```text
用户：生成一份租房合同，我是房东，租期一年，押一付三，想保护出租方权益。
动作：自动进入生成流程，成功后 screen=generateResult。
```

审查：

```text
用户：请审查这份合同：甲方委托乙方开发小程序...
动作：自动进入审查流程，成功后 screen=reviewResult。
```

闲聊：

```text
用户：你好
前端回复：你好，我是契合。你可以直接描述想生成的合同，或粘贴合同文本让我审查风险。
动作：停留在 home，不调用后端。
```

## 6. 功能页

### 6.1 页面结构

功能页顶部是两个大按钮：

- 合同审查
- 合同生成

状态：

```ts
const featureMode = ref<"review" | "generate">("review");
```

### 6.2 合同审查工作台

当前内容：

- 标题：合同审查
- 主标题：识别风险并给出修改建议
- 状态卡：专业AI审查 / 链路分析总结
- 输入卡：粘贴文本 / 上传文件
- 合同类型选择框和身份选择
- 审查重点 chips：付款风险、交付验收、违约责任、解除终止、签约主体、争议解决
- 主按钮：开始合同审查
- 卖点卡：专业AI审查、风险定位、主体核验、修改建议

输入状态：

```ts
const reviewInputMode = ref<"text" | "file">("text");
const contractText = ref("");
const selectedFile = ref("");
const selectedUploadFile = ref<LocalUploadFile | null>(null);
const reviewForm = reactive({
  contractType: "不确定",
  customContractType: "",
  role: "甲方",
  requirements: "",
  focusAreas: ["付款风险", "违约责任", "争议解决"]
});
```

校验规则：

- 粘贴文本模式：`contractText.trim()` 不能为空。
- 上传文件模式：`selectedFile` 不能为空。

### 6.3 合同生成工作台

当前内容：

- 标题：合同生成
- 主标题：把需求整理成合同草案
- 状态卡：合同框架 / 智能生成
- 描述生成需求输入框
- 合同框架卡
- 合同类型选择框
- 自定义合同类型输入框
- 身份选择：甲方、乙方、中立、未知
- 生成条款 chips：双方信息、价款报酬、履行安排、交付验收、违约责任、争议解决
- 金额/期限/特殊约定输入
- 主按钮：开始合同生成
- 卖点卡：结构完整、立场保护、待补信息、继续修改

输入状态：

```ts
const generatePrompt = ref("");
const generateForm = reactive({
  contractType: "不确定",
  customContractType: "",
  role: "甲方",
  requirements: "",
  focusAreas: ["双方信息", "价款报酬", "履行安排", "违约责任"]
});
```

校验规则：

- `generatePrompt.trim()` 不能为空。

## 7. 合同类型抽屉

合同类型不再使用横向按钮，而是底部抽屉。

打开函数：

```ts
openContractTypeDrawer(mode)
closeContractTypeDrawer()
selectContractType(value, index)
onContractTypeDrawerScroll(event)
```

抽屉通过 `contractTypeDrawerTarget` 区分目标表单。审查和生成各自保存合同类型、自定义类型、身份、补充说明和关注项，避免互相串值。

当前选项：

```ts
const contractTypeOptions = [
  { label: "不确定", value: "不确定", desc: "交给AI判断" },
  { label: "买卖采购", value: "买卖/采购合同", desc: "商品交易" },
  { label: "租赁房屋", value: "租赁/房屋合同", desc: "租房设备" },
  { label: "服务委托", value: "服务/委托合同", desc: "外包咨询" },
  { label: "技术软件", value: "技术/软件合同", desc: "开发许可" },
  { label: "劳动用工", value: "劳动/用工合同", desc: "雇佣劳务" },
  { label: "工程装修", value: "工程/装修合同", desc: "施工承揽" },
  { label: "借款担保", value: "借款/担保合同", desc: "借贷保证" },
  { label: "合伙合作", value: "合伙/合作合同", desc: "共同经营" },
  { label: "自定义", value: "自定义", desc: "自己填写" }
];
```

自定义逻辑：

```ts
isCustomContractTypeFor(mode)
displayContractTypeFor(mode)
```

当选中“自定义”：

- 对应模式的工作台或独立页出现 `customContractType` 输入框。
- 提交时如果自定义为空，后端收到 `自定义合同`。

## 8. 独立审查页

独立审查页用于主页快捷入口、澄清入口和文件入口。

页面内容：

- 顶部返回栏。
- 标题：合同审查。
- 粘贴文本 / 上传文件切换。
- 合同正文输入框或上传文件区域。
- 更多信息折叠卡。
- 固定底部按钮：开始审查。

更多信息包含：

- 合同类型选择框。
- 身份按钮。
- 审查重点多选 chips。
- 补充说明输入框。

触发函数：

```ts
startReview()
runTask("review")
```

## 9. 独立生成页

独立生成页用于主页快捷入口和结果页“继续修改”。

页面内容：

- 顶部返回栏。
- 标题：合同生成。
- 需求描述输入框。
- 补充要求折叠卡。
- 固定底部按钮：生成合同。

补充要求包含：

- 合同类型选择框。
- 身份按钮。
- 生成条款多选 chips。
- 金额、期限、交付标准、特殊约定输入框。

触发函数：

```ts
startGenerate()
runTask("generate")
```

## 10. 服务调用流程

核心函数：

```ts
async function runTask(mode: Exclude<Mode, "auto">)
```

流程：

1. 如果 `submitting=true`，直接返回，避免重复提交。
2. 显示 loading。
3. 根据 mode 获取 `queryText`。
4. 调用 `effectiveContractType(queryText, mode)` 得到合同类型。
5. 调用 `runContractAnalysis(payload)`。
6. 写入 `currentResult`。
7. 写入 `currentConversationId`。
8. 写入 `currentTaskContext`，记录合同类型、身份、关注项、输出详略和服务模式。
9. `resultTab` 重置为 `risks`。
10. 保存本地历史和处理上下文。
11. 切到 `reviewResult` 或 `generateResult`。

提交给服务层的 payload：

```ts
{
  mode,
  query: queryText,
  contractText: queryText,
  contractType: typeText,
  role: taskForm(mode).role,
  focusAreas: selectedFocusAreas(mode),
  requirements: structuredRequirements(mode),
  jurisdiction: "中国大陆",
  outputStyle: "普通用户可读",
  conversationId: currentConversationId.value,
  file: selectedUploadFile.value
}
```

`structuredRequirements(mode)` 会把选择项整理成结构化文本：

- 审查：`审查重点：付款风险、违约责任`
- 生成：`需包含条款：双方信息、价款报酬`
- 手动输入会追加为 `补充说明` 或 `补充约定`

条款 F-SVC-01：前端第一阶段不直接保存或读取真实 Dify Key。  
条款 F-SVC-02：真实后端接入应只改 `src/services/dify.ts` 和环境变量，不应重写页面。  
条款 F-SVC-03：`runTask` 的返回结果必须能同时驱动结果页和本地历史。  
条款 F-SVC-04：审查和生成表单状态必须隔离，不能复用同一个 `contractType/currentRole/requirements`。  
条款 F-SVC-05：本地历史必须保存当次处理上下文，结果页和导出 Markdown 应能展示处理条件。  

## 11. 审查结果页

状态：

```ts
const resultTab = ref<"original" | "risks" | "parties">("risks");
const currentResult = ref<ContractResult | null>(null);
```

顶部 Tab：

- 原文
- 风险
- 主体

### 11.1 风险 Tab

展示：

- 审查摘要。
- 处理条件卡：合同类型、身份、审查重点、输出详略。
- 重点风险数量。
- 安全分。
- 等级。
- 风险标签。
- 风险卡列表。
- 每条风险可展开建议替换条款。

使用字段：

| 字段 | 用途 |
| --- | --- |
| `currentResult.summary` | 摘要正文 |
| `currentResult.score` | 安全分 |
| `currentResult.grade` | 等级 |
| `currentResult.risk_level` | 风险标签 |
| `currentResult.clause_reviews` | 风险卡 |

前端映射逻辑：

```ts
const riskItems = computed<RiskView[]>(() => {
  const reviews = currentResult.value?.clause_reviews || [];
  return reviews.slice(0, 5).map(...);
});
```

如果后端没有返回 `clause_reviews`，前端会显示兜底风险卡，但真实接入后不应依赖兜底。

结果页继续追问：

- Mock 模式：使用前端本地解释函数生成追问建议。
- Dify 模式：调用 `runContractAnalysis()`，传入当前 `conversationId`、合同原文、处理上下文和用户追问；结果页不替换当前审查报告，只把回答追加到追问线程。

### 11.2 原文 Tab

展示：

- `contractText`
- 如果是文件审查且尚未解析原文，显示“当前是文件审查模拟，原文将在真实解析后展示。”

### 11.3 主体 Tab

展示：

- `currentResult.facts`

当前前端只稳定支持对象形式：

```json
{
  "合同类型": "技术/软件合同",
  "我方身份": "甲方",
  "审查地区": "中国大陆",
  "文本来源": "粘贴文本"
}
```

如果后端要返回数组形式，需要前端再增强。

## 12. 生成结果页

页面结构：

- 顶部返回栏。
- 标题：生成结果。
- 下载/复制按钮。
- 生成摘要卡。
- 处理条件卡：合同类型、身份、生成条款、输出详略。
- 合同正文卡。
- 待补充信息卡。
- 签署前清单卡。
- 免责声明。
- 底部固定按钮：复制全文、导出、继续修改。

使用字段：

| 字段 | 用途 |
| --- | --- |
| `currentResult.grade_label` | 生成摘要标题 |
| `currentResult.summary` | 生成摘要正文 |
| `currentResult.contract_title` | 合同正文卡标题 |
| `currentResult.contract_markdown` | 合同正文 |
| `currentResult.missing_fields` | 待补充信息 |
| `currentResult.signing_checklist` | 签署前清单 |
| `currentResult.disclaimer` | 免责声明 |

当前“导出”按钮暂时复用复制逻辑：

```ts
copyResult()
```

后续可改为：

- 导出 Markdown。
- 生成 PDF。
- 调用 iOS share sheet。

导出的 Markdown 会包含处理条件，避免脱离 App 后丢失当次生成背景。

## 13. 历史页

本地存储 key：

```ts
"qihe-history"
```

历史结构：

```ts
interface HistoryRecord {
  id: string;
  type: "review" | "generate";
  title: string;
  time: string;
  result: ContractResult;
  contractText?: string;
  context?: {
    contractType: string;
    role: string;
    focusAreas: string[];
    requirements: string;
    outputStyle: "简洁" | "标准" | "详细";
    serviceMode: string;
  };
}
```

历史列表展示当次处理上下文；打开历史详情时会恢复对应模式的表单状态，并把 `currentTaskContext` 带入结果页和导出 Markdown。

保存逻辑：

```ts
history.value = [record, ...history.value].slice(0, 30);
uni.setStorageSync("qihe-history", history.value);
```

当前限制：

- 最多保存 30 条。
- 时间显示固定为“刚刚”。
- 只保存在当前设备。
- 清空历史只删除本地 key。

后端云历史接入时需要重构：

- 列表分页。
- 详情接口。
- 删除接口。
- 本地缓存和云端合并策略。

## 14. 设置页

当前设置页是原型态。

显示内容：

- 个人中心卡片。
- 登录按钮。
- 账号与个人信息。
- 隐私与数据。
- 通用设置。
- 帮助与反馈。
- 关于契合。
- 清空历史记录。

当前点击行为：

- 普通设置项显示 Toast：`${title}后续接入`。
- 清空历史记录调用 `clearHistory()`。

后续可接入：

- 登录状态。
- 会员额度。
- 默认身份。
- 输出风格。
- 隐私模式。
- 云同步开关。

## 15. 文件上传交互

函数：

```ts
pickFile(stayInCurrentScreen = false)
```

H5 中如果 `uni.chooseFile` 不存在，会写入模拟文件：

```ts
selectedFile.value = "合同文件.docx";
selectedUploadFile.value = {
  name: selectedFile.value,
  path: selectedFile.value,
  type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
};
```

真实选择文件时：

```ts
chooseFile({
  count: 1,
  extension: [".pdf", ".doc", ".docx", ".txt"],
  ...
});
```

注意：

- 后端文档第一阶段只承诺 PDF/DOCX/TXT/MD。
- 前端当前包含 `.doc`，后续如果后端不支持 `.doc`，需要前端去掉 `.doc` 或提示不支持。

## 16. 合同类型推断

前端兜底函数：

```ts
function inferContractType(text: string) {
  if (/租房|租赁|房东|承租|押金/.test(text)) return "房屋租赁合同";
  if (/软件|开发|技术|系统|源码/.test(text)) return "技术/软件合同";
  if (/劳动|用工|工资|社保/.test(text)) return "劳动/用工合同";
  return "通用民事合同";
}
```

最终合同类型：

```ts
function effectiveContractType(text: string) {
  if (isCustomContractType.value) return customContractType.value.trim() || "自定义合同";
  if (contractType.value && contractType.value !== "不确定") return contractType.value;
  return inferContractType(text);
}
```

说明：

- 前端推断只做体验兜底。
- 后端/AI 仍应根据正文再次判断合同类型。

## 17. 当前视觉规范

整体风格：

- 简洁。
- 大气。
- 轻科技感。
- iPhone 使用习惯。
- 不做营销式复杂布局。

布局原则：

- 卡片圆角保持 8rpx。
- 主要操作按钮高度约 92rpx。
- 底部 Tab 固定。
- 结果页主操作固定在底部。
- 不添加无关图片。
- 不添加复杂营销区块。
- 文案保持普通用户可读。

颜色：

| 用途 | 值 |
| --- | --- |
| 主蓝 | `#2563eb` |
| 深色按钮 | `#111827` |
| 页面背景 | `#f7f8fb` |
| 卡片背景 | `#ffffff` |
| 次级文字 | `#7b8494` |
| 边框 | `#e3eaf5` |

## 18. 移动端 QA 标准

每次改页面后，至少检查 390px 宽度。

推荐视口：

```text
390 x 844
```

必须检查：

- 首页首屏。
- 首页输入后聊天气泡。
- 功能页审查工作台。
- 功能页生成工作台。
- 合同类型抽屉。
- 自定义合同类型输入框。
- 审查结果风险 Tab。
- 审查结果主体 Tab。
- 生成结果正文页。
- 历史空状态和有记录状态。
- 设置页。

已有 QA 截图目录：

```text
docs/qa/
```

## 19. 示例流程

### 19.1 生成合同

输入：

```text
生成一份租房合同，我是房东，租期一年，押一付三，想保护出租方权益。
```

期望：

- 进入 `generateResult`。
- 显示生成摘要。
- 显示房屋租赁合同正文。
- 显示待补充信息。
- 显示签署前清单。

### 19.2 审查合同

输入：

```text
请审查这份合同：甲方委托乙方开发小程序，合同金额50000元，乙方完成后付款，违约责任双方协商解决。
```

期望：

- 进入 `reviewResult`。
- 默认停留风险 Tab。
- 显示安全分、等级、风险标签。
- 显示付款与验收、违约责任、争议解决等风险卡。
- 主体 Tab 显示合同类型、我方身份、审查地区、文本来源。

### 19.3 闲聊

输入：

```text
你好
```

期望：

- 停留首页。
- 显示用户气泡和助手气泡。
- 助手回复：`你好，我是契合。你可以直接描述想生成的合同，或粘贴合同文本让我审查风险。`
- 不调用后端。

## 20. 后续开发边界

可以小步优化：

- 结果页导出真实 Markdown/PDF。
- 文件上传类型提示。
- 历史记录时间显示。
- 设置页真实开关。
- 合同类型抽屉搜索。
- 审查结果风险等级颜色更细分。

不要未经确认就做：

- 新增第三个核心功能。
- 新增营销首页。
- 添加复杂图片或插画。
- 把本地历史改为云历史。
- 前端直连 Dify 官方接口。
- 把 API Key 写进前端环境变量或 App 包。

## 21. 开发验收清单

前端改动完成后检查：

- `npm run type-check` 通过。
- `npm run build:h5` 通过。
- 390px 首页无文字溢出。
- 390px 功能页两个工作台主按钮可见。
- 合同类型抽屉能打开、滚动、选择自定义。
- 自定义后输入框出现。
- 生成示例能进入 `generateResult`。
- 审查示例能进入 `reviewResult`。
- 闲聊示例停留首页。
- 历史记录会新增。
- 清空历史只清本地记录。
- 没有读取或提交 `.env.local`。
