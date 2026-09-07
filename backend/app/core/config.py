import json
from pathlib import Path
from typing import Annotated, Any

from pydantic import field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

# The canonical .env lives at the repo root, one level above ``backend/``.
# Resolving it from this file (rather than the process working directory)
# means ``cd backend && pytest`` and ``uvicorn`` from the repo root load the
# same configuration instead of silently falling back to the defaults below.
_REPO_ROOT = Path(__file__).resolve().parents[3]
_ENV_FILES = (_REPO_ROOT / ".env", Path(".env"))


class Settings(BaseSettings):
    """Application configuration loaded from environment variables.

    Secrets are never hard-coded; they come from ``.env`` or the process
    environment (see ``.env.example`` at the repo root).
    """

    model_config = SettingsConfigDict(
        env_file=_ENV_FILES,
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
    # ``NoDecode`` stops pydantic-settings from JSON-parsing the raw value so
    # the validator below can accept the documented comma-separated form.
    ALLOWED_ORIGINS: Annotated[list[str], NoDecode] = [
        "http://localhost:3000",
        "http://localhost:8080",
    ]

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

    # Perception: auto | real | scripted | off.
    # ``auto`` uses real inference when weights are present and falls back to
    # scripted scenario playback otherwise. ``real`` never falls back.
    PERCEPTION_MODE: str = "auto"
    YOLO_WEIGHTS: str = "yolo/yolo11n.pt"  # relative to MODELS_DIR
    YOLO_CONFIDENCE_THRESHOLD: float = 0.35
    DEMO_SCENARIO: str = "stairs_ramp"

    @property
    def models_path(self) -> Path:
        """Absolute path to the model weights directory."""
        configured = Path(self.MODELS_DIR)
        if configured.is_absolute():
            return configured
        return _REPO_ROOT / configured

    @property
    def yolo_weights_path(self) -> Path:
        """Absolute path to the configured YOLO checkpoint."""
        configured = Path(self.YOLO_WEIGHTS)
        if configured.is_absolute():
            return configured
        return self.models_path / configured

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def _split_origins(cls, value: Any) -> Any:
        """Accept both the comma-separated and JSON list forms.

        ``.env.example`` documents ``a,b``; JSON is still accepted so an
        existing deployment setting a list literal keeps working.
        """
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return []
            if stripped.startswith("["):
                return json.loads(stripped)
            return [item.strip() for item in stripped.split(",") if item.strip()]
        return value

    @property
    def has_ai_capabilities(self) -> bool:
        return bool(self.GEMINI_API_KEY)


settings = Settings()