from fastapi import APIRouter, Depends

from app.core.errors import api_error
from app.api.deps import require_current_user
from app.models.auth import AuthTokenResponse, AuthUser, LoginRequest, RegisterRequest
from app.services.auth import AuthError, authenticate_user, register_user

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
async def me(user: AuthUser = Depends(require_current_user)) -> AuthUser:
    return user
