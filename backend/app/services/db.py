"""Unified SQLite database connection and schema initialization."""

from __future__ import annotations

import sqlite3
from pathlib import Path

from app.core.config import DEFAULT_QIHE_DB_PATH, settings


def connect() -> sqlite3.Connection:
    db_path = _resolve_db_path()
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_schema() -> None:
    with connect() as conn:
        conn.executescript(_SCHEMA_SQL)
        _ensure_jobs_columns(conn)


def _resolve_db_path() -> Path:
    db_path = str(settings.db_path or "").strip()
    legacy_auth_db_path = str(settings.auth_db_path or "").strip()
    if legacy_auth_db_path and (not db_path or db_path == DEFAULT_QIHE_DB_PATH):
        return Path(legacy_auth_db_path)
    return Path(db_path or DEFAULT_QIHE_DB_PATH)


_SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    email         TEXT    NOT NULL UNIQUE,
    display_name  TEXT,
    password_hash TEXT    NOT NULL,
    created_at    TEXT    NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

CREATE TABLE IF NOT EXISTS jobs (
    job_id          TEXT    PRIMARY KEY,
    owner_user_id   INTEGER NOT NULL,
    mode            TEXT    NOT NULL,
    status          TEXT    NOT NULL DEFAULT 'queued',
    progress        INTEGER NOT NULL DEFAULT 0,
    current_step    TEXT,
    steps_json      TEXT    NOT NULL DEFAULT '[]',
    source_text     TEXT    NOT NULL DEFAULT '',
    file_id         TEXT,
    review_perspective TEXT,
    metadata_json   TEXT    NOT NULL DEFAULT '{}',
    result_json     TEXT,
    error_code      TEXT,
    error_message   TEXT,
    created_at      TEXT    NOT NULL,
    updated_at      TEXT    NOT NULL,
    FOREIGN KEY (owner_user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_jobs_owner ON jobs(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);

CREATE TABLE IF NOT EXISTS email_verification_codes (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    email       TEXT    NOT NULL,
    code_hash   TEXT    NOT NULL,
    expires_at  TEXT    NOT NULL,
    attempts    INTEGER NOT NULL DEFAULT 0,
    consumed_at TEXT,
    created_at  TEXT    NOT NULL,
    ip_hash     TEXT
);

CREATE INDEX IF NOT EXISTS idx_vcodes_email ON email_verification_codes(email);

CREATE TABLE IF NOT EXISTS user_credits (
    user_id    INTEGER PRIMARY KEY,
    balance    INTEGER NOT NULL DEFAULT 0,
    created_at TEXT    NOT NULL,
    updated_at TEXT    NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS credit_transactions (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id      INTEGER NOT NULL,
    amount       INTEGER NOT NULL,
    reason       TEXT    NOT NULL,
    reference_id TEXT,
    job_id       TEXT,
    created_at   TEXT    NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_ctrans_user ON credit_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_ctrans_job ON credit_transactions(job_id);

CREATE TABLE IF NOT EXISTS activation_codes (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    code_hash   TEXT    NOT NULL UNIQUE,
    credits     INTEGER NOT NULL,
    redeemed_by INTEGER,
    redeemed_at TEXT,
    expires_at  TEXT,
    created_at  TEXT    NOT NULL,
    FOREIGN KEY (redeemed_by) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS storekit_transactions (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id        INTEGER NOT NULL,
    transaction_id TEXT    NOT NULL UNIQUE,
    product_id     TEXT    NOT NULL,
    credits        INTEGER NOT NULL,
    raw_payload    TEXT,
    created_at     TEXT    NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_sktrans_user ON storekit_transactions(user_id);
"""


def _ensure_jobs_columns(conn: sqlite3.Connection) -> None:
    columns = {str(row["name"]) for row in conn.execute("PRAGMA table_info(jobs)").fetchall()}
    if "file_id" not in columns:
        conn.execute("ALTER TABLE jobs ADD COLUMN file_id TEXT")
    if "review_perspective" not in columns:
        conn.execute("ALTER TABLE jobs ADD COLUMN review_perspective TEXT")
