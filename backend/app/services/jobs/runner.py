"""Background job runner for async contract tasks."""

from __future__ import annotations

import asyncio
import hashlib
import logging

from app.models.contracts import ContractRunRequest
from app.services.billing.quota import CREDIT_COST_GENERATE, CREDIT_COST_REVIEW, deduct_credits
from app.services.contracts.generate import run_generate
from app.services.contracts.review import run_review
from app.services.jobs import store as job_store


logger = logging.getLogger(__name__)


async def execute_job(job_id: str) -> None:
    """Execute a contract job in the background."""
    job = job_store.claim_queued_job(job_id)
    if not job:
        return

    try:
        owner_user_id = int(job["owner_user_id"])
        job_store.update_job_step(job_id, "parsing", "running")

        # Build request from job data
        request = ContractRunRequest(
            mode=job["mode"],
            text=job.get("source_text"),
            file_id=job.get("file_id"),
            metadata=job.get("metadata", {}),
            review_perspective=job.get("review_perspective"),
        )

        job_store.update_job_step(job_id, "parsing", "done")
        job_store.update_job_status(job_id, "running", progress=30, current_step="analyzing")
        job_store.update_job_step(job_id, "analyzing", "running")

        # Execute the appropriate contract task
        if job["mode"] == "review":
            result = await run_review(request, owner_user_id=owner_user_id)
            result_dict = result.model_dump()
        else:
            result = await run_generate(request, owner_user_id=owner_user_id)
            result_dict = result.model_dump()

        job_store.update_job_step(job_id, "analyzing", "done")
        job_store.update_job_status(job_id, "running", progress=80, current_step="formatting")
        job_store.update_job_step(job_id, "formatting", "running")

        job_store.update_job_step(job_id, "formatting", "done")

        # Deduct credits on successful job completion (with job_id for idempotency)
        cost = CREDIT_COST_REVIEW if job["mode"] == "review" else CREDIT_COST_GENERATE
        try:
            deduct_credits(
                owner_user_id,
                cost,
                f"contract_{job['mode']}",
                job_id=job_id,
            )
        except ValueError as exc:
            code = "insufficient_credits" if str(exc) == "insufficient_credits" else "credit_deduction_failed"
            logger.warning(
                "job credit deduction failed [job_ref=%s error_code=%s]",
                _job_log_ref(job_id),
                code,
            )
            job_store.set_job_error(job_id, code)
            return

        job_store.set_job_result(job_id, {"type": f"{job['mode']}_result", **result_dict})

    except Exception as exc:
        logger.error(
            "job execution failed [job_ref=%s exception_type=%s]",
            _job_log_ref(job_id),
            type(exc).__name__,
        )
        job_store.set_job_error(job_id, "job_execution_failed")


def start_job_background(job_id: str) -> None:
    """Launch job execution as a background task."""
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(execute_job(job_id))
    except RuntimeError:
        asyncio.run(execute_job(job_id))


def _job_log_ref(job_id: str) -> str:
    return hashlib.sha256(job_id.encode("utf-8", errors="replace")).hexdigest()[:12]
