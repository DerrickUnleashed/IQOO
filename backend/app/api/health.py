"""Health and readiness endpoints for liveness probes and observability."""

from fastapi import APIRouter

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

router = APIRouter(tags=["health"])


@router.get("/health")
async def health() -> dict:
    """Basic liveness check."""
    return {"status": "ok", "service": "accesscopilot"}


@router.get("/readiness")
async def readiness() -> dict:
    """Readiness check including capability info.

    ``ai_enabled`` reflects whether cloud AI capabilities (Gemini) are
    configured; the service degrades gracefully when it is false.
    """
    return {
        "status": "ready",
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "ai_enabled": settings.has_ai_capabilities,
        "backend_debug": settings.DEBUG,
    }