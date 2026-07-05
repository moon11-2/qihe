from functools import lru_cache
from pathlib import Path
from typing import Any

from app.models.chat import ChatRequest, ChatResponse
from app.services.llm.base import LLMProvider
from app.services.llm.qwen import create_qwen_provider

PROMPT_DIR = Path(__file__).resolve().parents[1] / "prompts"
REVIEW_KEYWORDS = (
    "审查",
    "审核",
    "检查",
    "评估",
    "审一审",
    "审一下",
    "把关",
    "过一遍",
    "找问题",
    "找风险",
    "有没有坑",
    "有没有问题",
    "能不能签",
    "是否可以签",
    "是否合法",
    "是否有效",
    "合同体检",
)
GENERATE_KEYWORDS = ("生成", "起草", "拟", "拟一份", "拟定", "草拟", "写", "写一份", "帮我写", "做一份", "做个", "出一份", "给我一份", "模板", "草案")
CONTRACT_OBJECT_KEYWORDS = ("合同", "协议", "条款", "文件", "正文", "NDA", "租房", "租赁", "劳动", "买卖", "服务", "委托", "保密", "借款", "担保", "合作")
REVIEW_ACTION_KEYWORDS = ("看", "看看", "看下", "过一遍", "把关", "有没有坑", "有没有问题", "检查", "评估", "审一审", "审一下")
CONSULTATION_KEYWORDS = ("什么是", "什么意思", "怎么理解", "流程", "需要哪些信息", "注意事项", "常见风险", "有哪些", "如何准备", "是什么", "怎么做")
CONCRETE_DOCUMENT_KEYWORDS = ("这份", "这个", "我的", "以下", "上述", "附件", "已上传", "粘贴", "全文", "原文", "发给你")
REVIEW_RESULT_CONTEXT_KEYWORDS = ("审查结果", "风险标题", "涉及条款", "修订建议", "原文摘录", "风险说明", "替代表述")
FOLLOW_UP_QUESTION_KEYWORDS = ("怎么改", "如何改", "怎么谈", "如何谈", "严重吗", "可否", "能否", "替代表述", "怎么处理", "怎么办")
EXPLICIT_REVIEW_RERUN_KEYWORDS = ("重新审查", "重新审核", "再审查", "再审核")
UNCERTAIN_CHOICE_KEYWORDS = ("不确定", "还是")


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
    has_contract_object = any(keyword in text for keyword in CONTRACT_OBJECT_KEYWORDS)
    explicit_review_rerun = any(keyword in text for keyword in EXPLICIT_REVIEW_RERUN_KEYWORDS)
    is_consultation = has_contract_object and any(keyword in text for keyword in CONSULTATION_KEYWORDS)
    has_concrete_document = any(keyword in text for keyword in CONCRETE_DOCUMENT_KEYWORDS)
    has_generate = any(keyword in text for keyword in GENERATE_KEYWORDS) and has_contract_object
    is_uncertain_choice = all(keyword in text for keyword in UNCERTAIN_CHOICE_KEYWORDS)
    if is_consultation and not has_concrete_document:
        return ChatResponse(
            type="chat",
            intent="chat",
            reply="我可以先解释合同相关概念或流程；如果你要审查或起草，也可以直接告诉我。",
        )

    if has_generate and not explicit_review_rerun and not is_uncertain_choice:
        return ChatResponse(
            type="route",
            intent="generate",
            route="generate",
            reply="我会进入合同生成流程，请补充合同类型、双方主体、金额、期限和关键条款。",
        )

    is_review_follow_up = any(keyword in text for keyword in REVIEW_RESULT_CONTEXT_KEYWORDS) and any(
        keyword in text for keyword in FOLLOW_UP_QUESTION_KEYWORDS
    )

    if is_review_follow_up and not explicit_review_rerun and not has_generate:
        return ChatResponse(
            type="chat",
            intent="chat",
            reply="我可以继续解释审查结果、修改思路和沟通要点；如果你要重新审查或生成完整合同，也可以直接说明。",
        )

    has_review = explicit_review_rerun or any(keyword in text for keyword in REVIEW_KEYWORDS) or (
        has_contract_object and any(keyword in text for keyword in REVIEW_ACTION_KEYWORDS)
    )

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
    if has_contract_object:
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
