"""Entitlement API – credit balance and activation codes."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.deps import require_current_user
from app.core.errors import api_error
from app.models.auth import AuthUser
from app.models.entitlements import ActivateRequest, ActivateResponse, CreditBalance
from app.services.billing import activation as activation_service
from app.services.billing.quota import get_balance

router = APIRouter(prefix="/api/entitlements", tags=["entitlements"], dependencies=[Depends(require_current_user)])


@router.get("/me", response_model=CreditBalance)
async def get_my_credits(user: AuthUser = Depends(require_current_user)) -> CreditBalance:
    """Get current user's credit balance."""
    balance = get_balance(user.id)
    from app.services.billing.quota import ensure_user_credits
    from app.services.db import connect
    row = None
    with connect() as conn:
        row = conn.execute(
            "SELECT created_at, updated_at FROM user_credits WHERE user_id = ?",
            (user.id,),
        ).fetchone()
    return CreditBalance(
        user_id=user.id,
        balance=balance,
        created_at=str(row["created_at"]) if row else "",
        updated_at=str(row["updated_at"]) if row else "",
    )


@router.post("/activate", response_model=ActivateResponse)
async def activate_code(
    request: ActivateRequest,
    user: AuthUser = Depends(require_current_user),
) -> ActivateResponse:
    """Redeem an activation code."""
    try:
        credits_added, balance = activation_service.redeem_code(request.code, user.id)
    except ValueError as exc:
        code = str(exc)
        if "not_found" in code:
            raise api_error(404, "activation_code_not_found", "激活码不存在")
        if "already_redeemed" in code:
            raise api_error(409, "activation_code_already_redeemed", "激活码已被兑换")
        if "expired" in code:
            raise api_error(400, "activation_code_expired", "激活码已过期")
        raise api_error(400, "activation_code_invalid", str(exc))

    return ActivateResponse(
        message="激活码兑换成功",
        credits_added=credits_added,
        balance=balance,
    )
