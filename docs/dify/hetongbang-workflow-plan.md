# 合同帮V1 Dify 工作流方案

## 定位

合同帮V1 是移动端 APP 的核心 AI 工作流，核心服务两个主功能：

- 合同审查
- 合同生成

同时，为了适配首页主对话框，工作流增加一个轻量 `consult` 分支，用来处理合同知识咨询、需求不明确和普通闲聊引导。它不生成完整合同，也不输出正式审查报告；产品核心能力仍然只对外呈现为「合同审查」和「合同生成」。

这不是旧「合同检查生成器」的复制版。当前版本不设置独立的 `revise` intent。信息不足时，在当前功能内返回 `status=need_input` 或在 `consult` 分支里返回追问。

工作流支持三种入口模式：

- `mode=review`：APP 点击「审查合同」时强制进入审查。
- `mode=generate`：APP 点击「生成合同」时强制进入生成。
- `mode=consult`：APP 或测试面板显式进入合同咨询。
- `mode=auto`：首页自然语言输入或 Dify 直接测试时，先判断用户是要审查、生成还是咨询，再进入对应分支。

## 用户体验原则

- 输出给普通用户看得懂，但保留专业结构。
- 评分是合同安全/可用分，越高越安全可用。
- 按 A/B/C/D/E 五档评级。
- 审查要讲清楚：能不能签、哪里有风险、为什么、怎么改。
- 生成要讲清楚：生成了什么、哪些是假设、哪些签署前必须补齐。
- 默认按用户选择的身份保护用户利益：甲方保护甲方，乙方保护乙方，中立则平衡。
- 不伪造法条或来源；可靠引用等后续法规知识库接入后再开启。

## APP 字段映射

| APP 页面 | 字段 | Dify 变量 |
| --- | --- | --- |
| 首页主输入框 | 粘贴合同或描述需求 | `contract_text` / `sys.query` |
| 上传文件入口 | PDF / DOCX / TXT / Markdown | `contract_file` |
| 功能模式 | 审查合同 / 生成合同 / 合同咨询 / 自动判断 | `mode=review/generate/consult/auto` |
| 合同类型 | APP 下拉或自定义 | `contract_type` |
| 你的立场/身份 | 甲方、乙方、中立、未知 | `role` |
| 审查关注重点 | 8 个审查 chip | `focus_areas` |
| 生成包含条款 | 8 个生成 chip | `focus_areas` |
| 补充说明 | 行业背景、金额、期限等 | `requirements` |
| 法域 | 默认中国大陆 | `jurisdiction` |
| 输出风格 | 默认普通用户可读 | `output_style` |

## 节点结构

1. `用户输入`
   接收 APP 字段和可选合同文件。

2. `是否上传文件`
   有文件则进入文档提取；无文件直接整理文本。

3. `提取合同文件文本`
   使用 Dify Document Extractor，将 PDF / DOCX / TXT / Markdown 转为文本。`.doc` 老格式第一版不承诺，后续接稳定转换插件后再开放。

4. `合并文件与输入` / `整理文本输入`
   合并文件文本、粘贴文本、补充说明和用户原始问题。

5. `统一合同文本`
   把文件路径和纯文本路径重新合并为一个变量。

6. `合同要素抽取`
   用 Parameter Extractor 抽取主体、标的、金额、付款、期限、交付验收、质量标准、违约责任、解除终止、争议解决等关键要素。

7. `组装专业上下文`
   汇总 APP 字段、抽取结果、评分规则、合同类型 checklist、引用策略。

8. `三类意图识别`
   使用 Dify Question Classifier 固定识别三类：`review` 审查合同、`generate` 生成合同、`consult` 咨询和其他。这里不使用 If/Else 默认分支；三条线分别直连对应 LLM。

9. `专业合同审查`
   生成普通用户可读的审查 JSON 和 `markdown_report`。

10. `专业合同生成`
   生成完整合同草案 JSON 和 `contract_markdown`。

11. `合同咨询与需求澄清`
   回答合同知识、处理闲聊和不明确需求，不强行进入审查或生成。

12. `JSON 质量门`
   清理 `<think>`、Markdown 代码块外壳、JSON 外文字，并统一 A-E 评分字段。

13. `Answer`
   返回 APP 可解析 JSON。

## 参考工作流吸收点

- 社区合同信息提取案例通常是「上传文件 -> 文档提取 -> LLM 结构化 -> Markdown/JSON 输出」，合同帮V1保留这个稳定主链路，但输出改成 APP 可直接解析的双模式 JSON。
- 社区合同审核 Agent 更强调「文件处理 -> 关键点审核 -> 审核报告」，合同帮V1把关键点审核进一步细化为合同类型 checklist、八个 APP 关注重点、A-E 评分和修改建议。
- 合同审核聊天机器人案例通常让用户先选择合同类型、上传合同、输入审核要求，再输出详细报告；合同帮V1与 APP 表单一致，把这些输入固定为 `contract_type`、`role`、`focus_areas`、`requirements`。
- `.doc` 老格式在部分实践中需要额外转换插件，V1 先聚焦 PDF / DOCX / TXT / Markdown，减少导入后首版不可控点。

## 五档评分

score 是合同安全/可用分，越高越安全可用：

| 等级 | 分数 | 含义 |
| --- | --- | --- |
| A | 90-100 | 低风险，基本可直接使用或签署前做常规确认 |
| B | 80-89 | 较低风险，整体可用，但建议优化若干条款 |
| C | 70-79 | 中等风险，风险可控，但关键条款应修改后再使用 |
| D | 60-69 | 较高风险，不建议直接签署或发送，应系统修订 |
| E | 0-59 | 重大风险、信息严重不足或风险不可控 |

生成合同时，score 表示草案完整度和可用度；审查合同时，score 表示合同当前安全/可签程度。

## 合同类型 checklist

### 买卖/采购合同

- 主体资质
- 标的规格
- 数量质量
- 价款支付
- 交货验收
- 所有权与风险转移
- 违约责任
- 争议解决

### 房屋租赁合同

- 房屋权属
- 租期
- 租金押金
- 用途限制
- 维修责任
- 转租装修
- 解除退租
- 违约与腾退

#### 房屋租赁合同生成强规则

- 正式生成前核对 9 项必要信息：双方姓名和身份证号、双方联系电话、房屋详细地址、房屋面积/户型或交付状态、租期起止时间、租金金额和周期、押金金额及退还条件和时间、付款周期/付款方式、水电气物业等费用承担。
- 任意关键项缺失时，不得编造姓名、证件号、电话、地址、金额、日期；应集中追问缺失项，或只用 `[待补充]` 占位。
- 用户明确只要模板/范本/空白框架时，可以输出空白模板，但必须说明不是正式合同。
- 信息齐备并正式生成时，至少包含标题、双方主体、房屋信息、租期、租金与付款、押金、费用承担、维修、转租/同住、解除、违约、争议解决、签署日期与签字栏。

#### 房屋租赁合同审查强规则

- 红色风险优先识别；红黄之间存疑时从严按红色提示，黄绿之间存疑时按黄色提示。
- 红色方向包括主体/权属不适格、租期超过法定上限、强制租金贷或明显违法费用、非居住空间/违法群租、剥夺法定解除/投诉维权/随意入户、违法用途或歧视条款。
- 黄色方向包括交付清单缺失、租金/水电/物业规则模糊、押金退还期限不明、维修责任不清、提前退租/续租机制不明、返还验收流程缺失、转租/同住/宠物/拆迁/争议解决未约定。
- 黄色风险必须说明对谁不利、可能引发什么纠纷，并给出可执行修改建议。

### 劳动/用工合同

- 主体身份
- 岗位地点
- 工时休假
- 薪酬社保
- 试用期
- 保密竞业
- 解除终止
- 劳动争议

### 服务/委托合同

- 服务范围
- 成果标准
- 服务费用
- 双方配合义务
- 期限交付
- 保密/知识产权
- 违约责任
- 解约机制

### 承揽/加工定作合同

- 定作要求
- 材料供应
- 加工质量
- 交付验收
- 报酬结算
- 瑕疵整改
- 风险转移
- 违约责任

### 建设工程合同

- 主体资质
- 工程范围
- 工期节点
- 价款结算
- 质量安全
- 变更签证
- 竣工验收
- 违约争议

### 技术/软件合同

- 需求范围
- 里程碑
- 交付验收
- 源码/知识产权
- 维护支持
- 数据安全
- 付款节点
- 违约/退出

### 借款/担保合同

- 本金利息
- 借款用途
- 期限还款
- 担保范围
- 抵质押/保证
- 提前到期
- 逾期责任
- 管辖争议

### 其他/自定义

按通用八项检查：签约主体、合同事项、价款付款、履行交付、质量标准、违约责任、解除终止、争议解决。

## 审查输出重点

审查结果必须回答四件事：

- 这份合同当前能不能签
- 主要风险在哪里
- 为什么这些条款危险
- 应该怎么改

主字段：

- `intent=review`
- `status=complete | need_input`
- `score`
- `grade`
- `risk_level`
- `summary`
- `information_completeness`
- `facts`
- `risk_counts`
- `key_findings`
- `clause_reviews`
- `suggested_revisions`
- `signature_checklist`
- `markdown_report`

## 生成输出重点

生成结果必须回答五件事：

- 生成了什么合同
- 这份合同偏保护谁
- 哪些信息来自用户
- 哪些信息是默认假设或待补齐
- 签署前还要确认什么

主字段：

- `intent=generate`
- `status=complete | need_input`
- `score`
- `grade`
- `contract_title`
- `summary`
- `missing_fields`
- `followup_questions`
- `assumptions`
- `facts_to_confirm`
- `clause_outline`
- `contract_markdown`
- `risk_notes`
- `signing_checklist`
- `next_steps`

## 咨询输出重点

咨询结果必须回答三件事：

- 用户当前问题的通俗答案
- 这类合同问题常见风险或注意事项
- 下一步应该走审查、生成，还是继续补充信息

主字段：

- `intent=consult`
- `status=complete | need_input`
- `result_type=contract_consultation`
- `title`
- `topic`
- `summary`
- `answer_markdown`
- `key_points`
- `practical_tips`
- `risk_notes`
- `recommended_mode=review | generate | consult`
- `followup_questions`
- `suggested_actions`

## 信息不足策略

### 审查合同

- 没有合同正文或可审查条款：`status=need_input`
- 合同正文存在但局部缺失：继续审查，并把缺失项写入 `information_completeness.missing_fields`

### 生成合同

- 只说“帮我生成合同”且没有合同类型/交易事项：`status=need_input`
- 有合同类型和基本交易事项，但缺少金额、期限、对方主体等：可以生成初稿，用 `[待补充]` 占位，并写入 `missing_fields`

### 合同咨询

- 用户问合同知识、注意事项、流程、概念解释：`status=complete`
- 用户只是闲聊或不知道自己要做什么：`status=complete`，简短说明合同帮能力，并给出下一步入口
- 用户表达了业务背景但不足以生成/审查：`status=need_input` 或 `complete`，用 `followup_questions` 追问 2-5 个关键问题

## 法律引用策略

当前工作流不伪造精确法条。

V1 输出里的 `legal_references` 只说明法规知识库尚未连接。后续接入知识库后，再让该字段返回可核验引用。

建议后续单独建设法规知识库：

- 《中华人民共和国民法典》合同编及相关条文
- 最高人民法院合同纠纷相关司法解释
- 劳动合同法及劳动争议相关规则
- 建设工程、房屋租赁、担保、知识产权等专题资料
- 常用合同模板与条款库

## 验收用例

### 自动判断：房东生成租房合同

输入：

- `mode=auto`
- `contract_type=房屋租赁合同`
- `role=房东（出租方）`
- `contract_text=我是房东，我想做个租房合同`

预期：

- 进入生成分支
- `intent=generate`
- 有 `contract_markdown`
- 合同内容偏保护出租方
- 不应进入审查分支

### 自动判断：租房合同知识咨询

输入：

- `mode=auto`
- `contract_type=房屋租赁合同`
- `contract_text=租房合同要注意什么`

预期：

- 进入咨询分支
- `intent=consult`
- `recommended_mode=consult`
- 有 `answer_markdown`
- 不应输出完整合同正文
- 不应进入审查分支

### 自动判断：闲聊和能力介绍

输入：

- `mode=auto`
- `contract_text=你好，你能做什么`

预期：

- 进入咨询分支
- `intent=consult`
- 简短介绍合同审查、合同生成、合同咨询
- 给出下一步建议

### 审查：软件开发服务合同

输入：

- `mode=review`
- `contract_type=技术/软件合同`
- `role=甲方（我方）`
- `focus_areas=签约主体,合同事项,付款风险,交付验收,质量标准,违约责任,解除终止,争议解决`
- 合同正文包含付款节点、源码交付、验收、违约责任

预期：

- `intent=review`
- `status=complete`
- 有 `score` 和 `grade`
- 有 `clause_reviews`
- 有 `markdown_report`
- 不包含 `<think>`
- 不包含 Markdown 代码块外壳

### 审查：无正文

输入：

- `mode=review`
- `contract_text=` 空

预期：

- `intent=review`
- `status=need_input`
- `score=0`
- `grade=E`
- `followup_questions` 要求用户提供合同正文或上传文件

### 生成：软件开发服务合同

输入：

- `mode=generate`
- `contract_type=技术/软件合同`
- `role=甲方（我方）`
- `focus_areas=双方信息,合作内容,价款报酬,履行安排,交付验收,质量标准,违约责任,争议解决`
- `requirements=生成一份软件开发服务合同，甲方采购，分三期付款，乙方交付源码和部署文档，偏保护甲方`

预期：

- `intent=generate`
- `status=complete`
- 有 `score` 和 `grade`
- 有 `contract_markdown`
- 付款、交付验收、源码/知识产权、违约责任明确
- 不包含 `<think>`
- 不包含 Markdown 代码块外壳

### 生成：严重信息不足

输入：

- `mode=generate`
- `contract_text=帮我生成合同`

预期：

- `intent=generate`
- `status=need_input`
- `score=0`
- `grade=E`
- `followup_questions` 追问合同类型、交易事项、双方角色、价款和期限
