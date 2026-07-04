from fastapi import APIRouter, HTTPException

from app.models.contracts import ContractExportRequest, ContractRunRequest, ContractRunResponse
from app.services.contracts.generate import build_generate_placeholder
from app.services.contracts.review import build_review_placeholder

router = APIRouter(prefix="/api/contracts", tags=["contracts"])


@router.post("/run", response_model=ContractRunResponse)
async def run_contract_task(request: ContractRunRequest) -> ContractRunResponse:
    if request.mode == "review":
        return ContractRunResponse(type="review_result", intent="review", result=build_review_placeholder(request))
    if request.mode == "generate":
        return ContractRunResponse(type="generate_result", intent="generate", result=build_generate_placeholder(request))
    raise HTTPException(status_code=400, detail="Unsupported contract task mode.")


@router.post("/export/word")
async def export_word(_: ContractExportRequest) -> None:
    raise HTTPException(status_code=501, detail="Word export is planned for the next backend milestone.")

