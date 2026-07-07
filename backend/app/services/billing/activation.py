"""Activation code generation and redemption."""

from __future__ import annotations

import hashlib
import secrets

from app.services.billing.quota import add_credits
from app.services.db import connect


def generate_activation_code(credits: int, expires_days: int | None = None) -> str:
    """Generate a single activation code and store its hash.

    Returns the plaintext code (show once to admin).
    """
    code = f"QH-{secrets.token_hex(4).upper()}-{secrets.token_hex(4).upper()}"
    code_hash = _hash_code(code)
    now = _now_iso()
    expires_at = _expires_at(days=expires_days) if expires_days else None

    with connect() as conn:
        conn.execute(
            "INSERT INTO activation_codes (code_hash, credits, expires_at, created_at) VALUES (?, ?, ?, ?)",
            (code_hash, credits, expires_at, now),
        )
        conn.commit()
    return code


def redeem_code(code: str, user_id: int) -> tuple[int, int]:
    """Redeem an activation code. Returns (credits_added, new_balance).

    Raises ValueError for invalid/expired/already-redeemed codes.
    """
    code_hash = _hash_code(code.strip().upper())
    now = _now_iso()

    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM activation_codes WHERE code_hash = ?", (code_hash,)
        ).fetchone()

        if not row:
            raise ValueError("activation_code_not_found")

        if row["redeemed_by"] is not None:
            raise ValueError("activation_code_already_redeemed")

        if row["expires_at"] and row["expires_at"] < now:
            raise ValueError("activation_code_expired")

        credits = int(row["credits"])
        conn.execute(
            "UPDATE activation_codes SET redeemed_by = ?, redeemed_at = ? WHERE id = ?",
            (user_id, now, row["id"]),
        )
        conn.commit()

    new_balance = add_credits(
        user_id=user_id,
        amount=credits,
        reason="activation_code",
        reference_id=str(row["id"]),
    )
    return credits, new_balance


def _hash_code(code: str) -> str:
    return hashlib.sha256(f"qihe-activation:{code}".encode()).hexdigest()


def _now_iso() -> str:
    import time
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _expires_at(days: int) -> str:
    import time
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + days * 86400))
