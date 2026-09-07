"""Shared FastAPI dependencies for engine providers."""

from fastapi import Depends

from app.perception.provider import PerceptionProvider
from app.routing.engine import NotConfiguredRouteEngine, RouteEngine


def get_perception_provider() -> PerceptionProvider:
    # Real YOLO/Depth/OCR providers are wired in the perception
    # milestone; until then the API reports degraded mode honestly.
    return build_not_configured()


def build_not_configured() -> PerceptionProvider:
    from app.perception.provider import NotConfiguredPerceptionProvider

    return NotConfiguredPerceptionProvider()


def get_route_engine() -> RouteEngine:
    # The accessibility-aware routing engine lands in the routing
    # milestone; until then the API reports degraded mode honestly.
    return NotConfiguredRouteEngine()