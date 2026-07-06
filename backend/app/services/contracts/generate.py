import json
import re
from typing import Any

from app.models.contracts import ContractRunRequest, ContractSource, GenerateResult
from app.services.contracts.common import (
    append_once,
    load_prompt,
    metadata_text,
    pick_metadata,
    resolve_contract_input,
    safe_output_text,
    safe_string_list,
    text_or_default,
)
from app.services.llm.base import LLMProvider
from app.services.llm.qwen import create_qwen_provider

GENERATE_DISCLAIMER = "AI 辅助起草，不构成法律意见。"
DEFAULT_CHECKLIST = [
    "核对双方主体名称、证照信息和签署授权",
    "核对金额、付款节点、发票和税费承担",
    "核对交付、验收、质量标准和期限",
    "核对违约责任、解除条件和通知方式",
    "核对争议解决方式、司法辖区和签署日期",
]
GENERATE_METADATA_LABELS = {
    "contract_type": "合同类型",
    "user_role": "用户角色",
    "my_identity": "我的身份",
    "special_terms": "特殊约定",
}
GENERATE_METADATA_KEYS = ("contract_type", "user_role", "my_identity", "special_terms")
INVALID_METADATA_VALUES = {"无", "null", "none", "None", "不确定", "未知", "未填写", "无特殊约定"}


async def run_generate(
    request: ContractRunRequest,
    provider: LLMProvider | None = None,
    *,
    owner_user_id: int | None = None,
) -> GenerateResult:
    text, source = resolve_contract_input(request, owner_user_id=owner_user_id)
    generate_metadata = pick_metadata(request.metadata, GENERATE_METADATA_KEYS)
    if not text:
        return build_generate_fallback(source, request=request, requirement_text=text)

    llm = provider or create_qwen_provider()
    messages = [
        {"role": "system", "content": load_prompt("generate")},
        {
            "role": "user",
            "content": (
                "请根据以下需求起草合同，并按指定 JSON schema 输出。\n\n"
                f"结构化起草条件 JSON：{json.dumps(generate_metadata, ensure_ascii=False)}\n"
                f"结构化起草条件说明：\n{metadata_text(generate_metadata, GENERATE_METADATA_LABELS) or '无'}\n\n"
                f"用户需求：\n{text}"
            ),
        },
    ]
    try:
        data = await llm.chat_json(messages, schema_name="contract_generate")
    except Exception:
        return build_generate_fallback(source, request=request, requirement_text=text)

    return normalize_generate_result(data, source, request=request, requirement_text=text)


def normalize_generate_result(
    data: dict[str, Any],
    source: ContractSource,
    request: ContractRunRequest | None = None,
    requirement_text: str = "",
) -> GenerateResult:
    notes = safe_string_list(data.get("notes"))
    if not any(GENERATE_DISCLAIMER in note for note in notes):
        notes.insert(0, GENERATE_DISCLAIMER)

    known_fields = _known_generate_fields(request.metadata if request else {}, requirement_text)
    missing_fields = _remove_known_missing_fields(safe_string_list(data.get("missing_fields")), known_fields)
    checklist = safe_string_list(data.get("pre_sign_checklist")) or DEFAULT_CHECKLIST
    checklist = _complete_checklist(checklist, known_fields)
    draft = text_or_default(safe_output_text(data.get("draft")), _fallback_draft(missing_fields))
    title = _complete_title(
        safe_output_text(text_or_default(data.get("title"), "合同草案")),
        known_fields,
    )
    notes = _complete_notes(notes, known_fields)

    return GenerateResult(
        title=title,
        draft=_complete_draft_with_known_fields(draft, known_fields),
        missing_fields=missing_fields,
        pre_sign_checklist=checklist,
        notes=notes,
        source=source,
    )


def build_generate_fallback(
    source: ContractSource,
    request: ContractRunRequest | None = None,
    requirement_text: str = "",
) -> GenerateResult:
    metadata = request.metadata if request else {}
    inferred = _infer_generate_fields(requirement_text)
    contract_type = _field(metadata, "contract_type", "合同类型") or inferred["contract_type"]
    party_a = _field(metadata, "party_a", "甲方", "甲方全称") or inferred["party_a"]
    party_b = _field(metadata, "party_b", "乙方", "乙方全称") or inferred["party_b"]
    amount = _field(metadata, "amount", "金额", "合同金额", "价款") or inferred["amount"]
    term = _field(metadata, "term", "期限", "履行期限") or inferred["term"]
    user_identity = _field(metadata, "my_identity", "我的身份")
    user_role = _field(metadata, "user_role", "用户角色")
    special_terms = _field(metadata, "special_terms", "特殊约定")
    key_terms = _field(metadata, "key_terms", "交付或服务内容", "服务内容") or special_terms or requirement_text
    jurisdiction = _field(metadata, "jurisdiction", "争议解决方式", "管辖") or inferred["jurisdiction"]

    missing_fields = _missing_fields(
        {
            "合同类型": contract_type,
            "甲方全称": party_a,
            "乙方全称": party_b,
            "合同金额": amount,
            "履行期限": term,
            "交付或服务内容": key_terms,
            "争议解决方式": jurisdiction,
        }
    )
    draft = _metadata_draft(
        contract_type=contract_type,
        party_a=party_a,
        party_b=party_b,
        amount=amount,
        term=term,
        key_terms=key_terms,
        user_identity=user_identity,
        special_terms=special_terms,
        jurisdiction=jurisdiction,
        missing_fields=missing_fields,
    )

    return GenerateResult(
        title=f"{contract_type or '合同'}草案",
        draft=draft,
        missing_fields=missing_fields,
        pre_sign_checklist=_complete_checklist(DEFAULT_CHECKLIST, {"用户身份": user_identity, "特殊约定": special_terms, "合同类型": contract_type}),
        notes=_complete_notes(
            [GENERATE_DISCLAIMER, "当前信息不足或 AI 输出未能稳定解析，已返回可继续补充的合同草案框架。"],
            {
                "用户身份": user_identity,
                "用户角色": user_role,
                "特殊约定": special_terms,
            },
        ),
        source=source,
    )


def _field(metadata: dict[str, Any], *keys: str) -> str:
    for key in keys:
        raw_value = metadata.get(key)
        if isinstance(raw_value, list):
            value = "；".join(str(item).strip() for item in raw_value if str(item).strip())
        else:
            value = str(raw_value or "").strip()
        if value and value not in INVALID_METADATA_VALUES and value.lower() not in INVALID_METADATA_VALUES:
            return value
    return ""


def _infer_contract_type(requirement_text: str) -> str:
    for candidate in ("买卖合同", "服务合同", "租赁合同", "劳动合同", "保密协议", "合作协议"):
        if candidate in requirement_text:
            return candidate
    if "租" in requirement_text:
        return "租赁合同"
    if "服务" in requirement_text:
        return "服务合同"
    if "采购" in requirement_text or "买卖" in requirement_text:
        return "买卖合同"
    return ""


def _infer_generate_fields(requirement_text: str) -> dict[str, str]:
    return {
        "contract_type": _infer_contract_type(requirement_text),
        "party_a": _first_match(requirement_text, r"甲方\s*[:：]?\s*([^，,。\n]{1,40}?)(?=乙方|金额|价款|期限|，|,|。|\n|$)"),
        "party_b": _first_match(requirement_text, r"乙方\s*[:：]?\s*([^，,。\n]{1,40}?)(?=甲方|金额|价款|期限|，|,|。|\n|$)"),
        "amount": _first_match(
            requirement_text,
            r"(?:金额|合同金额|总价|价款)\s*(?:为|是|:|：)?\s*((?:人民币)?\s*[0-9][0-9,，.]*\s*万?元)",
        ),
        "term": _first_match(requirement_text, r"(?:期限|履行期限)\s*(?:为|是|:|：)?\s*([^，,。；;\n]{1,30})"),
        "jurisdiction": _first_match(requirement_text, r"(?:争议解决|管辖)\s*(?:为|是|:|：)?\s*([^，,。；;\n]{1,40})"),
    }


def _known_generate_fields(metadata: dict[str, Any], requirement_text: str) -> dict[str, str]:
    inferred = _infer_generate_fields(requirement_text)
    return {
        "合同类型": _field(metadata, "contract_type", "合同类型") or inferred["contract_type"],
        "甲方全称": _field(metadata, "party_a", "甲方", "甲方全称") or inferred["party_a"],
        "乙方全称": _field(metadata, "party_b", "乙方", "乙方全称") or inferred["party_b"],
        "合同金额": _field(metadata, "amount", "金额", "合同金额", "价款") or inferred["amount"],
        "履行期限": _field(metadata, "term", "期限", "履行期限") or inferred["term"],
        "争议解决方式": _field(metadata, "jurisdiction", "争议解决方式", "管辖") or inferred["jurisdiction"],
        "用户身份": _field(metadata, "my_identity", "我的身份"),
        "用户角色": _field(metadata, "user_role", "用户角色"),
        "特殊约定": _field(metadata, "special_terms", "特殊约定"),
    }


def _remove_known_missing_fields(missing_fields: list[str], known_fields: dict[str, str]) -> list[str]:
    known_aliases = {
        "合同类型": ("合同类型",),
        "甲方全称": ("甲方", "甲方全称"),
        "乙方全称": ("乙方", "乙方全称"),
        "合同金额": ("金额", "合同金额", "价款"),
        "履行期限": ("期限", "履行期限"),
        "争议解决方式": ("争议解决", "争议解决方式", "管辖"),
        "特殊约定": ("特殊约定", "特别约定"),
    }
    filtered: list[str] = []
    for field in missing_fields:
        should_keep = True
        for label, aliases in known_aliases.items():
            if known_fields.get(label) and any(alias in field for alias in aliases):
                should_keep = False
                break
        if should_keep:
            filtered.append(field)
    return filtered


def _complete_draft_with_known_fields(draft: str, known_fields: dict[str, str]) -> str:
    replacements = {
        "甲方全称": ("【待补充：甲方全称】", "【待补充：甲方】"),
        "乙方全称": ("【待补充：乙方全称】", "【待补充：乙方】"),
        "合同金额": ("【待补充：合同金额】", "【待补充：金额】", "【待补充：价款】"),
        "履行期限": ("【待补充：履行期限】", "【待补充：期限】"),
        "争议解决方式": ("【待补充：争议解决方式】", "【待补充：管辖】"),
    }
    completed = draft
    for label, placeholders in replacements.items():
        value = known_fields.get(label)
        if not value:
            continue
        for placeholder in placeholders:
            completed = completed.replace(placeholder, value)

    confirmations = []
    for label, value in known_fields.items():
        if value and value not in completed:
            confirmations.append(f"{label}：{value}")
    if confirmations:
        completed = f"{completed.rstrip()}\n\n关键变量确认\n" + "\n".join(confirmations)
    return completed


def _complete_title(title: str, known_fields: dict[str, str]) -> str:
    contract_type = known_fields.get("合同类型")
    if contract_type and contract_type not in title and title in {"合同草案", "合同", "协议草案"}:
        return f"{contract_type}草案"
    return title


def _complete_notes(notes: list[str], known_fields: dict[str, str]) -> list[str]:
    completed = list(notes)
    user_identity = known_fields.get("用户身份")
    if user_identity and not any(user_identity in note for note in completed):
        completed.append(f"已按用户身份/立场关注：{user_identity}。")
    user_role = known_fields.get("用户角色")
    if user_role and not any(user_role in note for note in completed):
        completed.append(f"已按用户角色调整说明颗粒度：{user_role}。")
    special_terms = known_fields.get("特殊约定")
    if special_terms and not any(special_terms in note for note in completed):
        completed.append("已将特殊约定纳入草案或关键变量确认。")
    return completed


def _complete_checklist(checklist: list[str], known_fields: dict[str, str]) -> list[str]:
    completed = list(checklist)
    contract_type = known_fields.get("合同类型")
    if contract_type and not any(contract_type in item for item in completed):
        completed.append(f"核对{contract_type}的行业惯例、标的范围和履行条件")
    user_identity = known_fields.get("用户身份")
    if user_identity and not any(user_identity in item for item in completed):
        completed.append(f"从{user_identity}立场复核权利义务、违约责任和解除条件")
    special_terms = known_fields.get("特殊约定")
    if special_terms and not any("特殊约定" in item for item in completed):
        completed.append("逐条核对特殊约定的触发条件、履行期限和违约后果")
    return completed


def _first_match(text: str, pattern: str) -> str:
    match = re.search(pattern, text)
    if not match:
        return ""
    return match.group(1).strip()


def _missing_fields(fields: dict[str, str]) -> list[str]:
    return [label for label, value in fields.items() if not value]


def _metadata_draft(
    *,
    contract_type: str,
    party_a: str,
    party_b: str,
    amount: str,
    term: str,
    key_terms: str,
    user_identity: str,
    special_terms: str,
    jurisdiction: str,
    missing_fields: list[str],
) -> str:
    if not any((contract_type, party_a, party_b, amount, term, key_terms, user_identity, special_terms, jurisdiction)):
        return _fallback_draft(missing_fields)

    return append_once(
        "\n\n".join(
            part
            for part in [
                contract_type or "合同草案",
                f"甲方：{party_a or '【待补充：甲方全称】'}",
                f"乙方：{party_b or '【待补充：乙方全称】'}",
                f"起草关注：{user_identity}" if user_identity else "",
                "第一条 合同目的\n"
                f"双方就{key_terms or '【待补充：交付或服务内容】'}达成本合同。",
                f"第二条 特殊约定\n{special_terms}" if special_terms else "",
                "第三条 合同价款与支付\n"
                f"合同金额为{amount or '【待补充：合同金额】'}，付款方式和节点由双方另行确认。",
                "第四条 履行期限\n"
                f"履行期限为{term or '【待补充：履行期限】'}。",
                "第五条 交付与验收\n"
                "乙方应按照双方确认的范围、标准和期限完成交付，甲方应及时验收并反馈。",
                "第六条 违约责任\n"
                "任一方违反本合同约定，应继续履行、采取补救措施，并赔偿守约方合理损失。",
                "第七条 争议解决\n"
                f"因本合同产生的争议，双方应先友好协商；协商不成的，按{jurisdiction or '【待补充：争议解决方式】'}处理。",
                "第八条 签署\n本合同经双方授权代表签字或盖章后生效。",
            ]
            if part
        ).replace("\n\n\n", "\n\n"),
        GENERATE_DISCLAIMER,
    )


def _fallback_draft(missing_fields: list[str]) -> str:
    placeholder_lines = "\n".join(f"- 【待补充：{field}】" for field in missing_fields)
    return append_once(
        (
            "合同草案\n\n"
            "甲方：【待补充：甲方全称】\n"
            "乙方：【待补充：乙方全称】\n\n"
            "第一条 合同目的\n"
            "双方就【待补充：合同类型或交易事项】达成本合同。\n\n"
            "第二条 标的与内容\n"
            "乙方应按双方确认的范围提供【待补充：交付或服务内容】。\n\n"
            "第三条 价款与支付\n"
            "合同金额为【待补充：合同金额】，支付方式和节点为【待补充：付款安排】。\n\n"
            "第四条 履行期限\n"
            "履行期限为【待补充：履行期限】。\n\n"
            "第五条 违约责任\n"
            "任一方违反本合同约定，应承担相应违约责任；具体责任标准为【待补充：违约责任】。\n\n"
            "第六条 争议解决\n"
            "因本合同产生的争议，双方应先友好协商；协商不成的，按【待补充：争议解决方式】处理。\n\n"
            "第七条 签署\n"
            "本合同经双方授权代表签字或盖章后生效。\n\n"
            "待补充字段：\n"
            f"{placeholder_lines}"
        ),
        GENERATE_DISCLAIMER,
    )
