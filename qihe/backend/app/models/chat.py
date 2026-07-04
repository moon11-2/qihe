from typing import Literal

from pydantic import BaseModel, Field


class ChatMessage(BaseModel):
    role: Literal["system", "user", "assistant"]
    content: str = Field(min_length=1)


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(default_factory=list)


class ChatResponse(BaseModel):
    type: Literal["chat", "route", "need_input"]
    intent: Literal["chat", "review", "generate", "unknown"]
    reply: str
    route: Literal["review", "generate"] | None = None
    need_input: list[str] = Field(default_factory=list)
    options: list[Literal["review", "generate"]] = Field(default_factory=list)
