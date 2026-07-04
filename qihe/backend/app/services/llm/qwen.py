from app.services.llm.base import LLMProvider


class QwenProvider(LLMProvider):
    async def chat(self, messages: list[dict[str, str]]) -> str:
        raise NotImplementedError("Qwen chat will be implemented in M1.")

    async def chat_json(self, messages: list[dict[str, str]], schema_name: str) -> dict:
        raise NotImplementedError("Qwen structured JSON will be implemented in M1.")

