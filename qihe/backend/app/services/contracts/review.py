import json
import re
from typing import Any

from app.models.contracts import ClauseReview, ContractParties, ContractRunRequest, ContractSource, ReviewResult
from app.services.contracts.common import (
    append_once,
    bounded_score,
    load_prompt,
    metadata_text,
    pick_metadata,
    resolve_contract_input,
    risk_level,
    safe_output_text,
    safe_string_list,
    text_or_default,
    text_or_none,
)
from app.services.llm.base import LLMProvider
from app.services.llm.qwen import create_qwen_provider

REVIEW_DISCLAIMER = "AI 辅助审查，不构成法律意见。"
DEFAULT_LEGAL_BASIS = ["待确认：需结合具体事实和适用法律进一步核对"]
REVIEW_METADATA_LABELS = {
    "contract_type": "合同类型",
    "user_role": "用户角色",
    "my_position": "我的立场",
    "focus_areas": "重点关注",
}
REVIEW_METADATA_KEYS = ("contract_type", "user_role", "my_position", "focus_areas")


async def run_review(request: ContractRunRequest, provider: LLMProvider | None = None) -> ReviewResult:
    text, source = resolve_contract_input(request)
    if not text:
        return build_review_fallback(source, "未收到可审查的合同文本，请粘贴合同正文或上传可读取文件。")

    review_metadata = pick_metadata(request.metadata, REVIEW_METADATA_KEYS)
    llm = provider or create_qwen_provider()
    messages = [
        {"role": "system", "content": load_prompt("review")},
        {
            "role": "user",
            "content": (
                "请审查以下合同文本，并按指定 JSON schema 输出。\n\n"
                f"结构化审查条件 JSON：{json.dumps(review_metadata, ensure_ascii=False)}\n"
                f"结构化审查条件说明：\n{metadata_text(review_metadata, REVIEW_METADATA_LABELS) or '无'}\n\n"
                f"合同文本：\n{text}"
            ),
        },
    ]
    try:
        data = await llm.chat_json(messages, schema_name="contract_review")
    except Exception:
        return build_review_fallback(source, "AI 输出暂时未能稳定解析，已返回待确认的结构化审查结果。", text)

    return normalize_review_result(data, source, text)


def normalize_review_result(data: dict[str, Any], source: ContractSource, source_text: str = "") -> ReviewResult:
    parties_data = data.get("parties") if isinstance(data.get("parties"), dict) else {}
    clause_reviews = _normalize_clause_reviews(data.get("clause_reviews") or data.get("risk_items"), source_text)
    overall_level = risk_level(data.get("risk_level"), _derive_overall_level(clause_reviews))
    parties = _normalize_parties(parties_data, source_text)

    return ReviewResult(
        title=safe_output_text(text_or_default(data.get("title"), "合同审查报告")),
        summary=append_once(
            safe_output_text(text_or_default(data.get("summary"), "已完成结构化合同审查。")),
            REVIEW_DISCLAIMER,
        ),
        review_basis=append_once(
            safe_output_text(
                text_or_default(data.get("review_basis"), "基于用户提供的合同文本及一般合同审查关注点进行 AI 辅助审查。")
            ),
            REVIEW_DISCLAIMER,
        ),
        risk_level=overall_level,
        score=bounded_score(data.get("score")),
        risk_items=clause_reviews,
        clause_reviews=clause_reviews,
        parties=parties,
        source=source,
    )


def build_review_fallback(source: ContractSource, message: str, source_text: str = "") -> ReviewResult:
    original_excerpt = source_text[:160].strip() or None
    start_offset, end_offset = _locate_offsets(source_text, original_excerpt)
    fallback_reviews = [
        ClauseReview(
            clause_id="risk_1",
            clause_title="审查结果待确认",
            risk_title="审查结果待确认",
            risk_level="待确认",
            clause=original_excerpt,
            original_excerpt=original_excerpt,
            start_offset=start_offset,
            end_offset=end_offset,
            risk_analysis=message,
            revision_suggestion="请补充完整合同文本、双方主体、金额、期限、履行方式和争议解决条款后重新审查。",
            suggested_replacement=None,
            legal_basis=DEFAULT_LEGAL_BASIS,
        )
    ]
    return ReviewResult(
        title="合同审查报告",
        summary=append_once(message, REVIEW_DISCLAIMER),
        review_basis=append_once("基于用户提供文本进行结构化处理；当前信息不足或模型输出不稳定。", REVIEW_DISCLAIMER),
        risk_level="待确认",
        score=None,
        risk_items=fallback_reviews,
        clause_reviews=fallback_reviews,
        parties=_normalize_parties({}, source_text),
        source=source,
    )


def _normalize_clause_reviews(value: Any, source_text: str = "") -> list[ClauseReview]:
    if not isinstance(value, list):
        value = []

    reviews: list[ClauseReview] = []
    for index, item in enumerate(value, start=1):
        if not isinstance(item, dict):
            continue

        anchor = item.get("anchor") if isinstance(item.get("anchor"), dict) else {}
        clause = text_or_none(item.get("clause") or item.get("涉及条款") or item.get("clause_ref"))
        original_excerpt = text_or_none(
            item.get("original_excerpt")
            or item.get("原文摘录")
            or item.get("excerpt")
            or item.get("text")
            or anchor.get("excerpt")
            or anchor.get("text")
            or clause
        )
        start_offset = _int_or_none(item.get("start_offset") or item.get("start") or item.get("start_index") or anchor.get("start"))
        end_offset = _int_or_none(item.get("end_offset") or item.get("end") or item.get("end_index") or anchor.get("end"))
        if original_excerpt is None and start_offset is not None and end_offset is not None:
            original_excerpt = _excerpt_from_offsets(source_text, start_offset, end_offset)
        if start_offset is None or end_offset is None:
            start_offset, end_offset = _locate_offsets(source_text, original_excerpt)

        reviews.append(
            ClauseReview(
                clause_id=text_or_none(item.get("clause_id") or item.get("id")) or f"risk_{index}",
                clause_title=text_or_none(item.get("clause_title") or item.get("title_name") or item.get("clause_name"))
                or _derive_clause_title(clause or original_excerpt),
                risk_title=text_or_default(
                    safe_output_text(item.get("risk_title") or item.get("title") or item.get("clause_title")),
                    f"风险事项 {index}",
                ),
                risk_level=risk_level(item.get("risk_level") or item.get("level") or item.get("severity")),
                clause=clause,
                original_excerpt=original_excerpt,
                start_offset=start_offset,
                end_offset=end_offset,
                risk_analysis=text_or_default(
                    safe_output_text(item.get("risk_analysis") or item.get("description") or item.get("risk") or item.get("issue")),
                    "该事项需要结合完整合同文本进一步确认。",
                ),
                revision_suggestion=text_or_default(
                    safe_output_text(item.get("revision_suggestion") or item.get("suggestion")),
                    "建议补充明确约定，并在签署前由相关负责人复核。",
                ),
                suggested_replacement=text_or_none(
                    safe_output_text(item.get("suggested_replacement") or item.get("replacement") or item.get("replacement_text"))
                ),
                legal_basis=safe_string_list(item.get("legal_basis") or item.get("basis")) or DEFAULT_LEGAL_BASIS,
            )
        )

    if reviews:
        return reviews

    return [
        ClauseReview(
            clause_id="risk_1",
            clause_title="未识别到明确风险事项",
            risk_title="未识别到明确风险事项",
            risk_level="待确认",
            clause=None,
            original_excerpt=source_text[:160].strip() or None,
            start_offset=0 if source_text else None,
            end_offset=min(len(source_text), 160) if source_text else None,
            risk_analysis="模型未返回可定位的具体风险事项，需结合完整文本继续确认。",
            revision_suggestion="签署前仍建议核对主体、金额、期限、违约责任和争议解决条款。",
            suggested_replacement=None,
            legal_basis=DEFAULT_LEGAL_BASIS,
        )
    ]


def _derive_overall_level(clause_reviews: list[ClauseReview]) -> str:
    order = {"高风险": 4, "中风险": 3, "低风险": 2, "待确认": 1}
    if not clause_reviews:
        return "待确认"
    return max(clause_reviews, key=lambda item: order[item.risk_level]).risk_level


def _normalize_parties(parties_data: dict[str, Any], source_text: str) -> ContractParties:
    inferred = _infer_parties_from_text(source_text)
    amount = text_or_none(parties_data.get("amount") or parties_data.get("金额"))
    return ContractParties(
        party_a=text_or_none(parties_data.get("party_a") or parties_data.get("甲方")) or inferred.party_a,
        party_b=text_or_none(parties_data.get("party_b") or parties_data.get("乙方")) or inferred.party_b,
        amount=_prefer_amount(amount, inferred.amount),
        term=text_or_none(parties_data.get("term") or parties_data.get("期限")) or inferred.term,
        contract_type=text_or_none(parties_data.get("contract_type") or parties_data.get("合同类型")) or inferred.contract_type,
        jurisdiction=text_or_none(parties_data.get("jurisdiction") or parties_data.get("司法辖区")) or inferred.jurisdiction,
    )


def _infer_parties_from_text(text: str) -> ContractParties:
    if not text:
        return ContractParties()

    party_a = _first_match(text, r"甲方\s*[:：]?\s*([^，,。\n]{1,50}?)(?:将|与|向|为|同意|，|,|。|\n)")
    party_b = _first_match(text, r"乙方\s*[:：]?\s*([^，,。\n]{1,50}?)(?:将|与|向|为|同意|，|,|。|\n)")
    amount = _first_match(
        text,
        r"(?:租金|价款|金额|总价|合同金额)\s*(?:为|是|每月|共|总计|:|：)?\s*((?:每月)?\s*[0-9][0-9,，.]*\s*万?元)",
    )
    if amount and "租金每月" in text and not amount.startswith("每月"):
        amount = f"每月 {amount}"
    term = _first_match(text, r"(?:租期|期限|合同期限|履行期限)\s*(?:为|是|:|：)?\s*([^，,。；;\n]{1,30})")
    contract_type = None
    if "租" in text and ("房屋" in text or "房" in text):
        contract_type = "房屋租赁合同"
    elif "买卖" in text or "采购" in text:
        contract_type = "买卖合同"

    return ContractParties(
        party_a=party_a,
        party_b=party_b,
        amount=amount,
        term=term,
        contract_type=contract_type,
        jurisdiction=None,
    )


def _first_match(text: str, pattern: str) -> str | None:
    match = re.search(pattern, text)
    if not match:
        return None
    return text_or_none(match.group(1))


def _int_or_none(value: Any) -> int | None:
    if value is None or value == "":
        return None
    try:
        number = int(value)
    except (TypeError, ValueError):
        return None
    return number if number >= 0 else None


def _locate_offsets(source_text: str, excerpt: str | None) -> tuple[int | None, int | None]:
    if not source_text or not excerpt:
        return None, None
    index = source_text.find(excerpt)
    if index == -1:
        compact_excerpt = re.sub(r"\s+", "", excerpt)
        compact_source = re.sub(r"\s+", "", source_text)
        compact_index = compact_source.find(compact_excerpt)
        if compact_index == -1:
            return None, None
        return None, None
    return index, index + len(excerpt)


def _excerpt_from_offsets(source_text: str, start_offset: int, end_offset: int) -> str | None:
    if not source_text or start_offset < 0 or end_offset <= start_offset or start_offset >= len(source_text):
        return None
    return source_text[start_offset : min(end_offset, len(source_text))].strip() or None


def _derive_clause_title(text: str | None) -> str | None:
    if not text:
        return None
    match = re.search(r"(第[一二三四五六七八九十百0-9]+条[^，,。；;\n]{0,20})", text)
    if match:
        return match.group(1).strip()
    return None


def _prefer_amount(model_amount: str | None, inferred_amount: str | None) -> str | None:
    if inferred_amount and (not model_amount or not re.search(r"元|万元|人民币|美元|¥|\$", model_amount)):
        return inferred_amount
    return model_amount or inferred_amount
