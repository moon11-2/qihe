from functools import lru_cache
from pathlib import Path
from typing import Any

from app.models.contracts import ContractRunRequest, ContractSource, RiskLevel
from app.services.files.extractor import TextExtractionError, extract_text
from app.services.files.storage import find_upload, load_metadata

PROMPT_DIR = Path(__file__).resolve().parents[2] / "prompts"
RISK_LEVELS: set[RiskLevel] = {"高风险", "中风险", "低风险", "待确认"}
RISK_ALIASES = {
    "high": "高风险",
    "medium": "中风险",
    "low": "低风险",
    "unknown": "待确认",
    "pending": "待确认",
    "高": "高风险",
    "中": "中风险",
    "低": "低风险",
    "未知": "待确认",
    "需确认": "待确认",
}


@lru_cache
def load_prompt(name: str) -> str:
    return (PROMPT_DIR / f"{name}.md").read_text(encoding="utf-8")


def resolve_contract_input(request: ContractRunRequest) -> tuple[str, ContractSource]:
    text = (request.text or "").strip()
    if text:
        return text, ContractSource(
            text_preview=text[:240],
            file_id=request.file_id,
            char_count=len(text),
        )

    if request.file_id:
        metadata = load_metadata(request.file_id)
        path = find_upload(request.file_id)
        if path:
            try:
                text = extract_text(path)
            except TextExtractionError:
                text = ""
        return text, ContractSource(
            text_preview=(text or (metadata.text_preview if metadata else ""))[:240],
            file_id=request.file_id,
            char_count=len(text) if text else (metadata.char_count if metadata else 0),
        )

    return "", ContractSource(text_preview="", file_id=None, char_count=0)


def clean_metadata(metadata: dict[str, Any]) -> dict[str, Any]:
    cleaned: dict[str, Any] = {}
    for key, value in metadata.items():
        if value is None:
            continue
        if isinstance(value, str):
            text = value.strip()
            if text:
                cleaned[key] = text
            continue
        if isinstance(value, list):
            values = [str(item).strip() for item in value if str(item).strip()]
            if values:
                cleaned[key] = values
            continue
        if isinstance(value, dict):
            nested = clean_metadata(value)
            if nested:
                cleaned[key] = nested
            continue
        cleaned[key] = value
    return cleaned


def pick_metadata(metadata: dict[str, Any], keys: tuple[str, ...]) -> dict[str, Any]:
    cleaned = clean_metadata(metadata)
    return {key: cleaned[key] for key in keys if key in cleaned}


def metadata_text(metadata: dict[str, Any], labels: dict[str, str] | None = None) -> str:
    cleaned = clean_metadata(metadata)
    lines: list[str] = []
    for key, value in cleaned.items():
        label = labels.get(key, key) if labels else key
        if isinstance(value, list):
            rendered = "、".join(str(item) for item in value)
        else:
            rendered = str(value)
        lines.append(f"{label}: {rendered}")
    return "\n".join(lines)


def text_or_none(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if text in {"", "null", "None", "未识别", "无法识别", "无"}:
        return None
    return text


def text_or_default(value: Any, default: str) -> str:
    return text_or_none(value) or default


def string_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    if isinstance(value, str) and value.strip():
        return [value.strip()]
    return []


def risk_level(value: Any, default: RiskLevel = "待确认") -> RiskLevel:
    text = text_or_none(value)
    if text is None:
        return default
    if text in RISK_LEVELS:
        return text
    return RISK_ALIASES.get(text.lower(), default)  # type: ignore[return-value]


def bounded_score(value: Any) -> int | None:
    if value is None:
        return None
    try:
        score = int(value)
    except (TypeError, ValueError):
        return None
    return max(0, min(100, score))


def append_once(text: str, required_sentence: str) -> str:
    if required_sentence in text:
        return text
    if not text:
        return required_sentence
    return f"{text} {required_sentence}"


def safe_output_text(value: Any) -> str:
    text = str(value or "").strip()
    replacements = {
        "律师意见": "专业判断",
        "法律意见": "法律判断",
        "保证合规": "降低合规风险",
        "确保合规": "降低合规风险",
    }
    for source, replacement in replacements.items():
        text = text.replace(source, replacement)
    return text


def safe_string_list(value: Any) -> list[str]:
    return [safe_output_text(item) for item in string_list(value)]
