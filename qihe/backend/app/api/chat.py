from fastapi import APIRouter

from app.models.chat import ChatRequest, ChatResponse

router = APIRouter(prefix="/api/chat", tags=["chat"])


@router.post("", response_model=ChatResponse)
async def chat(request: ChatRequest) -> ChatResponse:
    last_message = request.messages[-1].content if request.messages else ""
    return ChatResponse(
        type="need_input",
        intent="unknown",
        reply="我已收到你的问题。下一步将接入千问完成自由聊天和意图识别。",
        options=["review", "generate"] if last_message else [],
    )

