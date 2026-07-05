from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, File, UploadFile

from app.core.config import settings
from app.core.errors import api_error
from app.models.files import FileUploadResponse
from app.services.files.extractor import SUPPORTED_SUFFIXES, TextExtractionError, extract_text
from app.services.files.storage import StoredFile, save_metadata, upload_path

router = APIRouter(prefix="/api/files", tags=["files"])

IMAGE_CONTENT_PREFIX = "image/"
MAX_CHUNK_SIZE = 1024 * 1024


@router.post("/upload", response_model=FileUploadResponse)
async def upload_file(file: UploadFile = File(...)) -> FileUploadResponse:
    filename = file.filename or "untitled"
    suffix = Path(filename).suffix.lower()
    content_type = file.content_type

    if content_type and content_type.lower().startswith(IMAGE_CONTENT_PREFIX):
        raise api_error(400, "unsupported_file_type", "不支持图片上传，请上传 PDF、DOCX 或 TXT 文件")

    if suffix not in SUPPORTED_SUFFIXES:
        raise api_error(400, "unsupported_file_type", "仅支持 PDF、DOCX、TXT 文件")

    file_id = str(uuid4())
    destination = upload_path(file_id, suffix)
    max_bytes = settings.max_upload_mb * 1024 * 1024
    total_size = 0

    try:
        with destination.open("wb") as buffer:
            while chunk := await file.read(MAX_CHUNK_SIZE):
                total_size += len(chunk)
                if total_size > max_bytes:
                    destination.unlink(missing_ok=True)
                    raise api_error(413, "file_too_large", "文件大小不能超过 20MB")
                buffer.write(chunk)

        try:
            text = extract_text(destination)
        except TextExtractionError:
            destination.unlink(missing_ok=True)
            raise api_error(400, "text_extraction_failed", "文件文本抽取失败，请确认文件可读取")

        if not text.strip():
            destination.unlink(missing_ok=True)
            raise api_error(400, "empty_file_text", "文件未抽取到可审查文本，请上传包含文字的 PDF、DOCX 或 TXT 文件")

        preview = text[:240]
        stored_file = StoredFile(
            file_id=file_id,
            filename=filename,
            content_type=content_type,
            suffix=suffix,
            path=str(destination),
            char_count=len(text),
            text_preview=preview,
        )
        save_metadata(stored_file)
    finally:
        await file.close()

    return FileUploadResponse(
        file_id=file_id,
        filename=filename,
        content_type=content_type,
        status="accepted",
        text_preview=preview,
        char_count=len(text),
    )
