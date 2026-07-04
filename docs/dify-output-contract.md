# 合同帮V1 Dify 输出契约

用途：让「合同帮」APP 稳定渲染 Dify 返回结果。当前支持三类 intent：

- `review`
- `generate`
- `consult`

没有 `revise` intent。信息不足时使用 `status=need_input` 或在 `consult` 分支返回追问。

输入侧可以使用 `mode=auto` 做自然语言意图判断，输出侧只允许返回 `intent=review`、`intent=generate` 或 `intent=consult`。

## 通用约定

所有输出必须是纯 JSON：

- 不要 Markdown 代码块外壳
- 不要 JSON 外说明文字
- 不要 `<think>`
- 审查和生成必须返回 `score` 与 `grade`
- 咨询分支不做 A-E 评分

## 五档评分

| grade | score | 审查含义 | 生成含义 |
| --- | --- | --- | --- |
| A | 90-100 | 低风险，基本可直接使用或签署前做常规确认 | 信息充分，草案结构完整 |
| B | 80-89 | 较低风险，整体可用，但建议优化若干条款 | 整体可用，少量字段需补齐 |
| C | 70-79 | 中等风险，风险可控，但关键条款应修改后再使用 | 可作为初稿，关键商业信息需补齐 |
| D | 60-69 | 较高风险，不建议直接签署或发送 | 信息不足较多，仅适合作为框架 |
| E | 0-59 | 重大风险、信息严重不足或风险不可控 | 信息严重不足，不应生成完整合同 |

## 咨询输出

```json
{
  "intent": "consult",
  "status": "complete",
  "result_type": "contract_consultation",
  "title": "房屋租赁合同注意事项",
  "topic": "租房合同要注意什么",
  "contract_type": "房屋租赁合同",
  "role": "房东（出租方）",
  "summary": "租房合同重点要看房屋信息、租期租金、押金、维修责任、解除退租和违约责任。",
  "answer_markdown": "# 简要回答\n租房合同要重点确认房屋权属、租期、租金押金、维修责任、提前退租、违约责任和争议解决。\n\n## 你需要知道的点\n...\n\n## 下一步怎么做\n如果你要起草合同，可以选择生成合同；如果已有合同，可以上传后审查。",
  "key_points": [
    "确认出租方是否有权出租",
    "写清租期、租金、押金和付款方式",
    "明确维修、转租、提前退租和违约责任"
  ],
  "practical_tips": [
    "签约前核对房产证明或授权材料",
    "押金退还条件要写清楚",
    "水电物业等费用承担要列明"
  ],
  "risk_notes": [
    "只口头约定押金和退租条件，后续容易争议",
    "没有写清维修责任，房屋损坏时容易互相推责"
  ],
  "recommended_mode": "consult",
  "followup_questions": [
    "你是房东还是租客？",
    "你是想了解注意事项，还是要生成一份合同？"
  ],
  "suggested_actions": [
    "需要起草时进入生成合同",
    "已有合同文本时进入审查合同"
  ],
  "legal_references": [
    {
      "title": "法规知识库未连接",
      "source_type": "knowledge_base",
      "verification_status": "not_connected",
      "note": "后续接入法规知识库后再返回可核验引用。"
    }
  ],
  "disclaimer": "AI 辅助说明不构成律师法律意见；重要合同请交由专业律师复核。"
}
```

## 审查输出

```json
{
  "intent": "review",
  "status": "complete",
  "result_type": "review_report",
  "title": "软件开发服务合同审查报告",
  "contract_type": "技术/软件合同",
  "role": "甲方（我方）",
  "score": 76,
  "grade": "C",
  "grade_label": "中等风险，风险可控，但关键条款应修改后再使用",
  "risk_level": "medium",
  "score_explanation": "主要扣分点是验收标准、知识产权和违约责任不够明确。",
  "summary": "这份合同可以作为谈判基础，但不建议按当前版本直接签署。",
  "information_completeness": {
    "score": 78,
    "missing_fields": ["乙方完整主体信息", "验收标准附件"],
    "assumptions": [],
    "limitations": ["未看到完整附件，附件相关判断可能不完整。"]
  },
  "facts": {
    "parties": "甲方与乙方",
    "subject_matter": "软件开发服务",
    "amount": "380000 元",
    "payment_terms": "分三期付款",
    "term": "2024-08-01 至 2025-07-31",
    "delivery_acceptance": "交付源码和部署文档，验收标准不清",
    "quality_standard": "未明确",
    "breach_liability": "违约金偏低",
    "termination": "解除条件不完整",
    "dispute_resolution": "约定管辖法院"
  },
  "risk_counts": {
    "critical": 0,
    "high": 2,
    "medium": 3,
    "low": 2,
    "notice": 1
  },
  "key_findings": [
    "尾款支付与验收标准绑定不清",
    "源码及成果知识产权归属不够明确",
    "违约责任可能不足以覆盖实际损失"
  ],
  "clause_reviews": [
    {
      "focus_area": "付款风险",
      "clause_title": "付款与验收",
      "original_text": "尾款在验收后支付。",
      "risk_level": "high",
      "issue": "未定义验收标准、验收期限和视为验收情形。",
      "impact": "容易产生是否应付款的争议。",
      "favored_party": "乙方",
      "suggestion": "补充验收标准、整改期限、二次验收和尾款支付条件。",
      "replacement_text": "建议替换条款正文...",
      "priority": "P1"
    }
  ],
  "suggested_revisions": [
    {
      "clause_title": "验收与付款",
      "original_text": "原条款",
      "replacement_text": "可复制替换条款",
      "reason": "降低验收争议和尾款争议。",
      "favored_party": "甲方"
    }
  ],
  "signature_checklist": [
    "补齐双方完整主体信息",
    "确认交付物清单和验收附件",
    "确认知识产权归属和源码交付边界"
  ],
  "legal_references": [
    {
      "title": "法规知识库未连接",
      "source_type": "knowledge_base",
      "verification_status": "not_connected",
      "note": "后续接入法规知识库后再返回可核验引用。"
    }
  ],
  "followup_questions": [],
  "markdown_report": "# 审查结论\n\n可直接展示给用户的审查报告。",
  "disclaimer": "AI 辅助审查，不构成律师法律意见；重要合同请交由专业律师复核。"
}
```

## 审查信息不足

```json
{
  "intent": "review",
  "status": "need_input",
  "result_type": "review_report",
  "title": "需要提供合同正文",
  "contract_type": "技术/软件合同",
  "role": "甲方（我方）",
  "score": 0,
  "grade": "E",
  "grade_label": "信息严重不足，暂不能完成可靠审查",
  "risk_level": "unknown",
  "score_explanation": "缺少合同正文，无法判断风险。",
  "summary": "请先粘贴合同正文或上传合同文件。",
  "information_completeness": {
    "score": 0,
    "missing_fields": ["合同正文"],
    "assumptions": [],
    "limitations": ["没有可审查文本。"]
  },
  "facts": {},
  "risk_counts": {
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0,
    "notice": 0
  },
  "key_findings": [],
  "clause_reviews": [],
  "suggested_revisions": [],
  "signature_checklist": [],
  "legal_references": [],
  "followup_questions": ["请粘贴合同正文，或上传 PDF/Word/TXT 合同文件。"],
  "markdown_report": "请先提供合同正文。",
  "disclaimer": "AI 辅助审查，不构成律师法律意见；重要合同请交由专业律师复核。"
}
```

## 生成输出

```json
{
  "intent": "generate",
  "status": "complete",
  "result_type": "contract_draft",
  "contract_title": "软件开发服务合同",
  "contract_type": "技术/软件合同",
  "role": "甲方（我方）",
  "score": 84,
  "grade": "B",
  "grade_label": "整体可用，少量字段需补齐",
  "summary": "已按偏保护甲方的立场生成软件开发服务合同草案。",
  "missing_fields": ["甲方完整名称", "乙方完整名称", "具体交付日期"],
  "followup_questions": [],
  "assumptions": [
    "双方主体信息签署前补齐",
    "付款分三期，具体日期以双方确认后填写"
  ],
  "facts_to_confirm": [
    "合同金额",
    "交付物清单",
    "验收标准",
    "维护服务期限"
  ],
  "clause_outline": [
    {
      "section": "双方信息",
      "purpose": "确认合同主体和联系方式",
      "included": true,
      "source": "required"
    }
  ],
  "contract_markdown": "# 软件开发服务合同\n\n完整合同正文...",
  "risk_notes": [
    "签署前必须补齐交付物清单和验收标准。",
    "金额较大时建议律师复核知识产权和违约责任条款。"
  ],
  "signing_checklist": [
    "补齐双方公司名称、统一社会信用代码、地址和联系人",
    "确认价款、付款节点和发票类型",
    "确认交付物、验收标准和整改期限"
  ],
  "legal_references": [
    {
      "title": "法规知识库未连接",
      "source_type": "knowledge_base",
      "verification_status": "not_connected",
      "note": "后续接入法规知识库后再返回可核验引用。"
    }
  ],
  "next_steps": [
    "补齐空白字段后再发送给对方确认",
    "签署前对金额、交付、验收、知识产权和违约责任做最终确认"
  ],
  "disclaimer": "AI 辅助起草，不构成律师法律意见；重要合同请交由专业律师复核。"
}
```

## 生成信息不足

```json
{
  "intent": "generate",
  "status": "need_input",
  "result_type": "contract_draft",
  "contract_title": "需要补充生成信息",
  "contract_type": "其他类型（不确定）",
  "role": "未知",
  "score": 0,
  "grade": "E",
  "grade_label": "信息严重不足，暂不能生成可靠合同",
  "summary": "目前还不能稳定生成合同，需要先补充关键交易信息。",
  "missing_fields": ["合同类型", "交易或合作事项", "双方角色", "价款或报酬", "履行期限"],
  "followup_questions": [
    "你想生成什么类型的合同？",
    "这份合同主要约定什么交易、服务或合作？",
    "你是甲方还是乙方？",
    "价款、付款方式或报酬标准是什么？",
    "预计履行期限或交付时间是什么？"
  ],
  "assumptions": [],
  "facts_to_confirm": [],
  "clause_outline": [],
  "contract_markdown": "",
  "risk_notes": [],
  "signing_checklist": [],
  "legal_references": [],
  "next_steps": ["补充上述信息后重新生成。"],
  "disclaimer": "AI 辅助起草，不构成律师法律意见；重要合同请交由专业律师复核。"
}
```

## APP 渲染建议

- 顶部评分：`score` + `grade` + `grade_label`
- 审查结论：`summary`
- 审查正文：`markdown_report`
- 生成正文：`contract_markdown`
- 风险卡片：`clause_reviews`
- 修改建议：`suggested_revisions`
- 生成目录：`clause_outline`
- 签署清单：`signature_checklist` 或 `signing_checklist`
- 信息不足：`missing_fields` + `followup_questions`
- 可靠引用：`legal_references`，只有 `verification_status=verified` 时才作为正式依据展示
