from urllib.parse import quote

from fastapi import APIRouter, Depends, Response

from app.api.deps import require_current_user
from app.core.errors import api_error
from app.models.contracts import ContractExportRequest, ContractRunRequest, ContractRunResponse
from app.services.contracts.export_word import export_contract_word
from app.services.contracts.generate import run_generate
from app.services.contracts.review import run_review

router = APIRouter(prefix="/api/contracts", tags=["contracts"], dependencies=[Depends(require_current_user)])


@router.post("/run", response_model=ContractRunResponse)
async def run_contract_task(request: ContractRunRequest) -> ContractRunResponse:
    if request.mode == "review":
        return ContractRunResponse(
            type="review_result",
            intent="review",
            review_result=await run_review(request),
        )
    if request.mode == "generate":
        return ContractRunResponse(
            type="generate_result",
            intent="generate",
            generate_result=await run_generate(request),
        )

    raise api_error(400, "unsupported_contract_mode", "不支持的合同任务类型")


@router.post("/export/word")
async def export_word(request: ContractExportRequest) -> Response:
    content = export_contract_word(request)
    filename = f"{request.title or '契合导出'}.docx"
    encoded_filename = quote(filename)
    return Response(
        content=content,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={"Content-Disposition": f"attachment; filename*=UTF-8''{encoded_filename}"},
    )
