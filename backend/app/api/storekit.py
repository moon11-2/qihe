"""StoreKit API – transaction verification."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.deps import require_current_user
from app.core.errors import api_error
from app.models.auth import AuthUser
from app.models.entitlements import StoreKitTransactionRequest, StoreKitTransactionResponse
from app.services.billing import storekit as storekit_service

router = APIRouter(prefix="/api/storekit", tags=["storekit"], dependencies=[Depends(require_current_user)])


@router.post("/transactions", response_model=StoreKitTransactionResponse)
async def post_transaction(
    request: StoreKitTransactionRequest,
    user: AuthUser = Depends(require_current_user),
) -> StoreKitTransactionResponse:
    """Process a StoreKit transaction and grant credits."""
    try:
        credits_added, balance = storekit_service.process_storekit_transaction(
            user_id=user.id,
            transaction_id=request.transaction_id,
            product_id=request.product_id,
            raw_payload=request.raw_payload,
        )
    except ValueError as exc:
        code = str(exc)
        if "verification_not_configured" in code:
            raise api_error(503, "storekit_verification_not_configured", "StoreKit 服务端验签未配置")
        if "duplicate" in code:
            raise api_error(409, "storekit_duplicate_transaction", "该交易已处理")
        if "unknown_product" in code:
            raise api_error(400, "storekit_unknown_product", "未知产品")
        raise api_error(400, "storekit_error", str(exc))

    return StoreKitTransactionResponse(
        message="积分入账成功",
        credits_added=credits_added,
        balance=balance,
    )
