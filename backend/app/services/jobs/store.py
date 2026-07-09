"""Job state persistence using the unified SQLite database."""

from __future__ import annotations

import json
from typing import Any

from app.services.db import connect


def create_job(
    job_id: str,
    owner_user_id: int,
    mode: str,
    source_text: str,
    file_id: str | None = None,
    review_perspective: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> None:
    """Insert a new job row."""
    now = _now_iso()
    steps_json = json.dumps(_default_steps(), ensure_ascii=False)
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO jobs (job_id, owner_user_id, mode, status, progress,
                              current_step, steps_json, source_text, file_id,
                              review_perspective, metadata_json,
                              created_at, updated_at)
            VALUES (?, ?, ?, 'queued', 0, NULL, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                job_id,
                owner_user_id,
                mode,
                steps_json,
                source_text,
                file_id,
                review_perspective,
                json.dumps(metadata or {}, ensure_ascii=False),
                now,
                now,
            ),
        )
        conn.commit()


def update_job_status(
    job_id: str,
    status: str,
    progress: int = 0,
    current_step: str | None = None,
) -> None:
    """Update job status and progress."""
    now = _now_iso()
    with connect() as conn:
        conn.execute(
            "UPDATE jobs SET status = ?, progress = ?, current_step = ?, updated_at = ? WHERE job_id = ?",
            (status, progress, current_step, now, job_id),
        )
        conn.commit()


def update_job_step(job_id: str, step_key: str, step_status: str) -> None:
    """Update a single step within a job."""
    with connect() as conn:
        row = conn.execute("SELECT steps_json FROM jobs WHERE job_id = ?", (job_id,)).fetchone()
        if not row:
            return
        steps = json.loads(row["steps_json"])
        for step in steps:
            if step["key"] == step_key:
                step["status"] = step_status
                break
        conn.execute(
            "UPDATE jobs SET steps_json = ?, updated_at = ? WHERE job_id = ?",
            (json.dumps(steps, ensure_ascii=False), _now_iso(), job_id),
        )
        conn.commit()


def set_job_result(job_id: str, result: dict[str, Any]) -> None:
    """Set the successful result for a job."""
    with connect() as conn:
        conn.execute(
            "UPDATE jobs SET result_json = ?, status = 'succeeded', progress = 100, updated_at = ? WHERE job_id = ?",
            (json.dumps(result, ensure_ascii=False), _now_iso(), job_id),
        )
        conn.commit()


def set_job_error(job_id: str, error_code: str, error_message: str) -> None:
    """Set error info for a failed job."""
    with connect() as conn:
        conn.execute(
            "UPDATE jobs SET error_code = ?, error_message = ?, status = 'failed', updated_at = ? WHERE job_id = ?",
            (error_code, error_message, _now_iso(), job_id),
        )
        conn.commit()


def get_job(job_id: str) -> dict[str, Any] | None:
    """Fetch a job by ID."""
    with connect() as conn:
        row = conn.execute("SELECT * FROM jobs WHERE job_id = ?", (job_id,)).fetchone()
        if not row:
            return None
        return _row_to_dict(row)


def get_running_job_for_user(owner_user_id: int) -> str | None:
    """Return job_id if user already has a running job, else None."""
    with connect() as conn:
        row = conn.execute(
            "SELECT job_id FROM jobs WHERE owner_user_id = ? AND status IN ('queued', 'running') LIMIT 1",
            (owner_user_id,),
        ).fetchone()
        return str(row["job_id"]) if row else None


def get_jobs_for_user(owner_user_id: int) -> list[dict[str, Any]]:
    """List all jobs for a user."""
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM jobs WHERE owner_user_id = ? ORDER BY created_at DESC LIMIT 50",
            (owner_user_id,),
        ).fetchall()
        return [_row_to_dict(row) for row in rows]


def _row_to_dict(row: Any) -> dict[str, Any]:
    metadata = json.loads(row["metadata_json"]) if row["metadata_json"] else {}
    result = {
        "job_id": row["job_id"],
        "owner_user_id": row["owner_user_id"],
        "mode": row["mode"],
        "status": row["status"],
        "progress": row["progress"],
        "current_step": row["current_step"],
        "steps": json.loads(row["steps_json"]) if row["steps_json"] else [],
        "source_text": row["source_text"],
        "file_id": row["file_id"],
        "review_perspective": row["review_perspective"] or metadata.get("review_perspective"),
        "metadata": metadata,
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }
    if row["result_json"]:
        result["result"] = json.loads(row["result_json"])
    if row["error_code"]:
        result["error"] = {"code": row["error_code"], "message": row["error_message"] or ""}
    return result


def _default_steps() -> list[dict[str, str]]:
    return [
        {"key": "parsing", "title": "解析合同文本", "status": "pending"},
        {"key": "analyzing", "title": "AI 分析中", "status": "pending"},
        {"key": "formatting", "title": "整理结果", "status": "pending"},
    ]


def _now_iso() -> str:
    import time
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
