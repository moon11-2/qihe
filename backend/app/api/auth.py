from fastapi import APIRouter, Header

from app.core.errors import api_error
from app.models.auth import AuthTokenResponse, AuthUser, LoginRequest, RegisterRequest
from app.services.auth import AuthError, authenticate_user, get_user_from_token, register_user

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/register", response_model=AuthTokenResponse)
async def register(request: RegisterRequest) -> AuthTokenResponse:
    try:
        user, token, expires_in = register_user(request)
    except AuthError as exc:
        raise api_error(exc.status_code, exc.code, exc.message) from exc
    return AuthTokenResponse(access_token=token, expires_in=expires_in, user=user)


@router.post("/login", response_model=AuthTokenResponse)
async def login(request: LoginRequest) -> AuthTokenResponse:
    try:
        user, token, expires_in = authenticate_user(request)
    except AuthError as exc:
        raise api_error(exc.status_code, exc.code, exc.message) from exc
    return AuthTokenResponse(access_token=token, expires_in=expires_in, user=user)


@router.get("/me", response_model=AuthUser)
async def me(authorization: str | None = Header(default=None)) -> AuthUser:
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
