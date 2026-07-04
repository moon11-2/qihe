from fastapi import Request
from fastapi.responses import JSONResponse


async def validation_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={"error": {"code": "validation_error", "message": str(exc)}},
    )


async def http_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    status_code = getattr(exc, "status_code", 500)
    detail = getattr(exc, "detail", "Internal server error")
    return JSONResponse(
        status_code=status_code,
        content={"error": {"code": "request_error", "message": detail}},
    )

