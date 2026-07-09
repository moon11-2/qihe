from typing import Any, Literal

from pydantic import BaseModel, Field

RiskLevel = Literal["高风险", "中风险", "低风险", "待确认"]
ReviewPerspective = Literal["party_a", "party_b", "neutral"]


class ContractRunRequest(BaseModel):
    mode: Literal["review", "generate"]
    text: str | None = None
    file_id: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    review_perspective: ReviewPerspective | None = None


class ContractSource(BaseModel):
    text_preview: str
    file_id: str | None = None
    char_count: int


class DocumentSource(BaseModel):
    document_id: str | None = None
    file_id: str | None = None
    filename: str | None = None
    text_preview: str
    char_count: int


class ContractBlock(BaseModel):
    block_id: str
    order: int
    title: str | None = None
    text: str
    start_offset: int | None = None
    end_offset: int | None = None
    type: str = "general"


class ContractRevision(BaseModel):
    revision_id: str
    block_id: str
    risk_id: str | None = None
    before_text: str
    after_text: str
    source: Literal["user", "suggestion", "ai"] = "user"
    status: Literal["draft", "confirmed", "applied"] = "draft"


class ContractParties(BaseModel):
    party_a: str | None = None
    party_b: str | None = None
    amount: str | None = None
    term: str | None = None
    contract_type: str | None = None
    jurisdiction: str | None = None


class ClauseReview(BaseModel):
    clause_id: str | None = None
    clause_title: str | None = None
    risk_title: str
    risk_level: RiskLevel
    clause: str | None = None
    original_excerpt: str | None = None
    start_offset: int | None = None
    end_offset: int | None = None
    block_id: str | None = None
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
    blocks: list[ContractBlock] = Field(default_factory=list)
    revisions: list[ContractRevision] = Field(default_factory=list)


class GenerateResult(BaseModel):
    title: str
    draft: str
    missing_fields: list[str] = Field(default_factory=list)
    pre_sign_checklist: list[str] = Field(default_factory=list)
    notes: list[str] = Field(default_factory=list)
    source: ContractSource
    blocks: list[ContractBlock] = Field(default_factory=list)
    revisions: list[ContractRevision] = Field(default_factory=list)


class ContractRunResponse(BaseModel):
    type: Literal["review_result", "generate_result"]
    intent: Literal["review", "generate"]
    review_result: ReviewResult | None = None
    generate_result: GenerateResult | None = None


class ContractExportRequest(BaseModel):
    type: Literal["review", "generate", "review_result", "generate_result"]
    title: str
    payload: dict[str, Any]


class ApplySuggestionRequest(BaseModel):
    document_id: str | None = None
    block_id: str
    risk_id: str | None = None
    after_text: str


class ConfirmRevisionRequest(BaseModel):
    pass


class RevisionResponse(BaseModel):
    revision_id: str
    block_id: str
    before_text: str
    after_text: str
    source: Literal["user", "suggestion", "ai"]
    status: Literal["draft", "confirmed", "applied"]
