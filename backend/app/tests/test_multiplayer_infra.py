import json
from datetime import UTC, datetime, timedelta
from pathlib import Path

from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import create_app
from app.services import db
from app.services.files import storage
from app.services.files.cleanup import cleanup_expired_uploads


class FailingProvider:
    async def chat_json(self, messages: list[dict[str, str]], schema_name: str) -> dict:
        raise RuntimeError("force review fallback")

    async def chat(self, messages: list[dict[str, str]]) -> str:
        raise RuntimeError("force chat fallback")


def _client(tmp_path: Path, monkeypatch) -> TestClient:
    monkeypatch.setattr(storage, "UPLOAD_DIR", tmp_path / "uploads")
    monkeypatch.setattr(settings, "db_path", str(tmp_path / "qihe.db"))
    monkeypatch.setattr(settings, "auth_db_path", "")
    monkeypatch.setattr(settings, "jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "jwt_expires_minutes", 60)
    return TestClient(create_app())


def _register(client: TestClient, email: str) -> tuple[dict[str, str], int]:
    response = client.post(
        "/api/auth/register",
        json={
            "email": email,
            "password": "TestPassw0rd!",
            "display_name": "测试用户",
        },
    )
    assert response.status_code == 200
    payload = response.json()
    return {"Authorization": f"Bearer {payload['access_token']}"}, int(payload["user"]["id"])


def _parse_iso(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def test_db_path_can_be_monkeypatched_and_sqlite_pragmas_are_enabled(tmp_path: Path, monkeypatch) -> None:
    db_path = tmp_path / "nested" / "qihe.db"
    monkeypatch.setattr(settings, "db_path", str(db_path))
    monkeypatch.setattr(settings, "auth_db_path", "")

    db.init_schema()

    assert db_path.exists()
    with db.connect() as conn:
        assert conn.execute("PRAGMA foreign_keys").fetchone()[0] == 1
        assert conn.execute("PRAGMA journal_mode").fetchone()[0].lower() == "wal"
        users_table = conn.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'users'"
        ).fetchone()
    assert users_table is not None


def test_old_stored_file_metadata_defaults_new_fields_and_remains_readable(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(storage, "UPLOAD_DIR", tmp_path)
    file_id = "11111111-1111-4111-8111-111111111111"
    original_path = tmp_path / f"{file_id}.txt"
    original_path.write_text("legacy contract text", encoding="utf-8")
    storage.metadata_path(file_id).write_text(
        json.dumps(
            {
                "file_id": file_id,
                "filename": "legacy.txt",
                "content_type": "text/plain",
                "suffix": ".txt",
                "path": str(original_path),
                "char_count": 20,
                "text_preview": "legacy contract text",
            }
        ),
        encoding="utf-8",
    )

    metadata = storage.load_metadata(file_id)

    assert metadata is not None
    assert metadata.owner_user_id is None
    assert metadata.created_at is None
    assert metadata.expires_at is None
    assert storage.find_upload(file_id, owner_user_id=123) == original_path


def test_new_upload_metadata_contains_owner_and_expiry(tmp_path: Path, monkeypatch) -> None:
    client = _client(tmp_path, monkeypatch)
    headers, user_id = _register(client, "owner@example.com")

    response = client.post(
        "/api/files/upload",
        headers=headers,
        files={"file": ("contract.txt", b"payment contract text", "text/plain")},
    )

    assert response.status_code == 200
    file_id = response.json()["file_id"]
    metadata = storage.load_metadata(file_id)
    assert metadata is not None
    assert metadata.owner_user_id == user_id
    assert metadata.created_at is not None
    assert metadata.expires_at is not None
    retention = _parse_iso(metadata.expires_at) - _parse_iso(metadata.created_at)
    assert timedelta(days=89) < retention < timedelta(days=91)
    assert storage.find_upload(file_id, owner_user_id=user_id) is not None
    assert storage.find_upload(file_id) is None


def test_file_id_review_allows_owner_and_rejects_other_user(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr("app.services.contracts.review.create_qwen_provider", lambda: FailingProvider())
    client = _client(tmp_path, monkeypatch)
    owner_headers, _ = _register(client, "contract-owner@example.com")
    other_headers, _ = _register(client, "contract-other@example.com")
    upload_response = client.post(
        "/api/files/upload",
        headers=owner_headers,
        files={"file": ("contract.txt", b"Payment is due after acceptance.", "text/plain")},
    )
    assert upload_response.status_code == 200
    file_id = upload_response.json()["file_id"]

    owner_response = client.post(
        "/api/contracts/run",
        headers=owner_headers,
        json={"mode": "review", "file_id": file_id},
    )
    assert owner_response.status_code == 200
    assert owner_response.json()["review_result"]["source"]["file_id"] == file_id

    other_response = client.post(
        "/api/contracts/run",
        headers=other_headers,
        json={"mode": "review", "file_id": file_id},
    )
    assert other_response.status_code == 404
    assert other_response.json()["error"]["code"] == "file_not_found"

    wildcard_response = client.post(
        "/api/contracts/run",
        headers=other_headers,
        json={"mode": "review", "file_id": "*"},
    )
    assert wildcard_response.status_code == 404
    assert wildcard_response.json()["error"]["code"] == "file_not_found"

    generate_response = client.post(
        "/api/contracts/run",
        headers=other_headers,
        json={"mode": "generate", "file_id": file_id},
    )
    assert generate_response.status_code == 404
    assert generate_response.json()["error"]["code"] == "file_not_found"


def test_cleanup_deletes_only_expired_upload_artifacts(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setattr(storage, "UPLOAD_DIR", tmp_path)
    now = datetime(2026, 7, 6, tzinfo=UTC)
    expired_file_id = "22222222-2222-4222-8222-222222222222"
    active_file_id = "33333333-3333-4333-8333-333333333333"
    expired_original = tmp_path / f"{expired_file_id}.txt"
    active_original = tmp_path / f"{active_file_id}.txt"
    expired_original.write_text("expired", encoding="utf-8")
    active_original.write_text("active", encoding="utf-8")

    expired = storage.StoredFile(
        file_id=expired_file_id,
        filename="expired.txt",
        content_type="text/plain",
        suffix=".txt",
        path=str(expired_original),
        expires_at=(now - timedelta(seconds=1)).isoformat().replace("+00:00", "Z"),
    )
    active = storage.StoredFile(
        file_id=active_file_id,
        filename="active.txt",
        content_type="text/plain",
        suffix=".txt",
        path=str(active_original),
        expires_at=(now + timedelta(days=1)).isoformat().replace("+00:00", "Z"),
    )
    storage.save_metadata(expired)
    storage.save_metadata(active)
    expired_extracted = storage.extracted_text_path(expired.file_id)
    active_extracted = storage.extracted_text_path(active.file_id)
    expired_extracted.write_text("expired extracted", encoding="utf-8")
    active_extracted.write_text("active extracted", encoding="utf-8")

    result = cleanup_expired_uploads(now=now)

    assert result.deleted_file_ids == [expired_file_id]
    assert not expired_original.exists()
    assert not storage.metadata_path(expired.file_id).exists()
    assert not expired_extracted.exists()
    assert active_original.exists()
    assert storage.metadata_path(active.file_id).exists()
    assert active_extracted.exists()


def test_cleanup_does_not_delete_metadata_path_outside_upload_dir(tmp_path: Path, monkeypatch) -> None:
    upload_dir = tmp_path / "uploads"
    outside_file = tmp_path / "outside.txt"
    monkeypatch.setattr(storage, "UPLOAD_DIR", upload_dir)
    file_id = "44444444-4444-4444-8444-444444444444"
    now = datetime(2026, 7, 6, tzinfo=UTC)
    outside_file.write_text("must stay", encoding="utf-8")
    metadata = storage.StoredFile(
        file_id=file_id,
        filename="polluted.txt",
        content_type="text/plain",
        suffix=".txt",
        path=str(outside_file),
        expires_at=(now - timedelta(days=1)).isoformat().replace("+00:00", "Z"),
    )
    storage.save_metadata(metadata)

    result = cleanup_expired_uploads(now=now)

    assert result.deleted_file_ids == [file_id]
    assert outside_file.exists()
    assert not storage.metadata_path(file_id).exists()
