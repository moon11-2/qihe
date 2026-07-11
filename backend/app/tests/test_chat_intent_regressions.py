import asyncio

import pytest

from app.models.chat import ChatMessage, ChatRequest
from app.services.chat import build_chat_response


class StubProvider:
    def __init__(self, intent: str = "unknown", response_type: str = "need_input") -> None:
        self.intent = intent
        self.response_type = response_type

    async def chat_json(self, messages: list[dict[str, str]], schema_name: str) -> dict:
        return {
            "type": self.response_type,
            "intent": self.intent,
            "reply": "模型返回的意图",
            "route": None,
            "options": ["review", "generate"],
        }

    async def chat(self, messages: list[dict[str, str]]) -> str:
        return "普通聊天回复"


def _respond(text: str, provider: StubProvider | None = None):
    request = ChatRequest(messages=[ChatMessage(role="user", content=text)])
    return asyncio.run(build_chat_response(request, provider=provider or StubProvider()))


@pytest.mark.parametrize("text", ["生成合同吧", "帮我写一份租赁合同", "起草合同"])
def test_explicit_generate_keywords_override_unknown_llm(text: str) -> None:
    response = _respond(text)

    assert response.type == "route"
    assert response.intent == "generate"
    assert response.route == "generate"
    assert response.options == []


@pytest.mark.parametrize("text", ["审一下合同", "检查合同风险"])
def test_explicit_review_keywords_override_chat_llm(text: str) -> None:
    response = _respond(text, StubProvider(intent="chat", response_type="chat"))

    assert response.type == "route"
    assert response.intent == "review"
    assert response.route == "review"
    assert response.options == []


def test_mixed_review_and_generate_requires_choice() -> None:
    response = _respond("审一下这份合同并帮我起草合同")

    assert response.type == "need_input"
    assert response.intent == "unknown"
    assert response.route is None
    assert response.options == ["review", "generate"]


def test_genuinely_unknown_intent_requires_choice() -> None:
    response = _respond("我有个合同相关的事情")

    assert response.type == "need_input"
    assert response.intent == "unknown"
    assert response.route is None
    assert response.options == ["review", "generate"]


def test_unknown_llm_does_not_turn_clear_consultation_into_need_input() -> None:
    response = _respond("合同审查流程是什么")

    assert response.type == "chat"
    assert response.intent == "chat"
    assert response.route is None
    assert response.options == []


@pytest.mark.parametrize("text", ["检查登录状态", "评估产品方案"])
def test_generic_non_contract_actions_do_not_route_to_review(text: str) -> None:
    response = _respond(text)

    assert response.type == "chat"
    assert response.intent == "chat"
    assert response.route is None


def test_contract_authorship_question_does_not_route_to_generate() -> None:
    response = _respond("这个合同是谁写的")

    assert response.type == "chat"
    assert response.intent == "chat"
    assert response.route is None


def test_generate_complete_contract_from_review_result_routes_to_generate() -> None:
    response = _respond("根据审查结果生成一份完整合同")

    assert response.type == "route"
    assert response.intent == "generate"
    assert response.route == "generate"
    assert response.options == []


def test_generate_complete_contract_from_review_report_routes_to_generate() -> None:
    response = _respond("根据审查报告起草一份完整合同")

    assert response.type == "route"
    assert response.intent == "generate"
    assert response.route == "generate"
