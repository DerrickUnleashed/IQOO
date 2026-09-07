"""Aggregates all API routers into a single wiring point."""

from fastapi import APIRouter

from app.api import health

api_router = APIRouter()
api_router.include_router(health.router, prefix="/api/v1")


@api_router.get("/api/v1/ping")
async def ping() -> dict:
    """Minimal endpoint for connectivity checks from the mobile app."""
    return {"ping": "pong"}