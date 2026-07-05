from collections.abc import Mapping
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import create_app


AUTH_BASE_CANDIDATES = ("/api/auth", "/auth")


@pytest.fixture()
def client(tmp_path, monkeypatch) -> TestClient:
    monkeypatch.setattr(settings, "auth_db_path", str(tmp_path / "auth.sqlite3"))
    monkeypatch.setattr(settings, "jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "jwt_expires_minutes", 60)
    return TestClient(create_app())


def _auth_base(client: TestClient) -> str:
    route_paths = {getattr(route, "path", "") for route in client.app.routes}
    for base in AUTH_BASE_CANDIDATES:
        if f"{base}/register" in route_paths and f"{base}/login" in route_paths and f"{base}/me" in route_paths:
            return base
    pytest.skip("auth API is not implemented yet")


def _new_credentials() -> dict[str, str]:
    return {
        "email": f"auth-{uuid4().hex}@example.com",
        "password": "TestPassw0rd!",
    }


def _extract_token(payload: Mapping[str, object]) -> str:
    token = payload.get("access_token") or payload.get("token")
    if not token and isinstance(payload.get("data"), Mapping):
        data = payload["data"]
        token = data.get("access_token") or data.get("token")
    if not token and isinstance(payload.get("auth"), Mapping):
        auth = payload["auth"]
        token = auth.get("access_token") or auth.get("token")
    assert isinstance(token, str)
    assert token
    return token


def _assert_no_password_material(value: object) -> None:
    if isinstance(value, Mapping):
        forbidden_keys = {"password", "password_hash", "hashed_password"}
        assert forbidden_keys.isdisjoint(value.keys())
        for nested in value.values():
            _assert_no_password_material(nested)
    elif isinstance(value, list):
        for nested in value:
            _assert_no_password_material(nested)


def _register(client: TestClient, base: str, credentials: dict[str, str]):
    return client.post(f"{base}/register", json=credentials)


def _login(client: TestClient, base: str, credentials: dict[str, str]):
    return client.post(f"{base}/login", json=credentials)


def test_register_success(client: TestClient) -> None:
    base = _auth_base(client)
    credentials = _new_credentials()

    response = _register(client, base, credentials)

    assert response.status_code in (200, 201)
    payload = response.json()
    assert credentials["email"] in str(payload)
    _assert_no_password_material(payload)


def test_duplicate_register_fails(client: TestClient) -> None:
    base = _auth_base(client)
    credentials = _new_credentials()
    first_response = _register(client, base, credentials)
    assert first_response.status_code in (200, 201)

    duplicate_response = _register(client, base, credentials)

    assert duplicate_response.status_code in (400, 409)
    payload = duplicate_response.json()
    assert "error" in payload
    assert "password" not in str(payload).lower()


def test_login_success_and_failure(client: TestClient) -> None:
    base = _auth_base(client)
    credentials = _new_credentials()
    register_response = _register(client, base, credentials)
    assert register_response.status_code in (200, 201)

    success_response = _login(client, base, credentials)
    assert success_response.status_code == 200
    token = _extract_token(success_response.json())
    assert token not in credentials.values()

    failed_response = _login(client, base, {**credentials, "password": "wrong-password"})
    assert failed_response.status_code in (400, 401, 403)
    failed_payload = failed_response.json()
    assert "error" in failed_payload
    assert "access_token" not in failed_payload
    assert "token" not in failed_payload


def test_me_success_missing_token_and_invalid_token(client: TestClient) -> None:
    base = _auth_base(client)
    credentials = _new_credentials()
    register_response = _register(client, base, credentials)
    assert register_response.status_code in (200, 201)
    token = _extract_token(_login(client, base, credentials).json())

    success_response = client.get(f"{base}/me", headers={"Authorization": f"Bearer {token}"})
    assert success_response.status_code == 200
    payload = success_response.json()
    assert credentials["email"] in str(payload)
    _assert_no_password_material(payload)

    missing_token_response = client.get(f"{base}/me")
    assert missing_token_response.status_code == 401
    assert "error" in missing_token_response.json()

    invalid_token_response = client.get(f"{base}/me", headers={"Authorization": "Bearer invalid-token"})
    assert invalid_token_response.status_code == 401
    assert "error" in invalid_token_response.json()


def test_core_contract_api_requires_login(client: TestClient) -> None:
    anonymous_response = client.post(
        "/api/contracts/run",
        json={
            "mode": "generate",
            "text": "生成一份服务合同，甲方甲公司，乙方乙公司，金额10000元。",
        },
    )

    assert anonymous_response.status_code == 401
    assert anonymous_response.json()["error"]["code"] == "auth_required"
    assert anonymous_response.json()["error"]["message"] == "请登录后使用"

    base = _auth_base(client)
    credentials = _new_credentials()
    register_response = _register(client, base, credentials)
    token = _extract_token(register_response.json())
    response = client.post(
        "/api/contracts/run",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "mode": "generate",
            "text": "生成一份服务合同，甲方甲公司，乙方乙公司，金额10000元。",
        },
    )

    assert response.status_code == 200
    assert response.json()["type"] == "generate_result"
