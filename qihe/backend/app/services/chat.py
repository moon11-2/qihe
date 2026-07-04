from functools import lru_cache
from pathlib import Path
from typing import Any

from app.models.chat import ChatRequest, ChatResponse
from app.services.llm.base import LLMProvider
from app.services.llm.qwen import create_qwen_provider

PROMPT_DIR = Path(__file__).resolve().parents[1] / "prompts"
REVIEW_KEYWORDS = ("审查", "审核", "风险", "条款", "看合同", "看看合同", "有没有问题", "合同体检")
GENERATE_KEYWORDS = ("生成", "起草", "拟一份", "写一份", "合同模板", "草案", "帮我写")
CONTRACT_KEYWORDS = ("合同", "协议", "条款")


@lru_cache
def _load_prompt(name: str) -> str:
    return (PROMPT_DIR / f"{name}.md").read_text(encoding="utf-8")


async def build_chat_response(request: ChatRequest, provider: LLMProvider | None = None) -> ChatResponse:
    last_message = _last_user_message(request)
    if not last_message:
        return _need_input_response("请告诉我你想审查合同，还是生成一份合同。")

    llm = provider or create_qwen_provider()
    try:
        intent_data = await llm.chat_json(_intent_messages(last_message), schema_name="intent")
        intent_response = _normalize_intent_response(intent_data)
    except Exception:
        intent_response = _keyword_intent_response(last_message)

    if intent_response.intent != "chat":
        return intent_response

    try:
        reply = await llm.chat(_chat_messages(request))
    except Exception:
        reply = "我可以帮你梳理合同问题、准备审查材料，或进入合同生成流程。涉及审查或起草时，我会以 AI 辅助方式处理，不构成法律意见。"

    return ChatResponse(type="chat", intent="chat", reply=reply, options=[])


def _intent_messages(last_message: str) -> list[dict[str, str]]:
    return [
        {"role": "system", "content": _load_prompt("intent")},
        {"role": "user", "content": last_message},
    ]


def _chat_messages(request: ChatRequest) -> list[dict[str, str]]:
    return [
        {"role": "system", "content": _load_prompt("chat")},
        *[{"role": message.role, "content": message.content} for message in request.messages],
    ]


def _last_user_message(request: ChatRequest) -> str:
    for message in reversed(request.messages):
        if message.role == "user":
            return message.content.strip()
    return ""


def _normalize_intent_response(data: dict[str, Any]) -> ChatResponse:
    intent = data.get("intent")
    response_type = data.get("type")
    reply = str(data.get("reply") or "").strip()

    if intent == "review":
        return ChatResponse(
            type="route",
            intent="review",
            route="review",
            reply=reply or "我会进入合同审查流程，请上传合同文件或粘贴合同文本。",
        )

    if intent == "generate":
        return ChatResponse(
            type="route",
            intent="generate",
            route="generate",
            reply=reply or "我会进入合同生成流程，请补充合同类型、双方主体、金额、期限和关键条款。",
        )

    if intent == "chat" and response_type == "chat":
        return ChatResponse(type="chat", intent="chat", reply=reply or "我可以帮你梳理合同相关问题。")

    return _need_input_response(reply or "你想让我审查已有合同，还是帮你生成合同草案？")


def _keyword_intent_response(text: str) -> ChatResponse:
    has_review = any(keyword in text for keyword in REVIEW_KEYWORDS)
    has_generate = any(keyword in text for keyword in GENERATE_KEYWORDS)
    has_contract = any(keyword in text for keyword in CONTRACT_KEYWORDS)

    if has_review and not has_generate:
        return ChatResponse(
            type="route",
            intent="review",
            route="review",
            reply="我会进入合同审查流程，请上传合同文件或粘贴合同文本。",
        )
    if has_generate and not has_review:
        return ChatResponse(
            type="route",
            intent="generate",
            route="generate",
            reply="我会进入合同生成流程，请补充合同类型、双方主体、金额、期限和关键条款。",
        )
    if has_review and has_generate:
        return _need_input_response("你是想审查已有合同，还是生成新的合同草案？")
    if has_contract:
        return _need_input_response("你想让我审查已有合同，还是帮你生成合同草案？")

    return ChatResponse(
        type="chat",
        intent="chat",
        reply="我可以帮你做合同审查和合同生成。你可以直接说明需求，或上传 PDF、DOCX、TXT 合同文件。",
    )


def _need_input_response(reply: str) -> ChatResponse:
    return ChatResponse(
        type="need_input",
        intent="unknown",
        reply=reply,
        need_input=["选择合同审查或合同生成"],
        options=["review", "generate"],
    )
