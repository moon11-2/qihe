"""Unified SQLite database connection and schema initialization."""

from __future__ import annotations

import sqlite3
from pathlib import Path

from app.core.config import DEFAULT_QIHE_DB_PATH, settings


def connect() -> sqlite3.Connection:
    db_path = _resolve_db_path()
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path), timeout=10)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA busy_timeout=10000")
    return conn


def init_schema() -> None:
    with connect() as conn:
        conn.executescript(_SCHEMA_SQL)
        _ensure_jobs_columns(conn)
        _ensure_job_constraints(conn)
        _ensure_credit_transaction_constraints(conn)


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


def _ensure_job_constraints(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        UPDATE jobs
        SET error_message = CASE error_code
            WHEN 'insufficient_credits' THEN '积分不足，任务无法完成'
            WHEN 'credit_deduction_failed' THEN '积分扣除失败，请稍后重试'
            WHEN 'job_state_conflict' THEN '任务状态冲突，请重新提交'
            ELSE '任务处理失败，请稍后重试'
        END
        WHERE error_code IS NOT NULL
        """
    )
    duplicate_owners = conn.execute(
        """
        SELECT owner_user_id
        FROM jobs
        WHERE status IN ('queued', 'running')
        GROUP BY owner_user_id
        HAVING COUNT(*) > 1
        """
    ).fetchall()
    for owner in duplicate_owners:
        jobs = conn.execute(
            """
            SELECT job_id
            FROM jobs
            WHERE owner_user_id = ? AND status IN ('queued', 'running')
            ORDER BY CASE status WHEN 'running' THEN 0 ELSE 1 END, created_at, job_id
            """,
            (owner["owner_user_id"],),
        ).fetchall()
        for duplicate in jobs[1:]:
            conn.execute(
                """
                UPDATE jobs
                SET status = 'failed', error_code = 'job_state_conflict',
                    error_message = '任务状态冲突，请重新提交'
                WHERE job_id = ?
                """,
                (duplicate["job_id"],),
            )

    conn.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_jobs_owner_active
        ON jobs(owner_user_id)
        WHERE status IN ('queued', 'running')
        """
    )


def _ensure_credit_transaction_constraints(conn: sqlite3.Connection) -> None:
    # Preserve legacy ledger amounts while retaining only one job association.
    conn.execute(
        """
        UPDATE credit_transactions
        SET job_id = NULL
        WHERE job_id IS NOT NULL AND amount < 0
          AND id NOT IN (
              SELECT MIN(id)
              FROM credit_transactions
              WHERE job_id IS NOT NULL AND amount < 0
              GROUP BY job_id
          )
        """
    )
    conn.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_credit_transactions_deduction_job
        ON credit_transactions(job_id)
        WHERE job_id IS NOT NULL AND amount < 0
        """
    )
