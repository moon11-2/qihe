from app.services.llm.base import LLMProvider


class DifyProvider(LLMProvider):
    async def chat(self, messages: list[dict[str, str]]) -> str:
        raise NotImplementedError("Dify is reserved for a later generate provider.")

    async def chat_json(self, messages: list[dict[str, str]], schema_name: str) -> dict:
        raise NotImplementedError("Dify is reserved for a later generate provider.")

