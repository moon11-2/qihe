from typing import Any

import httpx

from app.core.config import settings
from app.services.llm.base import LLMProvider, LLMProviderError, parse_json_object


class QwenProvider:
    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        model: str | None = None,
    ) -> None:
        self.api_key = api_key if api_key is not None else settings.qwen_api_key
        self.base_url = (base_url or settings.qwen_api_base_url).rstrip("/")
        self.model = model or settings.qwen_model

    async def chat(self, messages: list[dict[str, str]]) -> str:
        data = await self._create_completion(messages=messages)
        return _message_content(data)

    async def chat_json(self, messages: list[dict[str, str]], schema_name: str) -> dict:
        json_messages = [
            *messages,
            {
                "role": "system",
                "content": f"只返回一个 JSON object，schema 名称：{schema_name}。不要返回 Markdown。",
            },
        ]
        data = await self._create_completion(
            messages=json_messages,
            response_format={"type": "json_object"},
        )
        raw_content = _message_content(data)
        try:
            return parse_json_object(raw_content)
        except LLMProviderError:
            return await self._repair_json(raw_content, schema_name)

    async def _repair_json(self, raw_content: str, schema_name: str) -> dict[str, Any]:
        repair_messages = [
            {
                "role": "system",
                "content": (
                    "你是 JSON 修复器。只根据用户提供的原文修复为一个合法 JSON object，"
                    "不得新增事实，不得输出 Markdown，不得解释。"
                ),
            },
            {
                "role": "user",
                "content": f"schema 名称：{schema_name}\n需要修复的原文：\n{raw_content}",
            },
        ]
        data = await self._create_completion(
            messages=repair_messages,
            response_format={"type": "json_object"},
        )
        return parse_json_object(_message_content(data))

    async def _create_completion(
        self,
        messages: list[dict[str, str]],
        response_format: dict[str, str] | None = None,
    ) -> dict:
        if not self.api_key:
            raise LLMProviderError("QWEN_API_KEY is not configured")

        payload: dict = {
            "model": self.model,
            "messages": messages,
            "temperature": 0.2,
        }
        if response_format:
            payload["response_format"] = response_format

        async with httpx.AsyncClient(timeout=45) as client:
            try:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers={"Authorization": f"Bearer {self.api_key}"},
                    json=payload,
                )
                response.raise_for_status()
                return response.json()
            except httpx.HTTPError as exc:
                raise LLMProviderError("Qwen request failed") from exc


def _message_content(data: dict) -> str:
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise LLMProviderError("Unexpected Qwen response") from exc

    if not isinstance(content, str):
        raise LLMProviderError("Unexpected Qwen message content")
    return content.strip()


def create_qwen_provider() -> LLMProvider:
    return QwenProvider()
