from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration loaded from environment variables.

    Secrets are never hard-coded; they come from ``.env`` or the process
    environment (see ``.env.example`` at the repo root).
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Core
    APP_NAME: str = "AccessCopilot API"
    APP_VERSION: str = "0.1.0"
    DEBUG: bool = True

    # Server
    BACKEND_HOST: str = "0.0.0.0"
    BACKEND_PORT: int = 8000
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8080"]

    # Database
    DATABASE_URL: str = "postgresql+psycopg://user:password@localhost:5432/accesscopilot"

    # Auth
    SECRET_KEY: str = "dev-secret-change-in-production"

    # AI (filled at runtime; empty means degraded mode)
    GEMINI_API_KEY: str = ""
    LANGSMITH_API_KEY: str = ""
    LANGSMITH_PROJECT: str = "accesscopilot"

    # Model weights directory (mounted from repo in docker)
    MODELS_DIR: str = "models"

    @property
    def has_ai_capabilities(self) -> bool:
        return bool(self.GEMINI_API_KEY)


settings = Settings()