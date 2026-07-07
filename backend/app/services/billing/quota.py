"""Credit/quota management – balance check, deduct, refund."""

from __future__ import annotations

from app.services.db import connect


# ── Credit costs (MVP) ──
CREDIT_COST_REVIEW = 2
CREDIT_COST_GENERATE = 3
CREDIT_NEW_USER_BONUS = 10


def ensure_user_credits(user_id: int) -> int:
    """Ensure user has a credit row; create with new-user bonus if not exists.
    Returns current balance.
    """
    now = _now_iso()
    with connect() as conn:
        row = conn.execute(
            "SELECT balance FROM user_credits WHERE user_id = ?", (user_id,)
        ).fetchone()
        if row:
            return int(row["balance"])

        conn.execute(
            "INSERT INTO user_credits (user_id, balance, created_at, updated_at) VALUES (?, ?, ?, ?)",
            (user_id, CREDIT_NEW_USER_BONUS, now, now),
        )
        conn.execute(
            "INSERT INTO credit_transactions (user_id, amount, reason, created_at) VALUES (?, ?, ?, ?)",
            (user_id, CREDIT_NEW_USER_BONUS, "new_user_bonus", now),
        )
        conn.commit()
        return CREDIT_NEW_USER_BONUS


def get_balance(user_id: int) -> int:
    """Get current credit balance."""
    return ensure_user_credits(user_id)


def check_balance(user_id: int, required: int) -> bool:
    """Check if user has enough credits."""
    return get_balance(user_id) >= required


def deduct_credits(
    user_id: int,
    amount: int,
    reason: str,
    job_id: str | None = None,
    reference_id: str | None = None,
) -> int:
    """Deduct credits atomically. Returns new balance.
    Raises ValueError if insufficient credits.
    """
    now = _now_iso()
    with connect() as conn:
        row = conn.execute(
            "SELECT balance FROM user_credits WHERE user_id = ?", (user_id,)
        ).fetchone()
        if not row:
            ensure_user_credits(user_id)
            row = conn.execute(
                "SELECT balance FROM user_credits WHERE user_id = ?", (user_id,)
            ).fetchone()

        current = int(row["balance"])
        if current < amount:
            raise ValueError("insufficient_credits")

        new_balance = current - amount
        conn.execute(
            "UPDATE user_credits SET balance = ?, updated_at = ? WHERE user_id = ?",
            (new_balance, now, user_id),
        )
        conn.execute(
            "INSERT INTO credit_transactions (user_id, amount, reason, reference_id, job_id, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (user_id, -amount, reason, reference_id, job_id, now),
        )
        conn.commit()
        return new_balance


def add_credits(
    user_id: int,
    amount: int,
    reason: str,
    reference_id: str | None = None,
) -> int:
    """Add credits atomically. Returns new balance."""
    ensure_user_credits(user_id)
    now = _now_iso()
    with connect() as conn:
        conn.execute(
            "UPDATE user_credits SET balance = balance + ?, updated_at = ? WHERE user_id = ?",
            (amount, now, user_id),
        )
        conn.execute(
            "INSERT INTO credit_transactions (user_id, amount, reason, reference_id, created_at) "
            "VALUES (?, ?, ?, ?, ?)",
            (user_id, amount, reason, reference_id, now),
        )
        conn.commit()
        row = conn.execute(
            "SELECT balance FROM user_credits WHERE user_id = ?", (user_id,)
        ).fetchone()
        return int(row["balance"])


def _now_iso() -> str:
    import time
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
