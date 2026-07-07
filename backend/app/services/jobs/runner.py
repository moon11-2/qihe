"""Background job runner for async contract tasks."""

from __future__ import annotations

import asyncio
from typing import Any

from app.models.contracts import ContractRunRequest
from app.services.billing.quota import CREDIT_COST_GENERATE, CREDIT_COST_REVIEW, check_balance, deduct_credits
from app.services.contracts.generate import run_generate
from app.services.contracts.review import run_review
from app.services.jobs import store as job_store


async def execute_job(job_id: str) -> None:
    """Execute a contract job in the background."""
    job = job_store.get_job(job_id)
    if not job:
        return

    try:
        job_store.update_job_status(job_id, "running", progress=10, current_step="parsing")
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
            result = await run_review(request)
            result_dict = result.model_dump()
        else:
            result = await run_generate(request)
            result_dict = result.model_dump()

        job_store.update_job_step(job_id, "analyzing", "done")
        job_store.update_job_status(job_id, "running", progress=80, current_step="formatting")
        job_store.update_job_step(job_id, "formatting", "running")

        job_store.update_job_step(job_id, "formatting", "done")
        job_store.set_job_result(job_id, {"type": f"{job['mode']}_result", **result_dict})

        # Deduct credits on successful job completion (with job_id for idempotency)
        cost = CREDIT_COST_REVIEW if job["mode"] == "review" else CREDIT_COST_GENERATE
        try:
            deduct_credits(
                int(job["owner_user_id"]),
                cost,
                f"contract_{job['mode']}",
                job_id=job_id,
            )
        except ValueError:
            pass  # Already deducted or insufficient – non-fatal

    except Exception as exc:
        job_store.set_job_error(job_id, "job_execution_failed", str(exc))


def start_job_background(job_id: str) -> None:
    """Launch job execution as a background task."""
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(execute_job(job_id))
    except RuntimeError:
        asyncio.run(execute_job(job_id))
