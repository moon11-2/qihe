import asyncio
from concurrent.futures import ThreadPoolExecutor
import sqlite3
from pathlib import Path
from threading import Barrier

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import create_app
from app.models.contracts import ContractBlock, ContractSource, GenerateResult
from app.services import db
from app.services.billing.quota import CREDIT_COST_GENERATE, deduct_credits, get_balance
from app.services.files import storage
from app.services.jobs import store as job_store
from app.services.jobs.runner import execute_job


def _client(tmp_path: Path, monkeypatch) -> TestClient:
    monkeypatch.setattr(storage, "UPLOAD_DIR", tmp_path / "uploads")
    monkeypatch.setattr(settings, "db_path", str(tmp_path / "qihe.db"))
    monkeypatch.setattr(settings, "auth_db_path", "")
    monkeypatch.setattr(settings, "jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "jwt_expires_minutes", 60)
    return TestClient(create_app())


def _auth_headers(client: TestClient, email: str) -> dict[str, str]:
    response = client.post(
        "/api/auth/register",
        json={
            "email": email,
            "password": "TestPassw0rd!",
            "display_name": "任务测试用户",
        },
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.mark.parametrize(
    ("method", "path", "payload"),
    [
        (
            "post",
            "/api/jobs/review-jobs",
            {"mode": "review", "text": "检查合同风险"},
        ),
        (
            "post",
            "/api/jobs/generate-jobs",
            {"mode": "generate", "text": "生成一份服务合同"},
        ),
        ("get", "/api/jobs/job_missing", None),
    ],
)
def test_jobs_routes_require_login_instead_of_returning_not_found(
    tmp_path: Path,
    monkeypatch,
    method: str,
    path: str,
    payload: dict[str, str] | None,
) -> None:
    client = _client(tmp_path, monkeypatch)

    response = client.request(method, path, json=payload)

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "auth_required"


def test_logged_in_user_can_create_and_poll_succeeded_job(
    tmp_path: Path,
    monkeypatch,
) -> None:
    client = _client(tmp_path, monkeypatch)
    owner_headers = _auth_headers(client, "job-success@example.com")
    queued_job_ids: list[str] = []
    generate_calls: list[str] = []
    monkeypatch.setattr(
        "app.api.jobs.start_job_background",
        lambda job_id: queued_job_ids.append(job_id),
    )

    async def successful_generate(*_args, **_kwargs) -> GenerateResult:
        generate_calls.append("called")
        await asyncio.sleep(0)
        source_text = "生成一份服务合同"
        return GenerateResult(
            title="服务合同草案",
            draft="服务合同\n甲方与乙方经协商订立本合同。",
            missing_fields=[],
            pre_sign_checklist=["核对双方主体信息"],
            notes=["AI 辅助起草，不构成法律意见。"],
            source=ContractSource(
                text_preview=source_text,
                char_count=len(source_text),
            ),
            blocks=[
                ContractBlock(
                    block_id="block_1",
                    order=0,
                    title="服务合同",
                    text="甲方与乙方经协商订立本合同。",
                )
            ],
        )

    monkeypatch.setattr("app.services.jobs.runner.run_generate", successful_generate)

    create_response = client.post(
        "/api/jobs/generate-jobs",
        headers=owner_headers,
        json={"mode": "generate", "text": "生成一份服务合同"},
    )

    assert create_response.status_code == 200
    created = create_response.json()
    assert created["status"] == "queued"
    assert created["job_id"].startswith("job_")
    assert queued_job_ids == [created["job_id"]]

    async def execute_twice() -> None:
        await asyncio.gather(execute_job(created["job_id"]), execute_job(created["job_id"]))

    asyncio.run(execute_twice())
    asyncio.run(execute_job(created["job_id"]))

    poll_response = client.get(
        f"/api/jobs/{created['job_id']}",
        headers=owner_headers,
    )
    assert poll_response.status_code == 200
    completed = poll_response.json()
    assert completed["status"] == "succeeded"
    assert completed["progress"] == 100
    assert all(step["status"] == "done" for step in completed["steps"])
    assert completed["error"] is None
    assert completed["result"]["type"] == "generate_result"
    assert completed["result"]["title"] == "服务合同草案"
    assert completed["result"]["source"]["text_preview"] == "生成一份服务合同"
    assert completed["result"]["blocks"][0]["block_id"] == "block_1"
    assert generate_calls == ["called"]

    with db.connect() as conn:
        user_id = int(
            conn.execute("SELECT id FROM users WHERE email = ?", ("job-success@example.com",)).fetchone()["id"]
        )
        deductions = conn.execute(
            "SELECT COUNT(*) FROM credit_transactions WHERE job_id = ? AND amount < 0",
            (created["job_id"],),
        ).fetchone()[0]
    assert deductions == 1
    assert get_balance(user_id) == 10 - CREDIT_COST_GENERATE


def test_job_status_is_isolated_between_users(tmp_path: Path, monkeypatch) -> None:
    client = _client(tmp_path, monkeypatch)
    owner_headers = _auth_headers(client, "job-owner@example.com")
    other_headers = _auth_headers(client, "job-other@example.com")
    monkeypatch.setattr("app.api.jobs.start_job_background", lambda _job_id: None)

    create_response = client.post(
        "/api/jobs/review-jobs",
        headers=owner_headers,
        json={"mode": "review", "text": "审查这份合同"},
    )
    assert create_response.status_code == 200
    job_id = create_response.json()["job_id"]

    response = client.get(f"/api/jobs/{job_id}", headers=other_headers)

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "forbidden"


def test_logged_in_user_can_poll_failed_job_without_exposing_exception(
    tmp_path: Path,
    monkeypatch,
    caplog,
) -> None:
    client = _client(tmp_path, monkeypatch)
    owner_headers = _auth_headers(client, "job-failure@example.com")
    monkeypatch.setattr("app.api.jobs.start_job_background", lambda _job_id: None)

    async def failed_review(*_args, **_kwargs):
        raise RuntimeError("controlled review failure secret-token-value")

    monkeypatch.setattr("app.services.jobs.runner.run_review", failed_review)

    create_response = client.post(
        "/api/jobs/review-jobs",
        headers=owner_headers,
        json={"mode": "review", "text": "审查这份合同"},
    )
    assert create_response.status_code == 200
    job_id = create_response.json()["job_id"]

    asyncio.run(execute_job(job_id))

    poll_response = client.get(f"/api/jobs/{job_id}", headers=owner_headers)
    assert poll_response.status_code == 200
    failed = poll_response.json()
    assert failed["status"] == "failed"
    assert failed["result"] is None
    assert failed["error"] == {
        "code": "job_execution_failed",
        "message": "任务处理失败，请稍后重试",
    }
    stored = job_store.get_job(job_id)
    assert stored is not None
    assert "secret-token-value" not in str(stored)
    assert "secret-token-value" not in caplog.text


def test_deduct_credits_is_idempotent_for_job_id(tmp_path: Path, monkeypatch) -> None:
    client = _client(tmp_path, monkeypatch)
    _auth_headers(client, "deduct-idempotent@example.com")
    with db.connect() as conn:
        user_id = int(
            conn.execute("SELECT id FROM users WHERE email = ?", ("deduct-idempotent@example.com",)).fetchone()["id"]
        )

    first_balance = deduct_credits(user_id, 3, "contract_generate", job_id="job_idempotent")
    second_balance = deduct_credits(user_id, 3, "contract_generate", job_id="job_idempotent")

    assert first_balance == 7
    assert second_balance == 7
    with db.connect() as conn:
        rows = conn.execute(
            "SELECT amount FROM credit_transactions WHERE job_id = ?",
            ("job_idempotent",),
        ).fetchall()
    assert [int(row["amount"]) for row in rows] == [-3]


def test_job_creation_check_and_insert_are_atomic(tmp_path: Path, monkeypatch) -> None:
    client = _client(tmp_path, monkeypatch)
    _auth_headers(client, "atomic-job@example.com")
    with db.connect() as conn:
        user_id = int(
            conn.execute("SELECT id FROM users WHERE email = ?", ("atomic-job@example.com",)).fetchone()["id"]
        )

    barrier = Barrier(2)

    def create(job_id: str) -> str:
        barrier.wait()
        try:
            job_store.create_job(job_id, user_id, "review", "审查合同")
        except job_store.ActiveJobExistsError:
            return "rejected"
        return "created"

    with ThreadPoolExecutor(max_workers=2) as executor:
        outcomes = list(executor.map(create, ("job_atomic_1", "job_atomic_2")))

    assert sorted(outcomes) == ["created", "rejected"]
    with db.connect() as conn:
        active_jobs = conn.execute(
            "SELECT COUNT(*) FROM jobs WHERE owner_user_id = ? AND status IN ('queued', 'running')",
            (user_id,),
        ).fetchone()[0]
    assert active_jobs == 1


def test_job_api_reports_conflict_for_existing_active_job(tmp_path: Path, monkeypatch) -> None:
    client = _client(tmp_path, monkeypatch)
    headers = _auth_headers(client, "job-conflict@example.com")
    monkeypatch.setattr("app.api.jobs.start_job_background", lambda _job_id: None)

    first = client.post(
        "/api/jobs/review-jobs",
        headers=headers,
        json={"mode": "review", "text": "审查这份合同"},
    )
    second = client.post(
        "/api/jobs/generate-jobs",
        headers=headers,
        json={"mode": "generate", "text": "生成一份合同"},
    )

    assert first.status_code == 200
    assert second.status_code == 409
    assert second.json()["error"]["code"] == "job_in_progress"


def test_schema_migrates_legacy_duplicate_job_deductions(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(settings, "db_path", str(tmp_path / "legacy.db"))
    monkeypatch.setattr(settings, "auth_db_path", "")
    db.init_schema()
    with db.connect() as conn:
        conn.execute("DROP INDEX uq_credit_transactions_deduction_job")
        conn.execute(
            "INSERT INTO users (email, display_name, password_hash, created_at) VALUES (?, ?, ?, ?)",
            ("legacy-ledger@example.com", "旧库用户", "unused", "2026-07-09T00:00:00Z"),
        )
        user_id = int(conn.execute("SELECT last_insert_rowid()").fetchone()[0])
        for _ in range(2):
            conn.execute(
                """
                INSERT INTO credit_transactions (user_id, amount, reason, job_id, created_at)
                VALUES (?, -2, 'contract_review', 'job_legacy_duplicate', '2026-07-09T00:00:00Z')
                """,
                (user_id,),
            )

    db.init_schema()

    with db.connect() as conn:
        ledger = conn.execute(
            "SELECT amount, job_id FROM credit_transactions WHERE user_id = ? ORDER BY id",
            (user_id,),
        ).fetchall()
        assert [int(row["amount"]) for row in ledger] == [-2, -2]
        assert sum(row["job_id"] == "job_legacy_duplicate" for row in ledger) == 1
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                """
                INSERT INTO credit_transactions (user_id, amount, reason, job_id, created_at)
                VALUES (?, -2, 'contract_review', 'job_legacy_duplicate', '2026-07-09T00:00:00Z')
                """,
                (user_id,),
            )


def test_schema_and_read_path_sanitize_legacy_job_errors(tmp_path: Path, monkeypatch) -> None:
    client = _client(tmp_path, monkeypatch)
    _auth_headers(client, "legacy-error@example.com")
    with db.connect() as conn:
        user_id = int(
            conn.execute("SELECT id FROM users WHERE email = ?", ("legacy-error@example.com",)).fetchone()["id"]
        )
        conn.execute(
            """
            INSERT INTO jobs (
                job_id, owner_user_id, mode, status, progress, steps_json, source_text,
                metadata_json, error_code, error_message, created_at, updated_at
            ) VALUES (
                'job_legacy_error', ?, 'review', 'failed', 20, '[]', '', '{}',
                'job_execution_failed', 'raw secret from legacy exception',
                '2026-07-09T00:00:00Z', '2026-07-09T00:00:00Z'
            )
            """,
            (user_id,),
        )

    before_migration = job_store.get_job("job_legacy_error")
    assert before_migration is not None
    assert before_migration["error"]["message"] == "任务处理失败，请稍后重试"

    db.init_schema()
    with db.connect() as conn:
        stored_message = conn.execute(
            "SELECT error_message FROM jobs WHERE job_id = 'job_legacy_error'"
        ).fetchone()["error_message"]
    assert stored_message == "任务处理失败，请稍后重试"
