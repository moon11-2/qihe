from fastapi import APIRouter, Depends, Request

from app.core.errors import api_error
from app.api.deps import require_current_user
from app.models.auth import AuthTokenResponse, AuthUser, LoginRequest, RegisterRequest, SendCodeRequest, VerifyCodeRequest
from app.services.auth import (
    AuthError,
    authenticate_user,
    register_user,
    send_verification_code,
    verify_code_and_login,
)

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


@router.post("/send-code")
async def send_code(request: SendCodeRequest, req: Request) -> dict:
    """Send a 6-digit verification code to the email address."""
    try:
        ip = req.client.host if req.client else None
        send_verification_code(request.email, ip_address=ip)
    except AuthError as exc:
        raise api_error(exc.status_code, exc.code, exc.message) from exc
    return {"message": "验证码已发送"}


@router.post("/verify-code", response_model=AuthTokenResponse)
async def verify_code(request: VerifyCodeRequest) -> AuthTokenResponse:
    """Verify code and return access token (auto-registers new users)."""
    try:
        user, token, expires_in = verify_code_and_login(request.email, request.code)
    except AuthError as exc:
        raise api_error(exc.status_code, exc.code, exc.message) from exc
    return AuthTokenResponse(access_token=token, expires_in=expires_in, user=user)
