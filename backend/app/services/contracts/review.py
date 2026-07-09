import json
import re
from typing import Any

from app.models.contracts import ClauseReview, ContractBlock, ContractParties, ContractRunRequest, ContractSource, ReviewResult
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
from app.services.contracts.segmenter import find_block_for_offset, segment_text
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
FALLBACK_REVIEW_MESSAGE = "AI 输出暂时未能稳定解析，已根据合同文本提取重点核对项。"

FALLBACK_RULES = [
    {
        "id": "payment",
        "patterns": (r"付款|支付|价款|金额|总金额|合同金额|人民币|¥|￥|发票|结算",),
        "title": "付款金额与结算安排需核对",
        "level": "中风险",
        "analysis": "合同涉及金额、付款或结算信息，若付款节点、验收条件、发票要求或逾期后果不清，容易引发履行争议。",
        "suggestion": "明确总金额、付款节点、付款条件、发票类型、逾期付款责任以及与验收结果的关联。",
        "basis": ["民法典合同编关于价款、履行和违约责任的一般规则"],
    },
    {
        "id": "acceptance",
        "patterns": (r"验收|交付|交货|履行期限|服务期限|质量|标准|成果|完成|签收",),
        "title": "交付验收标准需明确",
        "level": "中风险",
        "analysis": "合同涉及交付、服务或验收内容，若验收标准、验收期限、整改流程或交付成果边界不清，可能影响付款和责任认定。",
        "suggestion": "补充交付清单、验收标准、验收期限、异议处理、整改次数和最终确认方式。",
        "basis": ["民法典合同编关于履行质量、履行期限和验收的一般规则"],
    },
    {
        "id": "breach",
        "patterns": (r"违约|赔偿|责任|罚金|违约金|滞纳金|解除|终止|不退|扣除|损失",),
        "title": "违约责任与解除条件需核对",
        "level": "中风险",
        "analysis": "合同出现违约责任、赔偿、解除或扣除安排，需要确认责任触发条件、责任上限和解除程序是否对等、清楚。",
        "suggestion": "明确违约情形、通知与补救期限、违约金计算方式、损失赔偿范围、解除条件和责任上限。",
        "basis": ["民法典合同编关于违约责任、合同解除和损害赔偿的一般规则"],
    },
    {
        "id": "dispute",
        "patterns": (r"争议|仲裁|诉讼|法院|管辖|法律适用|协商|纠纷",),
        "title": "争议解决条款需核对",
        "level": "低风险",
        "analysis": "合同涉及争议解决安排，应确认管辖机构、适用法律和争议处理路径是否明确且可执行。",
        "suggestion": "写明协商期限、管辖法院或仲裁机构、适用法律、送达地址及通知方式。",
        "basis": ["民事诉讼法及民法典合同编关于争议解决和通知送达的一般规则"],
    },
    {
        "id": "procurement",
        "patterns": (r"政府采购|采购法|采购合同|招标|投标|中标|供应商|采购人|财政",),
        "title": "政府采购合规要求需复核",
        "level": "中风险",
        "analysis": "文本涉及政府采购或招投标场景，需要复核合同内容是否与采购文件、中标结果、预算金额和法定采购程序保持一致。",
        "suggestion": "核对采购项目编号、采购文件、中标通知、服务范围、金额、履约验收、付款条件和变更审批流程。",
        "basis": ["政府采购法及其实施条例关于采购合同、履约验收和变更管理的一般要求"],
    },
    {
        "id": "confidentiality",
        "patterns": (r"保密|知识产权|著作权|数据|资料|商业秘密|隐私|个人信息",),
        "title": "保密与资料权属需核对",
        "level": "低风险",
        "analysis": "合同涉及资料、数据、知识产权或保密内容，应明确使用范围、权属归属、保密期限和泄露责任。",
        "suggestion": "补充资料交付、使用授权、成果权属、保密期限、例外情形和违约责任。",
        "basis": ["民法典合同编及知识产权、个人信息保护相关规则的一般要求"],
    },
]


async def run_review(
    request: ContractRunRequest,
    provider: LLMProvider | None = None,
    *,
    owner_user_id: int | None = None,
) -> ReviewResult:
    text, source = resolve_contract_input(request, owner_user_id=owner_user_id)
    if not text:
        return build_review_fallback(source, "未收到可审查的合同文本，请粘贴合同正文或上传可读取文件。")

    perspective = _resolve_perspective(request)
    review_metadata = pick_metadata(request.metadata, REVIEW_METADATA_KEYS)
    llm = provider or create_qwen_provider()
    messages = [
        {"role": "system", "content": load_prompt("review")},
        {
            "role": "user",
            "content": (
                "请审查以下合同文本，并按指定 JSON schema 输出。\n\n"
                f"{_perspective_instruction(perspective)}\n"
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

    # Segment source text into blocks
    blocks = segment_text(source_text)

    # Bind risks to blocks
    _bind_risks_to_blocks(clause_reviews, blocks)

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
        blocks=blocks,
    )


def build_review_fallback(source: ContractSource, message: str, source_text: str = "") -> ReviewResult:
    fallback_reviews = _build_fallback_clause_reviews(source_text, message)
    overall_level = _derive_overall_level(fallback_reviews)
    blocks = segment_text(source_text)
    _bind_risks_to_blocks(fallback_reviews, blocks)
    return ReviewResult(
        title="合同审查报告",
        summary=append_once(_fallback_summary(message, fallback_reviews, source_text), REVIEW_DISCLAIMER),
        review_basis=append_once("基于用户提供文本进行结构化处理；模型输出不稳定时已启用规则兜底审查。", REVIEW_DISCLAIMER),
        risk_level=overall_level,
        score=_fallback_score(overall_level, source_text),
        risk_items=fallback_reviews,
        clause_reviews=fallback_reviews,
        parties=_normalize_parties({}, source_text),
        source=source,
        blocks=blocks,
    )


def _build_fallback_clause_reviews(source_text: str, message: str) -> list[ClauseReview]:
    if not source_text.strip():
        return [_generic_fallback_review(source_text, message)]

    reviews: list[ClauseReview] = []
    for rule in FALLBACK_RULES:
        excerpt = _fallback_excerpt_for_patterns(source_text, rule["patterns"])
        if not excerpt:
            continue
        start_offset, end_offset = _locate_offsets(source_text, excerpt)
        reviews.append(
            ClauseReview(
                clause_id=f"fallback_{rule['id']}",
                clause_title=_derive_clause_title(excerpt) or str(rule["title"]),
                risk_title=str(rule["title"]),
                risk_level=rule["level"],  # type: ignore[arg-type]
                clause=excerpt,
                original_excerpt=excerpt,
                start_offset=start_offset,
                end_offset=end_offset,
                risk_analysis=f"规则兜底识别：{rule['analysis']}",
                revision_suggestion=str(rule["suggestion"]),
                suggested_replacement=None,
                legal_basis=list(rule["basis"]),
            )
        )
        if len(reviews) >= 4:
            break

    if reviews:
        return reviews

    return [_generic_fallback_review(source_text, message)]


def _generic_fallback_review(source_text: str, message: str) -> ClauseReview:
    original_excerpt = source_text[:180].strip() or None
    start_offset, end_offset = _locate_offsets(source_text, original_excerpt)
    return ClauseReview(
        clause_id="fallback_general",
        clause_title="合同关键条款需人工复核",
        risk_title="合同关键条款需人工复核",
        risk_level="待确认",
        clause=original_excerpt,
        original_excerpt=original_excerpt,
        start_offset=start_offset,
        end_offset=end_offset,
        risk_analysis=message,
        revision_suggestion="请重点核对主体、金额、期限、履行方式、违约责任和争议解决条款，必要时补充更完整文本后重新审查。",
        suggested_replacement=None,
        legal_basis=DEFAULT_LEGAL_BASIS,
    )


def _fallback_excerpt_for_patterns(source_text: str, patterns: tuple[str, ...]) -> str | None:
    for pattern in patterns:
        match = re.search(pattern, source_text, flags=re.IGNORECASE)
        if match:
            return _window_around_match(source_text, match.start(), match.end())
    return None


def _window_around_match(source_text: str, start: int, end: int) -> str:
    left_boundaries = [source_text.rfind(separator, 0, start) for separator in ("\n", "。", "；", ";")]
    left = max(left_boundaries)
    left = left + 1 if left >= 0 else max(0, start - 80)

    right_candidates = [
        index for separator in ("\n", "。", "；", ";") if (index := source_text.find(separator, end)) != -1
    ]
    right = min(right_candidates) + 1 if right_candidates else min(len(source_text), end + 180)

    excerpt = source_text[left:right].strip()
    if len(excerpt) < 18:
        excerpt = source_text[max(0, start - 80) : min(len(source_text), end + 180)].strip()
    return re.sub(r"\n{3,}", "\n\n", excerpt)[:260].strip()


def _fallback_summary(message: str, fallback_reviews: list[ClauseReview], source_text: str) -> str:
    if not source_text.strip():
        return message
    if fallback_reviews and fallback_reviews[0].clause_id != "fallback_general":
        return f"{FALLBACK_REVIEW_MESSAGE} 共识别 {len(fallback_reviews)} 项需要重点核对的合同风险。"
    return f"{message} 已保留原文并提取关键条款供继续复核。"


def _fallback_score(level: str, source_text: str) -> int | None:
    if not source_text.strip():
        return None
    if level == "高风险":
        return 58
    if level == "中风险":
        return 72
    if level == "低风险":
        return 86
    return None


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


def _resolve_perspective(request: ContractRunRequest) -> str:
    """Resolve review perspective from request, preferring top-level field over metadata."""
    if request.review_perspective:
        return request.review_perspective
    metadata_perspective = request.metadata.get("review_perspective")
    if metadata_perspective in ("party_a", "party_b", "neutral"):
        return str(metadata_perspective)
    return "neutral"


def _perspective_instruction(perspective: str) -> str:
    """Generate perspective-specific instruction for the review prompt."""
    if perspective == "party_a":
        return (
            "审查立场：请站在甲方利益角度识别风险并给出修改建议。"
            "重点关注条款是否对甲方不利、是否存在责任过重或权利受限的情况，"
            "修订建议应倾向于保护甲方权益。"
        )
    if perspective == "party_b":
        return (
            "审查立场：请站在乙方利益角度识别风险并给出修改建议。"
            "重点关注条款是否对乙方不利、是否存在责任过重或权利受限的情况，"
            "修订建议应倾向于保护乙方权益。"
        )
    return (
        "审查立场：请以中立立场进行审查，兼顾双方公平性，"
        "客观指出对任一方可能不利的条款并提出平衡的修改建议。"
    )


def _bind_risks_to_blocks(
    clause_reviews: list[ClauseReview],
    blocks: list["ContractBlock"],
) -> None:
    """Assign block_id to each clause review by matching offsets or excerpt text."""
    for review in clause_reviews:
        if review.block_id:
            continue
        # First try by offset
        if review.start_offset is not None:
            block = find_block_for_offset(blocks, review.start_offset)
            if block:
                review.block_id = block.block_id
                continue
        # Then try by excerpt text
        if review.original_excerpt and blocks:
            for block in blocks:
                if review.original_excerpt in block.text:
                    review.block_id = block.block_id
                    break
