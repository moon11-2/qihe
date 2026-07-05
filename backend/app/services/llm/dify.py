from app.services.llm.base import LLMProvider, LLMProviderError


class DifyProvider:
    async def chat(self, messages: list[dict[str, str]]) -> str:
        raise LLMProviderError("Dify provider is reserved for a later milestone")

    async def chat_json(self, messages: list[dict[str, str]], schema_name: str) -> dict:
        raise LLMProviderError("Dify provider is reserved for a later milestone")


def create_dify_provider() -> LLMProvider:
    return DifyProvider()
