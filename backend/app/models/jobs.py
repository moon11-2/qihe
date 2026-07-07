"""Job models for async contract review/generate tasks."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class JobStep(BaseModel):
    key: str
    title: str
    status: Literal["pending", "running", "done", "failed"]


class ContractJobRequest(BaseModel):
    mode: Literal["review", "generate"]
    text: str | None = None
    file_id: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    review_perspective: Literal["party_a", "party_b", "neutral"] | None = None


class ContractJobResponse(BaseModel):
    job_id: str
    status: Literal["queued", "running", "succeeded", "failed"]
    progress: int = 0
    current_step: str | None = None
    steps: list[JobStep] = Field(default_factory=list)
    result: dict[str, Any] | None = None
    error: dict[str, str] | None = None
