import asyncio
import hashlib
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import create_app
from app.services import db
from app.services import auth as auth_service
from app.services.billing import activation
from app.services.billing.quota import CREDIT_COST_REVIEW, deduct_credits, get_balance
from app.services.files import storage
from app.services.jobs import store as job_store
from app.services.jobs.runner import execute_job


class FailingProvider:
    async def chat_json(self, messages: list[dict[str, str]], schema_name: str) -> dict:
        raise RuntimeError("force fallback")

    async def chat(self, messages: list[dict[str, str]]) -> str:
        raise RuntimeError("force fallback")


def _configure_isolated_backend(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(storage, "UPLOAD_DIR", tmp_path / "uploads")
    monkeypatch.setattr(settings, "db_path", str(tmp_path / "qihe.db"))
    monkeypatch.setattr(settings, "auth_db_path", "")
    monkeypatch.setattr(settings, "jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "jwt_expires_minutes", 60)


def _client(tmp_path: Path, monkeypatch) -> TestClient:
    _configure_isolated_backend(tmp_path, monkeypatch)
    return TestClient(create_app())


def _auth_headers(client: TestClient, email: str = "security@example.com") -> dict[str, str]:
    response = client.post(
        "/api/auth/register",
        json={
            "email": email,
            "password": "TestPassw0rd!",
            "display_name": "安全测试",
        },
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def _insert_user(email: str) -> int:
    db.init_schema()
    with db.connect() as conn:
        cursor = conn.execute(
            "INSERT INTO users (email, display_name, password_hash, created_at) VALUES (?, ?, ?, ?)",
            (email, "测试用户", "unused", "2026-07-09T00:00:00Z"),
        )
        conn.commit()
        return int(cursor.lastrowid)


def test_email_verification_code_is_hmac_verifiable_and_not_logged(
    tmp_path: Path,
    monkeypatch,
    capsys,
) -> None:
    _configure_isolated_backend(tmp_path, monkeypatch)
    monkeypatch.setattr(auth_service, "_generate_code", lambda: "123456")

    auth_service.send_verification_code("code-login@example.com", ip_address="127.0.0.1")

    captured = capsys.readouterr()
    assert "123456" not in captured.out
    assert "123456" not in captured.err
    with db.connect() as conn:
        row = conn.execute(
            "SELECT code_hash FROM email_verification_codes WHERE email = ?",
            ("code-login@example.com",),
        ).fetchone()
    assert row is not None
    assert str(row["code_hash"]).startswith("hmac_sha256$")
    assert "123456" not in str(row["code_hash"])

    user, token, expires_in = auth_service.verify_code_and_login("code-login@example.com", "123456")

    assert user.email == "code-login@example.com"
    assert token
    assert expires_in > 0


def test_email_verification_accepts_legacy_pbkdf2_hash(tmp_path: Path, monkeypatch) -> None:
    _configure_isolated_backend(tmp_path, monkeypatch)
    db.init_schema()
    salt = b"legacy-code-salt"
    digest = hashlib.pbkdf2_hmac("sha256", b"654321", salt, 100_000)
    legacy_hash = f"pbkdf2_sha256$100000${auth_service._b64_bytes(salt)}${auth_service._b64_bytes(digest)}"
    with db.connect() as conn:
        conn.execute(
            "INSERT INTO email_verification_codes (email, code_hash, expires_at, created_at) VALUES (?, ?, ?, ?)",
            ("legacy-code@example.com", legacy_hash, "2999-01-01T00:00:00Z", "2026-07-09T00:00:00Z"),
        )
        conn.commit()

    user, token, _expires_in = auth_service.verify_code_and_login("legacy-code@example.com", "654321")

    assert user.email == "legacy-code@example.com"
    assert token


def test_sync_contract_run_returns_error_when_post_success_deduct_fails(
    tmp_path: Path,
    monkeypatch,
) -> None:
    monkeypatch.setattr("app.api.contracts.check_balance", lambda _user_id, _cost: True)

    def fail_deduct(*_args, **_kwargs) -> int:
        raise ValueError("insufficient_credits")

    monkeypatch.setattr("app.api.contracts.deduct_credits", fail_deduct)
    client = _client(tmp_path, monkeypatch)
    headers = _auth_headers(client, "sync-deduct@example.com")

    response = client.post(
        "/api/contracts/run",
        headers=headers,
        json={"mode": "generate", "text": "生成一份服务合同"},
    )

    assert response.status_code == 402
    assert response.json()["error"]["code"] == "insufficient_credits"
    assert "generate_result" not in response.json()


def test_job_runner_uses_persisted_file_id_perspective_and_owner(
    tmp_path: Path,
    monkeypatch,
) -> None:
    _configure_isolated_backend(tmp_path, monkeypatch)
    monkeypatch.setattr("app.services.contracts.review.create_qwen_provider", lambda: FailingProvider())
    user_id = _insert_user("job-owner@example.com")
    file_id = "55555555-5555-4555-8555-555555555555"
    upload_path = storage.upload_path(file_id, ".txt")
    upload_path.write_text("甲方：甲公司\n乙方：乙公司\n付款应在验收后完成。", encoding="utf-8")
    storage.save_metadata(
        storage.StoredFile(
            file_id=file_id,
            filename="contract.txt",
            content_type="text/plain",
            suffix=".txt",
            path=str(upload_path),
            char_count=26,
            text_preview="甲方：甲公司",
            owner_user_id=user_id,
        )
    )

    job_store.create_job(
        job_id="job_file_owner",
        owner_user_id=user_id,
        mode="review",
        source_text="",
        file_id=file_id,
        review_perspective="party_a",
        metadata={"review_perspective": "party_b"},
    )
    queued = job_store.get_job("job_file_owner")
    assert queued is not None
    assert queued["file_id"] == file_id
    assert queued["review_perspective"] == "party_a"

    asyncio.run(execute_job("job_file_owner"))

    job = job_store.get_job("job_file_owner")
    assert job is not None
    assert job["status"] == "succeeded"
    assert job["result"]["source"]["file_id"] == file_id
    assert get_balance(user_id) == 10 - CREDIT_COST_REVIEW


def test_review_job_perspective_metadata_is_persisted(
    tmp_path: Path,
    monkeypatch,
) -> None:
    monkeypatch.setattr("app.services.contracts.review.create_qwen_provider", lambda: FailingProvider())
    client = _client(tmp_path, monkeypatch)
    headers = _auth_headers(client, "job-perspective@example.com")

    response = client.post(
        "/api/jobs/review-jobs",
        headers=headers,
        json={
            "mode": "review",
            "text": "甲方：甲公司\n乙方：乙公司\n付款应在验收后完成。",
            "metadata": {"review_perspective": "party_b"},
        },
    )

    assert response.status_code == 200
    job = job_store.get_job(response.json()["job_id"])
    assert job is not None
    assert job["review_perspective"] == "party_b"


def test_job_runner_marks_failed_when_deduct_fails_after_result(
    tmp_path: Path,
    monkeypatch,
) -> None:
    _configure_isolated_backend(tmp_path, monkeypatch)
    monkeypatch.setattr("app.services.contracts.review.create_qwen_provider", lambda: FailingProvider())
    user_id = _insert_user("job-no-balance@example.com")
    with db.connect() as conn:
        conn.execute(
            "INSERT INTO user_credits (user_id, balance, created_at, updated_at) VALUES (?, 0, ?, ?)",
            (user_id, "2026-07-09T00:00:00Z", "2026-07-09T00:00:00Z"),
        )
        conn.commit()
    job_store.create_job(
        job_id="job_no_balance",
        owner_user_id=user_id,
        mode="review",
        source_text="甲方：甲公司\n乙方：乙公司\n付款期限不清。",
    )

    asyncio.run(execute_job("job_no_balance"))

    job = job_store.get_job("job_no_balance")
    assert job is not None
    assert job["status"] == "failed"
    assert job["error"]["code"] == "insufficient_credits"
    assert "result" not in job


def test_deduct_credits_does_not_overdraw_balance(tmp_path: Path, monkeypatch) -> None:
    _configure_isolated_backend(tmp_path, monkeypatch)
    user_id = _insert_user("atomic-deduct@example.com")

    assert deduct_credits(user_id, 10, "test_full_spend") == 0
    with pytest.raises(ValueError, match="insufficient_credits"):
        deduct_credits(user_id, 1, "test_over_spend")

    assert get_balance(user_id) == 0


def test_storekit_transactions_fail_closed_without_apple_verification(
    tmp_path: Path,
    monkeypatch,
) -> None:
    client = _client(tmp_path, monkeypatch)
    headers = _auth_headers(client, "storekit@example.com")

    response = client.post(
        "/api/storekit/transactions",
        headers=headers,
        json={
            "transaction_id": "client-supplied-transaction",
            "product_id": "com.qihe.credits.small",
            "raw_payload": {"signed": False},
        },
    )

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "storekit_verification_not_configured"
    with db.connect() as conn:
        count = conn.execute("SELECT COUNT(*) FROM storekit_transactions").fetchone()[0]
    assert count == 0


def test_activation_code_redeem_is_not_double_credited(
    tmp_path: Path,
    monkeypatch,
) -> None:
    _configure_isolated_backend(tmp_path, monkeypatch)
    first_user_id = _insert_user("activation-one@example.com")
    second_user_id = _insert_user("activation-two@example.com")
    code = activation.generate_activation_code(credits=5)

    credits, balance = activation.redeem_code(code, first_user_id)
    assert credits == 5
    assert balance == 15
    with pytest.raises(ValueError, match="activation_code_already_redeemed"):
        activation.redeem_code(code, second_user_id)

    with db.connect() as conn:
        activation_transactions = conn.execute(
            "SELECT COUNT(*) FROM credit_transactions WHERE reason = 'activation_code'"
        ).fetchone()[0]
    assert activation_transactions == 1
