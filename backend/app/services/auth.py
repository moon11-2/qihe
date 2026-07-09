import base64
import hashlib
import hmac
import json
import secrets
import sqlite3
import time
from typing import Any

from app.core.config import settings
from app.models.auth import AuthUser, LoginRequest, RegisterRequest
from app.services.db import connect, init_schema

TOKEN_ALGORITHM = "HS256"
TOKEN_TYPE = "JWT"
PASSWORD_ITERATIONS = 210_000
_PROCESS_JWT_SECRET = secrets.token_urlsafe(32)


class AuthError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code


def register_user(request: RegisterRequest) -> tuple[AuthUser, str, int]:
    _jwt_secret()
    init_schema()
    now = _now_iso()
    password_hash = _hash_password(request.password)
    try:
        with connect() as conn:
            cursor = conn.execute(
                "INSERT INTO users (email, display_name, password_hash, created_at) VALUES (?, ?, ?, ?)",
                (request.email, request.display_name, password_hash, now),
            )
            user = AuthUser(
                id=int(cursor.lastrowid),
                email=request.email,
                display_name=request.display_name,
                created_at=now,
            )
    except sqlite3.IntegrityError as exc:
        raise AuthError("email_already_registered", "该邮箱已注册", status_code=409) from exc

    token, expires_in = create_access_token(user)
    return user, token, expires_in


def authenticate_user(request: LoginRequest) -> tuple[AuthUser, str, int]:
    _jwt_secret()
    init_schema()
    row = _get_user_row_by_email(request.email)
    if row is None or not _verify_password(request.password, str(row["password_hash"])):
        raise AuthError("invalid_credentials", "邮箱或密码不正确", status_code=401)

    user = _row_to_user(row)
    token, expires_in = create_access_token(user)
    return user, token, expires_in


def get_user_from_token(token: str) -> AuthUser:
    payload = _decode_token(token)
    user_id = payload.get("sub")
    if not isinstance(user_id, int):
        raise AuthError("invalid_token", "登录状态无效，请重新登录", status_code=401)

    init_schema()
    row = _get_user_row_by_id(user_id)
    if row is None:
        raise AuthError("invalid_token", "登录状态无效，请重新登录", status_code=401)
    return _row_to_user(row)


def create_access_token(user: AuthUser) -> tuple[str, int]:
    expires_in = max(int(settings.jwt_expires_minutes), 1) * 60
    now = int(time.time())
    payload = {
        "sub": user.id,
        "email": user.email,
        "iat": now,
        "exp": now + expires_in,
    }
    header = {"typ": TOKEN_TYPE, "alg": TOKEN_ALGORITHM}
    signing_input = f"{_b64_json(header)}.{_b64_json(payload)}"
    signature = _sign(signing_input)
    return f"{signing_input}.{signature}", expires_in


def _decode_token(token: str) -> dict[str, Any]:
    parts = token.split(".")
    if len(parts) != 3:
        raise AuthError("invalid_token", "登录状态无效，请重新登录", status_code=401)

    signing_input = f"{parts[0]}.{parts[1]}"
    expected_signature = _sign(signing_input)
    if not hmac.compare_digest(parts[2], expected_signature):
        raise AuthError("invalid_token", "登录状态无效，请重新登录", status_code=401)

    try:
        header = _b64_decode_json(parts[0])
        payload = _b64_decode_json(parts[1])
    except (ValueError, json.JSONDecodeError) as exc:
        raise AuthError("invalid_token", "登录状态无效，请重新登录", status_code=401) from exc

    if header.get("alg") != TOKEN_ALGORITHM:
        raise AuthError("invalid_token", "登录状态无效，请重新登录", status_code=401)
    exp = payload.get("exp")
    if not isinstance(exp, int) or exp < int(time.time()):
        raise AuthError("token_expired", "登录已过期，请重新登录", status_code=401)
    return payload


def _get_user_row_by_email(email: str) -> sqlite3.Row | None:
    with connect() as conn:
        return conn.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()


def _get_user_row_by_id(user_id: int) -> sqlite3.Row | None:
    with connect() as conn:
        return conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()


def _row_to_user(row: sqlite3.Row) -> AuthUser:
    return AuthUser(
        id=int(row["id"]),
        email=str(row["email"]),
        display_name=row["display_name"],
        created_at=str(row["created_at"]),
    )


def _hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, PASSWORD_ITERATIONS)
    return f"pbkdf2_sha256${PASSWORD_ITERATIONS}${_b64_bytes(salt)}${_b64_bytes(digest)}"


def _verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, iterations_raw, salt_raw, digest_raw = stored_hash.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False
        iterations = int(iterations_raw)
        salt = _b64_decode_bytes(salt_raw)
        expected = _b64_decode_bytes(digest_raw)
    except (ValueError, TypeError):
        return False

    actual = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return hmac.compare_digest(actual, expected)


def _jwt_secret() -> str:
    secret = settings.jwt_secret.strip()
    if secret:
        return secret
    if settings.app_env.lower() in {"prod", "production"}:
        raise AuthError("auth_not_configured", "认证服务暂时不可用", status_code=503)
    return _PROCESS_JWT_SECRET


def _sign(signing_input: str) -> str:
    digest = hmac.new(_jwt_secret().encode("utf-8"), signing_input.encode("utf-8"), hashlib.sha256).digest()
    return _b64_bytes(digest)


def _b64_json(value: dict[str, Any]) -> str:
    raw = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return _b64_bytes(raw)


def _b64_decode_json(value: str) -> dict[str, Any]:
    decoded = _b64_decode_bytes(value).decode("utf-8")
    data = json.loads(decoded)
    if not isinstance(data, dict):
        raise ValueError("token segment is not an object")
    return data


def _b64_bytes(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def _b64_decode_bytes(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


# ── Email verification code ────────────────────────────────────────────

VERIFICATION_CODE_MAX_ATTEMPTS = 5
VERIFICATION_CODE_TTL_MINUTES = 10
VERIFICATION_CODE_RESEND_SECONDS = 60


def send_verification_code(email: str, ip_address: str | None = None) -> None:
    """Generate a 6-digit code and store a verifiable server-side HMAC."""
    init_schema()
    now = _now_iso()
    code = _generate_code()
    code_hash = _hash_code(email, code)
    expires_at = _iso_at_offset(VERIFICATION_CODE_TTL_MINUTES * 60)
    ip_hash = _hash_ip(ip_address) if ip_address else None

    # Rate-limit: 60s between sends for the same email
    with connect() as conn:
        row = conn.execute(
            "SELECT created_at FROM email_verification_codes WHERE email = ? ORDER BY id DESC LIMIT 1",
            (email,),
        ).fetchone()
        if row:
            last_sent = _parse_iso_to_unix(str(row["created_at"]))
            if time.time() - last_sent < VERIFICATION_CODE_RESEND_SECONDS:
                raise AuthError("code_rate_limited", "发送过于频繁，请稍后再试", status_code=429)

        conn.execute(
            "INSERT INTO email_verification_codes (email, code_hash, expires_at, created_at, ip_hash) "
            "VALUES (?, ?, ?, ?, ?)",
            (email, code_hash, expires_at, now, ip_hash),
        )
        conn.commit()


def verify_code_and_login(email: str, code: str) -> tuple[AuthUser, str, int]:
    """Verify a 6-digit code and return user + token.

    If the user doesn't exist, auto-register them (code-based first login).
    """
    init_schema()

    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM email_verification_codes "
            "WHERE email = ? AND consumed_at IS NULL "
            "ORDER BY id DESC LIMIT 1",
            (email,),
        ).fetchone()

        if not row:
            raise AuthError("invalid_code", "验证码不正确或已过期", status_code=401)

        if row["attempts"] >= VERIFICATION_CODE_MAX_ATTEMPTS:
            conn.execute(
                "UPDATE email_verification_codes SET consumed_at = ? WHERE id = ?",
                (_now_iso(), row["id"]),
            )
            conn.commit()
            raise AuthError("code_expired", "验证码已失效，请重新获取", status_code=401)

        if _parse_iso_to_unix(str(row["expires_at"])) < int(time.time()):
            conn.execute(
                "UPDATE email_verification_codes SET consumed_at = ? WHERE id = ?",
                (_now_iso(), row["id"]),
            )
            conn.commit()
            raise AuthError("code_expired", "验证码已过期，请重新获取", status_code=401)

        if not _verify_code_hash(email, code, str(row["code_hash"])):
            conn.execute(
                "UPDATE email_verification_codes SET attempts = attempts + 1 WHERE id = ?",
                (row["id"],),
            )
            conn.commit()
            raise AuthError("invalid_code", "验证码不正确", status_code=401)

        # Mark as consumed
        conn.execute(
            "UPDATE email_verification_codes SET consumed_at = ? WHERE id = ?",
            (_now_iso(), row["id"]),
        )
        conn.commit()

    # Find or create user
    user_row = _get_user_row_by_email(email)
    if user_row is None:
        # Auto-register
        now = _now_iso()
        display_name = email.split("@")[0]
        password_hash = _hash_password(secrets.token_urlsafe(32))
        with connect() as conn:
            cursor = conn.execute(
                "INSERT INTO users (email, display_name, password_hash, created_at) VALUES (?, ?, ?, ?)",
                (email, display_name, password_hash, now),
            )
            conn.commit()
        user = AuthUser(id=int(cursor.lastrowid), email=email, display_name=display_name, created_at=now)
    else:
        user = _row_to_user(user_row)

    token, expires_in = create_access_token(user)
    return user, token, expires_in


def _generate_code() -> str:
    return str(secrets.randbelow(1_000_000)).zfill(6)


def _hash_code(email: str, code: str) -> str:
    normalized_email = email.strip().lower()
    normalized_code = code.strip()
    payload = f"qihe-email-code:v1:{normalized_email}:{normalized_code}".encode("utf-8")
    digest = hmac.new(_jwt_secret().encode("utf-8"), payload, hashlib.sha256).hexdigest()
    return f"hmac_sha256${digest}"


def _verify_code_hash(email: str, code: str, stored_hash: str) -> bool:
    if stored_hash.startswith("hmac_sha256$"):
        return hmac.compare_digest(stored_hash, _hash_code(email, code))

    try:
        algorithm, iterations_raw, salt_raw, digest_raw = stored_hash.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False
        iterations = int(iterations_raw)
        salt = _b64_decode_bytes(salt_raw)
        expected = _b64_decode_bytes(digest_raw)
    except (ValueError, TypeError):
        return False

    actual = hashlib.pbkdf2_hmac("sha256", code.strip().encode("utf-8"), salt, iterations)
    return hmac.compare_digest(actual, expected)


def _hash_ip(ip: str) -> str:
    return hashlib.sha256(f"salt-qihe:{ip}".encode()).hexdigest()


def _parse_iso_to_unix(iso_str: str) -> float:
    import calendar
    try:
        parsed = time.strptime(iso_str, "%Y-%m-%dT%H:%M:%SZ")
        return calendar.timegm(parsed)
    except ValueError:
        return 0


def _iso_at_offset(seconds_from_now: int) -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + seconds_from_now))
