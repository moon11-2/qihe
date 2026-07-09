import json
from dataclasses import asdict, dataclass, fields
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import UUID


UPLOAD_DIR = Path("uploads")
DEFAULT_RETENTION_DAYS = 90


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
    if not is_valid_file_id(file_id) or not is_safe_suffix(suffix):
        raise ValueError("invalid upload path")
    return ensure_upload_dir() / f"{file_id}{suffix}"


def metadata_path(file_id: str) -> Path:
    if not is_valid_file_id(file_id):
        raise ValueError("invalid file_id")
    return ensure_upload_dir() / f"{file_id}.json"


def extracted_text_path(file_id: str) -> Path:
    if not is_valid_file_id(file_id):
        raise ValueError("invalid file_id")
    return ensure_upload_dir() / f"{file_id}.extracted.txt"


def utc_now_iso() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def default_expires_at(created_at: datetime | None = None) -> str:
    base = created_at or datetime.now(UTC)
    return (base + timedelta(days=DEFAULT_RETENTION_DAYS)).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def save_metadata(stored_file: StoredFile) -> None:
    metadata_path(stored_file.file_id).write_text(
        json.dumps(asdict(stored_file), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def load_metadata(file_id: str) -> StoredFile | None:
    if not is_valid_file_id(file_id):
        return None
    path = metadata_path(file_id)
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("file_id") != file_id:
        return None
    data.setdefault("owner_user_id", None)
    data.setdefault("created_at", None)
    data.setdefault("expires_at", None)
    data["owner_user_id"] = _int_or_none(data.get("owner_user_id"))
    allowed_fields = {field.name for field in fields(StoredFile)}
    return StoredFile(**{key: value for key, value in data.items() if key in allowed_fields})


def find_upload(file_id: str, owner_user_id: int | None = None) -> Path | None:
    if not is_valid_file_id(file_id):
        return None
    metadata = load_metadata(file_id)
    if metadata is None or not metadata_allows_owner(metadata, owner_user_id):
        return None
    return stored_upload_path(metadata)


def metadata_allows_owner(metadata: StoredFile, owner_user_id: int | None) -> bool:
    if metadata.owner_user_id is None:
        return True
    if owner_user_id is None:
        return False
    return metadata.owner_user_id == owner_user_id


def stored_upload_path(metadata: StoredFile) -> Path | None:
    if not is_valid_file_id(metadata.file_id) or not is_safe_suffix(metadata.suffix):
        return None
    upload_dir = ensure_upload_dir().resolve()
    expected_path = (upload_dir / f"{metadata.file_id}{metadata.suffix}").resolve()
    metadata_path_value = Path(metadata.path).resolve()
    if metadata_path_value != expected_path:
        return None
    if not _is_relative_to(expected_path, upload_dir) or not expected_path.exists():
        return None
    return expected_path


def save_extracted_text(file_id: str, text: str) -> None:
    extracted_text_path(file_id).write_text(text, encoding="utf-8")


def load_extracted_text(file_id: str) -> str | None:
    if not is_valid_file_id(file_id):
        return None
    path = extracted_text_path(file_id)
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8")


def is_valid_file_id(file_id: str) -> bool:
    try:
        parsed = UUID(file_id, version=4)
    except (TypeError, ValueError, AttributeError):
        return False
    return str(parsed) == file_id.lower()


def is_safe_suffix(suffix: str) -> bool:
    return suffix.startswith(".") and "/" not in suffix and "\\" not in suffix and suffix not in {".", ".."}


def _int_or_none(value: object) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True
