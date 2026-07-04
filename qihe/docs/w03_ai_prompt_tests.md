# W03 AI Prompt 验收样例

## 1. 租房合同审查

输入：

```txt
甲方张三将房屋出租给乙方李四，租期一年，租金每月5000元，押金一个月，退租后退还。
```

期望输出要点：

```json
{
  "summary": "包含 AI 辅助审查、不构成法律意见的说明",
  "review_basis": "基于用户提供合同文本和一般合同审查关注点",
  "risk_level": "中风险",
  "score": 76,
  "parties": {
    "party_a": "张三",
    "party_b": "李四",
    "amount": "每月 5000 元",
    "term": "一年",
    "contract_type": "房屋租赁合同",
    "jurisdiction": null
  },
  "clause_reviews": [
    {
      "risk_title": "押金退还条件不清",
      "clause": "押金一个月，退租后退还。",
      "risk_analysis": "未明确退还时间、扣除范围和交接标准。",
      "revision_suggestion": "补充押金退还期限、扣除条件和验收交接方式。",
      "suggested_replacement": "租赁期满且乙方结清费用、完成交接后，甲方应在 7 日内退还押金；如需扣除，应列明依据和金额。",
      "legal_basis": ["民法典合同编一般规则"]
    }
  ]
}
```

## 2. 买卖合同生成

输入：

```txt
帮我生成买卖合同：A公司向B公司采购办公椅100把，总价3万元，30天内交付。
```

期望输出要点：

```json
{
  "title": "货物买卖合同",
  "draft": "包含合同正文、双方信息、标的、价款、交付、验收、违约责任、争议解决和签署栏",
  "missing_fields": ["交付地点", "验收标准", "争议解决方式"],
  "pre_sign_checklist": ["核对双方授权", "核对付款节点", "核对交付验收"],
  "notes": ["AI 辅助起草，不构成法律意见。"]
}
```

## 3. 不确定意图

输入：

```txt
我这个合同帮我处理一下
```

期望输出：

```json
{
  "type": "need_input",
  "intent": "unknown",
  "reply": "你想审查已有合同，还是生成新的合同草案？",
  "route": null,
  "need_input": ["选择合同审查或合同生成"],
  "options": ["review", "generate"]
}
```
