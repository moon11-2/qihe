from typing import Any, Literal

from pydantic import BaseModel, Field

RiskLevel = Literal["高风险", "中风险", "低风险", "待确认"]


class ContractRunRequest(BaseModel):
    mode: Literal["review", "generate"]
    text: str | None = None
    file_id: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class ContractSource(BaseModel):
    text_preview: str
    file_id: str | None = None
    char_count: int


class ContractParties(BaseModel):
    party_a: str | None = None
    party_b: str | None = None
    amount: str | None = None
    term: str | None = None
    contract_type: str | None = None
    jurisdiction: str | None = None


class ClauseReview(BaseModel):
    risk_title: str
    risk_level: RiskLevel
    clause: str | None = None
    risk_analysis: str
    revision_suggestion: str
    suggested_replacement: str | None = None
    legal_basis: list[str] = Field(default_factory=list)


class ReviewResult(BaseModel):
    title: str
    summary: str
    review_basis: str
    risk_level: RiskLevel
    score: int | None
    risk_items: list[ClauseReview] = Field(default_factory=list)
    clause_reviews: list[ClauseReview] = Field(default_factory=list)
    parties: ContractParties = Field(default_factory=ContractParties)
    source: ContractSource


class GenerateResult(BaseModel):
    title: str
    draft: str
    missing_fields: list[str] = Field(default_factory=list)
    pre_sign_checklist: list[str] = Field(default_factory=list)
    notes: list[str] = Field(default_factory=list)
    source: ContractSource


class ContractRunResponse(BaseModel):
    type: Literal["review_result", "generate_result"]
    intent: Literal["review", "generate"]
    review_result: ReviewResult | None = None
    generate_result: GenerateResult | None = None


class ContractExportRequest(BaseModel):
    type: Literal["review", "generate", "review_result", "generate_result"]
    title: str
    payload: dict[str, Any]
