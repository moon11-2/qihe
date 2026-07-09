from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_DIR = Path(__file__).resolve().parents[2]
DEFAULT_QIHE_DB_PATH = str(BACKEND_DIR / "data" / "qihe.db")


class Settings(BaseSettings):
    app_env: str = "local"
    api_prefix: str = "/api"

    qwen_api_key: str = ""
    qwen_api_base_url: str = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    qwen_model: str = "qwen-plus"

    dify_api_key: str = ""
    dify_api_base_url: str = "https://api.dify.ai/v1"

    max_upload_mb: int = 20

    # Unified DB path. Production should set QIHE_DB_PATH to a persistent path,
    # for example /var/lib/qihe/qihe.db.
    db_path: str = Field(default=DEFAULT_QIHE_DB_PATH, validation_alias="QIHE_DB_PATH")
    # Deprecated compatibility only; prefer QIHE_DB_PATH for new deployments.
    auth_db_path: str = Field(default="", validation_alias="AUTH_DB_PATH")
    jwt_secret: str = ""
    jwt_expires_minutes: int = 60 * 24 * 7

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        populate_by_name=True,
    )


settings = Settings()
