"""Job API endpoints – async contract review/generate with progress tracking."""

from __future__ import annotations

from uuid import uuid4

from fastapi import APIRouter, Depends

from app.api.deps import require_current_user
from app.core.errors import api_error
from app.models.auth import AuthUser
from app.models.jobs import ContractJobRequest, ContractJobResponse, JobStep
from app.services.billing.quota import CREDIT_COST_GENERATE, CREDIT_COST_REVIEW, check_balance
from app.services.jobs import store as job_store
from app.services.jobs.runner import start_job_background

router = APIRouter(prefix="/api/jobs", tags=["jobs"], dependencies=[Depends(require_current_user)])


@router.post("/review-jobs", response_model=ContractJobResponse)
async def create_review_job(
    request: ContractJobRequest,
    user: AuthUser = Depends(require_current_user),
) -> ContractJobResponse:
    """Create an async review job."""
    return await _create_job("review", request, user.id)


@router.post("/generate-jobs", response_model=ContractJobResponse)
async def create_generate_job(
    request: ContractJobRequest,
    user: AuthUser = Depends(require_current_user),
) -> ContractJobResponse:
    """Create an async generate job."""
    return await _create_job("generate", request, user.id)


@router.get("/{job_id}", response_model=ContractJobResponse)
async def get_job_status(
    job_id: str,
    user: AuthUser = Depends(require_current_user),
) -> ContractJobResponse:
    """Get job status and result."""
    job = job_store.get_job(job_id)
    if not job:
        raise api_error(404, "job_not_found", "任务不存在")
    if job["owner_user_id"] != user.id:
        raise api_error(403, "forbidden", "无权访问该任务")

    return _job_to_response(job)


async def _create_job(
    mode: str,
    request: ContractJobRequest,
    owner_user_id: int,
) -> ContractJobResponse:
    """Shared job creation logic."""
    # Check credit balance before creating job
    cost = CREDIT_COST_REVIEW if mode == "review" else CREDIT_COST_GENERATE
    if not check_balance(owner_user_id, cost):
        raise api_error(402, "insufficient_credits", f"积分不足，需要 {cost} 积分")

    source_text = request.text or ""
    job_id = f"job_{uuid4().hex[:12]}"

    review_perspective = request.review_perspective
    if review_perspective is None and request.metadata.get("review_perspective") in {"party_a", "party_b", "neutral"}:
        review_perspective = str(request.metadata["review_perspective"])

    try:
        job_store.create_job(
            job_id=job_id,
            owner_user_id=owner_user_id,
            mode=mode,
            source_text=source_text,
            file_id=request.file_id,
            review_perspective=review_perspective,
            metadata=request.metadata,
        )
    except job_store.ActiveJobExistsError as exc:
        raise api_error(409, "job_in_progress", "已有正在执行的任务，请等待完成后再提交") from exc

    # Launch background execution
    start_job_background(job_id)

    job = job_store.get_job(job_id)
    return _job_to_response(job) if job else ContractJobResponse(
        job_id=job_id, status="queued", progress=0, steps=_default_steps(),
    )


def _job_to_response(job: dict) -> ContractJobResponse:
    steps = [
        JobStep(key=s["key"], title=s["title"], status=s["status"])
        for s in job.get("steps", [])
    ]
    return ContractJobResponse(
        job_id=job["job_id"],
        status=job["status"],
        progress=job["progress"],
        current_step=job.get("current_step"),
        steps=steps,
        result=job.get("result"),
        error=job.get("error"),
    )


def _default_steps() -> list[JobStep]:
    return [
        JobStep(key="parsing", title="解析合同文本", status="pending"),
        JobStep(key="analyzing", title="AI 分析中", status="pending"),
        JobStep(key="formatting", title="整理结果", status="pending"),
    ]
