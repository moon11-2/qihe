import json
from typing import Any, Protocol


class LLMProvider(Protocol):
    async def chat(self, messages: list[dict[str, str]]) -> str:
        ...

    async def chat_json(self, messages: list[dict[str, str]], schema_name: str) -> dict:
        ...


class LLMProviderError(Exception):
    pass


def parse_json_object(raw_text: str) -> dict[str, Any]:
    cleaned = _strip_markdown_fence(raw_text.strip())
    try:
        parsed = json.loads(cleaned)
    except json.JSONDecodeError as exc:
        json_text = _extract_first_json_object(cleaned)
        if json_text is None:
            raise LLMProviderError("LLM did not return JSON") from exc
        parsed = json.loads(json_text)

    if not isinstance(parsed, dict):
        raise LLMProviderError("LLM JSON response must be an object")
    return parsed


def _strip_markdown_fence(text: str) -> str:
    if not text.startswith("```"):
        return text

    lines = text.splitlines()
    if len(lines) >= 2 and lines[-1].strip() == "```":
        return "\n".join(lines[1:-1]).strip()
    return text


def _extract_first_json_object(text: str) -> str | None:
    start = text.find("{")
    if start == -1:
        return None

    depth = 0
    in_string = False
    escaped = False
    for index, char in enumerate(text[start:], start=start):
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue

        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[start : index + 1]

    return None
