"""StoreKit transaction verification and credit granting."""

from __future__ import annotations

from app.services.billing.quota import add_credits
from app.services.db import connect

# MVP product_id -> credits mapping
PRODUCT_CREDITS: dict[str, int] = {
    "com.qihe.credits.small": 30,
    "com.qihe.credits.medium": 100,
    "com.qihe.credits.large": 300,
}


def process_storekit_transaction(
    user_id: int,
    transaction_id: str,
    product_id: str,
    raw_payload: dict | None = None,
) -> tuple[int, int]:
    """Process a StoreKit transaction and grant credits.

    Returns (credits_added, new_balance).
    Raises ValueError for duplicate transactions or unknown products.
    """
    # Check for duplicate transaction
    with connect() as conn:
        existing = conn.execute(
            "SELECT id FROM storekit_transactions WHERE transaction_id = ?",
            (transaction_id,),
        ).fetchone()
        if existing:
            raise ValueError("storekit_duplicate_transaction")

    credits = PRODUCT_CREDITS.get(product_id)
    if credits is None:
        raise ValueError("storekit_unknown_product")

    now = _now_iso()
    with connect() as conn:
        conn.execute(
            "INSERT INTO storekit_transactions (user_id, transaction_id, product_id, credits, raw_payload, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (user_id, transaction_id, product_id, credits, _json_or_none(raw_payload), now),
        )
        conn.commit()

    new_balance = add_credits(
        user_id=user_id,
        amount=credits,
        reason="storekit_purchase",
        reference_id=transaction_id,
    )
    return credits, new_balance


def _json_or_none(value: dict | None) -> str | None:
    import json
    if value is None:
        return None
    return json.dumps(value, ensure_ascii=False)


def _now_iso() -> str:
    import time
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
