from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path

from app.services.files import storage


@dataclass(frozen=True)
class CleanupResult:
    deleted_file_ids: list[str] = field(default_factory=list)
    deleted_paths: list[Path] = field(default_factory=list)
    skipped_file_ids: list[str] = field(default_factory=list)


def cleanup_expired_uploads(now: datetime | None = None) -> CleanupResult:
    current_time = now or datetime.now(UTC)
    deleted_file_ids: list[str] = []
    deleted_paths: list[Path] = []
    skipped_file_ids: list[str] = []

    for metadata_file in storage.ensure_upload_dir().glob("*.json"):
        stored_file = storage.load_metadata(metadata_file.stem)
        if stored_file is None:
            continue
        if not _is_expired(stored_file.expires_at, current_time):
            skipped_file_ids.append(stored_file.file_id)
            continue

        for path in _upload_artifact_paths(stored_file):
            if path.exists():
                path.unlink()
                deleted_paths.append(path)
        deleted_file_ids.append(stored_file.file_id)

    return CleanupResult(
        deleted_file_ids=deleted_file_ids,
        deleted_paths=deleted_paths,
        skipped_file_ids=skipped_file_ids,
    )


def _upload_artifact_paths(stored_file: storage.StoredFile) -> list[Path]:
    paths = [
        storage.extracted_text_path(stored_file.file_id),
        storage.metadata_path(stored_file.file_id),
    ]
    if storage.is_valid_file_id(stored_file.file_id) and storage.is_safe_suffix(stored_file.suffix):
        paths.insert(0, storage.upload_path(stored_file.file_id, stored_file.suffix))
    return paths


def _is_expired(expires_at: str | None, now: datetime) -> bool:
    if not expires_at:
        return False
    expires_at_datetime = _parse_iso_datetime(expires_at)
    if expires_at_datetime is None:
        return False
    return expires_at_datetime <= _as_aware_utc(now)


def _parse_iso_datetime(value: str) -> datetime | None:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return _as_aware_utc(parsed)


def _as_aware_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
