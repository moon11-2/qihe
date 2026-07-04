from pathlib import Path


UPLOAD_DIR = Path("uploads")


def ensure_upload_dir() -> Path:
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    return UPLOAD_DIR

