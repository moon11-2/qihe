import json
from dataclasses import asdict, dataclass
from pathlib import Path


UPLOAD_DIR = Path("uploads")


@dataclass(frozen=True)
class StoredFile:
    file_id: str
    filename: str
    content_type: str | None
    suffix: str
    path: str
    char_count: int = 0
    text_preview: str = ""
    owner_user_id: int | None = None
    created_at: str | None = None
    expires_at: str | None = None


def ensure_upload_dir() -> Path:
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    return UPLOAD_DIR


def upload_path(file_id: str, suffix: str) -> Path:
    return ensure_upload_dir() / f"{file_id}{suffix}"


def metadata_path(file_id: str) -> Path:
    return ensure_upload_dir() / f"{file_id}.json"


def save_metadata(stored_file: StoredFile) -> None:
    metadata_path(stored_file.file_id).write_text(
        json.dumps(asdict(stored_file), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def load_metadata(file_id: str) -> StoredFile | None:
    path = metadata_path(file_id)
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    # Backward compat: older metadata files may lack new fields
    data.setdefault("owner_user_id", None)
    data.setdefault("created_at", None)
    data.setdefault("expires_at", None)
    return StoredFile(**data)


def find_upload(file_id: str) -> Path | None:
    metadata = load_metadata(file_id)
    if metadata:
        path = Path(metadata.path)
        if path.exists():
            return path

    for path in ensure_upload_dir().glob(f"{file_id}.*"):
        if path.suffix == ".json":
            continue
        return path
    return None


def extracted_text_path(file_id: str) -> Path:
    """Path to the extracted full text file for a given upload."""
    return ensure_upload_dir() / f"{file_id}.txt"


def save_extracted_text(file_id: str, text: str) -> None:
    """Save the full extracted text alongside the uploaded file metadata."""
    extracted_text_path(file_id).write_text(text, encoding="utf-8")


def load_extracted_text(file_id: str) -> str | None:
    """Load the full extracted text for a file, if it exists."""
    path = extracted_text_path(file_id)
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8")
