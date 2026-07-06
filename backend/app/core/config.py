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

    db_path: str = Field(default=DEFAULT_QIHE_DB_PATH, validation_alias="QIHE_DB_PATH")
    auth_db_path: str = ""
    jwt_secret: str = ""
    jwt_expires_minutes: int = 60 * 24 * 7

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
