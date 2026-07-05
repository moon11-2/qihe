from fastapi import Header

from app.core.errors import api_error
from app.models.auth import AuthUser
from app.services.auth import AuthError, get_user_from_token


def require_current_user(authorization: str | None = Header(default=None)) -> AuthUser:
    token = _bearer_token(authorization)
    try:
        return get_user_from_token(token)
    except AuthError as exc:
        raise api_error(exc.status_code, exc.code, exc.message) from exc


def _bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise api_error(401, "auth_required", "请先登录")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise api_error(401, "invalid_token", "登录状态无效，请重新登录")
    return token.strip()
