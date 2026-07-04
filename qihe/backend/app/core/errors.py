from typing import Any

from fastapi import HTTPException, Request
from fastapi.responses import JSONResponse


def api_error(status_code: int, code: str, message: str) -> HTTPException:
    return HTTPException(status_code=status_code, detail={"code": code, "message": message})


def _public_error(detail: Any, status_code: int) -> dict[str, str]:
    if isinstance(detail, dict):
        code = str(detail.get("code") or "request_error")
        message = str(detail.get("message") or "请求无法处理")
        return {"code": code, "message": message}

    if status_code >= 500:
        return {"code": "internal_error", "message": "服务器暂时无法处理请求"}

    return {"code": "request_error", "message": str(detail or "请求无法处理")}


async def validation_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={"error": {"code": "validation_error", "message": "请求参数格式不正确"}},
    )


async def http_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    status_code = getattr(exc, "status_code", 500)
    detail = getattr(exc, "detail", "Internal server error")
    return JSONResponse(
        status_code=status_code,
        content={"error": _public_error(detail, status_code)},
    )
