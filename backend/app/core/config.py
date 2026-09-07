from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql://user:password@localhost:5432/accesscopilot"
    GEMINI_API_KEY: str = ""
    SECRET_KEY: str = "dev-secret-change-in-production"
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:8080"]
    BACKEND_HOST: str = "0.0.0.0"
    BACKEND_PORT: int = 8000
    BACKEND_DEBUG: bool = True
    LANGSMITH_API_KEY: str = ""
    LANGSMITH_PROJECT: str = "accesscopilot"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
