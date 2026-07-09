"""StoreKit transaction verification entrypoint.

Credits must only be granted after server-side Apple verification. The current
backend has no App Store Server API/JWS verification configured, so this module
fails closed instead of trusting client-supplied transaction fields.
"""

from __future__ import annotations

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
    """Process a StoreKit transaction and grant credits after Apple verification.

    Returns (credits_added, new_balance).
    Raises ValueError while verification is not configured.
    """
    raise ValueError("storekit_verification_not_configured")
