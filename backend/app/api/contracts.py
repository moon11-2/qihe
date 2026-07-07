from urllib.parse import quote

from fastapi import APIRouter, Depends, Response

from app.api.deps import require_current_user
from app.core.errors import api_error
from app.models.auth import AuthUser
from app.models.contracts import (
    ApplySuggestionRequest,
    ConfirmRevisionRequest,
    ContractExportRequest,
    ContractRevision,
    ContractRunRequest,
    ContractRunResponse,
    RevisionResponse,
)
from app.services.billing.quota import CREDIT_COST_GENERATE, CREDIT_COST_REVIEW, check_balance, deduct_credits
from app.services.contracts.export_word import export_contract_word
from app.services.contracts.generate import run_generate
from app.services.contracts.review import run_review
from app.services.contracts.revise import confirm_revision, create_revision

router = APIRouter(prefix="/api/contracts", tags=["contracts"], dependencies=[Depends(require_current_user)])


@router.post("/run", response_model=ContractRunResponse)
async def run_contract_task(
    request: ContractRunRequest,
    user: AuthUser = Depends(require_current_user),
) -> ContractRunResponse:
    # Pre-check credit balance
    cost = CREDIT_COST_REVIEW if request.mode == "review" else CREDIT_COST_GENERATE
    if not check_balance(user.id, cost):
        raise api_error(402, "insufficient_credits", f"积分不足，需要 {cost} 积分")

    try:
        if request.mode == "review":
            result = await run_review(request)
        else:
            result = await run_generate(request)
    except Exception:
        raise

    # Deduct credits on success
    try:
        deduct_credits(user.id, cost, f"contract_{request.mode}")
    except ValueError:
        pass  # Balance was already checked; safety net

    return ContractRunResponse(
        type="review_result" if request.mode == "review" else "generate_result",
        intent=request.mode,
        review_result=result if request.mode == "review" else None,
        generate_result=result if request.mode == "generate" else None,
    )


@router.post("/export/word")
async def export_word(request: ContractExportRequest) -> Response:
    content = export_contract_word(request)
    filename = f"{request.title or '契合导出'}.docx"
    encoded_filename = quote(filename)
    return Response(
        content=content,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={"Content-Disposition": f"attachment; filename*=UTF-8''{encoded_filename}"},
    )


@router.post("/apply-suggestion", response_model=RevisionResponse)
async def apply_suggestion(request: ApplySuggestionRequest) -> RevisionResponse:
    """Apply a suggested revision to a contract block."""
    revision = create_revision(
        block_id=request.block_id,
        before_text="",  # Client should provide before_text; fallback to empty
        after_text=request.after_text,
        risk_id=request.risk_id,
        source="user",
    )
    return RevisionResponse(
        revision_id=revision.revision_id,
        block_id=revision.block_id,
        before_text=revision.before_text,
        after_text=revision.after_text,
        source=revision.source,
        status=revision.status,
    )


@router.post("/revisions/{revision_id}/confirm", response_model=RevisionResponse)
async def confirm_revision_endpoint(
    revision_id: str,
    request_body: ConfirmRevisionRequest,
) -> RevisionResponse:
    """Confirm a draft revision."""
    # In MVP mode, create a temporary revision for confirmation
    # In production, this would fetch from DB
    revision = ContractRevision(
        revision_id=revision_id,
        block_id="",
        before_text="",
        after_text="",
        source="user",
        status="draft",
    )
    confirmed = confirm_revision(revision)
    return RevisionResponse(
        revision_id=confirmed.revision_id,
        block_id=confirmed.block_id,
        before_text=confirmed.before_text,
        after_text=confirmed.after_text,
        source=confirmed.source,
        status=confirmed.status,
    )
