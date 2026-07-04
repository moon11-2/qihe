from typing import Protocol


class LLMProvider(Protocol):
    async def chat(self, messages: list[dict[str, str]]) -> str:
        ...

    async def chat_json(self, messages: list[dict[str, str]], schema_name: str) -> dict:
        ...

