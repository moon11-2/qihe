from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api import chat, contracts, files, health
from app.core.errors import http_exception_handler, validation_exception_handler


def create_app() -> FastAPI:
    app = FastAPI(title="Qihe Backend", version="0.1.0")

    app.include_router(health.router)
    app.include_router(chat.router)
    app.include_router(files.router)
    app.include_router(contracts.router)

    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(Exception, http_exception_handler)
    return app


app = create_app()
