"""Unified SQLite database connection and schema initialization.

All persistent data (auth, jobs, quotas, verification codes, etc.) shares
a single SQLite database so tables stay in one place and foreign keys work.

Connection defaults: WAL journal mode + foreign keys enabled.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from app.core.config import settings

_LOCAL_DEFAULT = Path("data/qihe.db")


def connect() -> sqlite3.Connection:
    """Open (or create) the unified SQLite database.

    Returns a connection with row_factory = sqlite3.Row, WAL mode,
    and foreign keys enabled.
    """
    db_path = _resolve_db_path()
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_schema() -> None:
    """Create all application tables if they don't already exist.

    This is safe to call on every startup – it only creates missing tables.
    New tables (jobs, credits, verification_codes, etc.) should be added here
    so a single call bootstraps the entire database.
    """
    with connect() as conn:
        conn.executescript(_SCHEMA_SQL)


def _resolve_db_path() -> Path:
    """Pick the effective database path.

    Resolution order:
    1. ``QIHE_DB_PATH`` / ``settings.db_path`` – the new unified config key.
    2. ``AUTH_DB_PATH`` / ``settings.auth_db_path`` – backward-compat fallback.
    3. ``data/qihe.db`` – local default (relative to the backend/ working dir).
    """
    if settings.db_path:
        return Path(settings.db_path)
    if settings.auth_db_path:
        return Path(settings.auth_db_path)
    return _LOCAL_DEFAULT


_SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS users (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    email       TEXT    NOT NULL UNIQUE,
    display_name TEXT,
    password_hash TEXT  NOT NULL,
    created_at  TEXT    NOT NULL
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
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    email           TEXT    NOT NULL,
    code_hash       TEXT    NOT NULL,
    expires_at      TEXT    NOT NULL,
    attempts        INTEGER NOT NULL DEFAULT 0,
    consumed_at     TEXT,
    created_at      TEXT    NOT NULL,
    ip_hash         TEXT
);

CREATE INDEX IF NOT EXISTS idx_vcodes_email ON email_verification_codes(email);

CREATE TABLE IF NOT EXISTS user_credits (
    user_id     INTEGER PRIMARY KEY,
    balance     INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT    NOT NULL,
    updated_at  TEXT    NOT NULL,
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
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    code_hash    TEXT    NOT NULL UNIQUE,
    credits      INTEGER NOT NULL,
    redeemed_by  INTEGER,
    redeemed_at  TEXT,
    expires_at   TEXT,
    created_at   TEXT    NOT NULL,
    FOREIGN KEY (redeemed_by) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS storekit_transactions (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id         INTEGER NOT NULL,
    transaction_id  TEXT    NOT NULL UNIQUE,
    product_id      TEXT    NOT NULL,
    credits         INTEGER NOT NULL,
    raw_payload     TEXT,
    created_at      TEXT    NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_sktrans_user ON storekit_transactions(user_id);
"""
