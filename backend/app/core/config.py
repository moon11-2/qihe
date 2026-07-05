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

    auth_db_path: str = "/tmp/qihe-auth.sqlite3"
    jwt_secret: str = ""
    jwt_expires_minutes: int = 60 * 24 * 7

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
