from pathlib import Path

from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import create_app
from app.services.llm.base import parse_json_object


class FakeProvider:
    def __init__(self, payload: dict) -> None:
        self.payload = payload

    async def chat_json(self, messages: list[dict[str, str]], schema_name: str) -> dict:
        return self.payload

    async def chat(self, messages: list[dict[str, str]]) -> str:
        return "这是自由聊天回复。"


def _client(tmp_path: Path, monkeypatch) -> TestClient:
    monkeypatch.setattr(settings, "auth_db_path", str(tmp_path / "auth.sqlite3"))
    monkeypatch.setattr(settings, "jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "jwt_expires_minutes", 60)
    client = TestClient(create_app())
    response = client.post(
        "/api/auth/register",
        json={
            "email": f"prompts-{id(client)}@example.com",
            "password": "TestPassw0rd!",
        },
    )
    assert response.status_code == 200
    client.headers.update({"Authorization": f"Bearer {response.json()['access_token']}"})
    return client


def test_review_rental_contract_shape(tmp_path: Path, monkeypatch) -> None:
    expected = {
        "title": "租房合同审查报告",
        "summary": "押金退还和维修责任需要重点确认。",
        "review_basis": "基于用户提供的租房合同文本和一般合同审查关注点。",
        "risk_level": "中风险",
        "score": 76,
        "parties": {
            "party_a": "张三",
            "party_b": "李四",
            "amount": "5000",
            "term": "一年",
            "contract_type": "房屋租赁合同",
            "jurisdiction": None,
        },
        "clause_reviews": [
            {
                "risk_title": "押金退还条件不清",
                "risk_level": "中风险",
                "clause": "押金一个月，退租后退还。",
                "risk_analysis": "未明确退还时间、扣除范围和交接标准。",
                "revision_suggestion": "补充押金退还期限、扣除条件和验收交接方式。",
                "suggested_replacement": "租赁期满且乙方结清费用、完成交接后，甲方应在 7 日内退还押金；如需扣除，应列明依据和金额。",
                "legal_basis": ["民法典合同编一般规则"],
            }
        ],
    }
    monkeypatch.setattr(
        "app.services.contracts.review.create_qwen_provider",
        lambda: FakeProvider(expected),
    )

    client = _client(tmp_path, monkeypatch)
    response = client.post(
        "/api/contracts/run",
        json={
            "mode": "review",
            "text": "甲方张三将房屋出租给乙方李四，租期一年，租金每月5000元，押金一个月，退租后退还。",
        },
    )

    assert response.status_code == 200
    data = response.json()
    result = data["review_result"]
    assert data["type"] == "review_result"
    assert result["summary"].endswith("AI 辅助审查，不构成法律意见。")
    assert result["risk_level"] == "中风险"
    assert result["parties"]["party_a"] == "张三"
    assert result["parties"]["amount"] == "每月 5000元"
    assert result["parties"]["jurisdiction"] is None
    assert result["clause_reviews"][0]["risk_title"] == "押金退还条件不清"
    assert result["clause_reviews"][0]["clause_id"] == "risk_1"
    assert result["clause_reviews"][0]["original_excerpt"] == "押金一个月，退租后退还。"
    assert result["clause_reviews"][0]["start_offset"] is not None
    assert result["clause_reviews"][0]["end_offset"] is not None
    assert "legal_basis" in result["clause_reviews"][0]


def test_generate_sales_contract_shape(tmp_path: Path, monkeypatch) -> None:
    expected = {
        "title": "货物买卖合同",
        "draft": "货物买卖合同\n\n甲方：A 公司\n乙方：B 公司\n第一条 标的：采购办公椅 100 把。",
        "missing_fields": ["交付地点", "验收标准", "争议解决方式"],
        "pre_sign_checklist": ["核对双方授权", "核对付款节点", "核对交付验收"],
        "notes": ["请在签署前复核主体信息。"],
    }
    monkeypatch.setattr(
        "app.services.contracts.generate.create_qwen_provider",
        lambda: FakeProvider(expected),
    )

    client = _client(tmp_path, monkeypatch)
    response = client.post(
        "/api/contracts/run",
        json={
            "mode": "generate",
            "text": "帮我生成买卖合同：A公司向B公司采购办公椅100把，总价3万元，30天内交付。",
        },
    )

    assert response.status_code == 200
    data = response.json()
    result = data["generate_result"]
    assert data["type"] == "generate_result"
    assert result["title"] == "货物买卖合同"
    assert result["draft"].startswith("货物买卖合同")
    assert "交付地点" in result["missing_fields"]
    assert result["notes"][0] == "AI 辅助起草，不构成法律意见。"


def test_unknown_intent_needs_user_choice(tmp_path: Path, monkeypatch) -> None:
    expected = {
        "type": "need_input",
        "intent": "unknown",
        "reply": "你想审查已有合同，还是生成新的合同草案？",
        "route": None,
        "need_input": ["选择合同审查或合同生成"],
        "options": ["review", "generate"],
    }
    monkeypatch.setattr("app.services.chat.create_qwen_provider", lambda: FakeProvider(expected))

    client = _client(tmp_path, monkeypatch)
    response = client.post(
        "/api/chat",
        json={"messages": [{"role": "user", "content": "我这个合同帮我处理一下"}]},
    )

    assert response.status_code == 200
    assert response.json() == expected


def test_parse_json_object_repairs_markdown_wrapper() -> None:
    raw = """```json
{"type":"chat","intent":"chat","reply":"可以","options":[]}
```"""

    assert parse_json_object(raw)["intent"] == "chat"


def test_prompts_describe_metadata_and_review_anchor_fields() -> None:
    review_prompt = open("app/prompts/review.md", encoding="utf-8").read()
    generate_prompt = open("app/prompts/generate.md", encoding="utf-8").read()
    intent_prompt = open("app/prompts/intent.md", encoding="utf-8").read()

    for field in ("clause_id", "clause_title", "original_excerpt", "start_offset", "end_offset"):
        assert field in review_prompt
    for field in ("contract_type", "user_role", "my_position", "focus_areas"):
        assert field in review_prompt
    for field in ("contract_type", "user_role", "my_identity", "special_terms"):
        assert field in generate_prompt
    assert "合同知识咨询" in intent_prompt
