import sqlite3
from pathlib import Path

from app.core.config import DEFAULT_QIHE_DB_PATH, settings


def connect() -> sqlite3.Connection:
    db_path = _database_path()
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_schema() -> None:
    with connect() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT NOT NULL UNIQUE,
                display_name TEXT,
                password_hash TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.execute("CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)")


def _database_path() -> Path:
    db_path = str(settings.db_path or "").strip()
    legacy_auth_db_path = str(settings.auth_db_path or "").strip()
    if legacy_auth_db_path and db_path == DEFAULT_QIHE_DB_PATH:
        return Path(legacy_auth_db_path)
    return Path(db_path or DEFAULT_QIHE_DB_PATH)
