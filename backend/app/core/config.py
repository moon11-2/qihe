from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: str = "local"
    api_prefix: str = "/api"

    qwen_api_key: str = ""
    qwen_api_base_url: str = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    qwen_model: str = "qwen-plus"

    dify_api_key: str = ""
    dify_api_base_url: str = "https://api.dify.ai/v1"

    max_upload_mb: int = 20

    # Unified DB path (QIHE_DB_PATH). Local default: data/qihe.db (relative to backend/).
    # Production: set to an absolute path, e.g. /var/lib/qihe/qihe.db.
    db_path: str = Field(default="", alias="QIHE_DB_PATH")
    # Deprecated – kept for backward compatibility. Prefer QIHE_DB_PATH.
    auth_db_path: str = Field(default="", alias="AUTH_DB_PATH")

    jwt_secret: str = ""
    jwt_expires_minutes: int = 60 * 24 * 7

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        populate_by_name=True,
    )


settings = Settings()
