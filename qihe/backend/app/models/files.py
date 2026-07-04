from pydantic import BaseModel


class FileUploadResponse(BaseModel):
    file_id: str
    filename: str
    content_type: str | None
    status: str
    text_preview: str
    char_count: int
