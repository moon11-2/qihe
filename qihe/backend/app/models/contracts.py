from typing import Any, Literal

from pydantic import BaseModel, Field


class ContractRunRequest(BaseModel):
    mode: Literal["review", "generate"]
    text: str | None = None
    file_id: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class ContractRunResponse(BaseModel):
    type: Literal["review_result", "generate_result"]
    intent: Literal["review", "generate"]
    result: dict[str, Any]


class ContractExportRequest(BaseModel):
    type: Literal["review", "generate"]
    title: str
    payload: dict[str, Any]

