from fastapi import APIRouter, Depends

from app.api.deps import require_current_user
from app.models.chat import ChatRequest, ChatResponse
from app.services.chat import build_chat_response

router = APIRouter(prefix="/api/chat", tags=["chat"], dependencies=[Depends(require_current_user)])


@router.post("", response_model=ChatResponse)
async def chat(request: ChatRequest) -> ChatResponse:
    return await build_chat_response(request)
