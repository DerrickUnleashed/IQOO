"""Aggregates all API routers into a single wiring point."""

from fastapi import APIRouter

from app.api import (
    assistant,
    auth,
    buildings,
    health,
    perception,
    routes,
    users,
    verification,
)

api_router = APIRouter()
api_router.include_router(health.router, prefix="/api/v1")

api_router.include_router(auth.router, prefix="/api/v1")
api_router.include_router(users.router, prefix="/api/v1")
api_router.include_router(buildings.router, prefix="/api/v1")
api_router.include_router(perception.router, prefix="/api/v1")
api_router.include_router(routes.router, prefix="/api/v1")
api_router.include_router(verification.router, prefix="/api/v1")
api_router.include_router(assistant.router, prefix="/api/v1")


@api_router.get("/api/v1/ping")
async def ping() -> dict:
    """Minimal endpoint for connectivity checks from the mobile app."""
    return {"ping": "pong"}