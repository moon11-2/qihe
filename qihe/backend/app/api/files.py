from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.models.files import FileUploadResponse

router = APIRouter(prefix="/api/files", tags=["files"])

ALLOWED_SUFFIXES = {".pdf", ".doc", ".docx", ".txt"}


@router.post("/upload", response_model=FileUploadResponse)
async def upload_file(file: UploadFile = File(...)) -> FileUploadResponse:
    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in ALLOWED_SUFFIXES:
        raise HTTPException(status_code=400, detail="Only PDF, Word, and TXT files are supported.")

    return FileUploadResponse(
        file_id=str(uuid4()),
        filename=file.filename or "untitled",
        content_type=file.content_type,
        status="accepted",
    )

