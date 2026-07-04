from typing import Literal

from pydantic import BaseModel, Field


class ChatMessage(BaseModel):
    role: Literal["system", "user", "assistant"]
    content: str = Field(min_length=1)


class ChatRequest(BaseModel):
    messages: list[ChatMessage]


class ChatResponse(BaseModel):
    type: Literal["chat", "route", "need_input", "error"]
    intent: Literal["chat", "review", "generate", "unknown"]
    reply: str
    options: list[Literal["review", "generate"]] = []

