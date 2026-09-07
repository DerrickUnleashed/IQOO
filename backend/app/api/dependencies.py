"""Shared FastAPI dependencies for engine providers."""

from functools import lru_cache

from app.core.config import settings
from app.perception.provider import PerceptionProvider, build_perception_provider
from app.routing.engine import NotConfiguredRouteEngine, RouteEngine


@lru_cache(maxsize=1)
def get_perception_provider() -> PerceptionProvider:
    """Return the process-wide perception provider.

    Cached because loading model weights is expensive and the provider is
    stateful (scripted playback advances frame by frame).
    """
    return build_perception_provider(
        mode=settings.PERCEPTION_MODE,
        weights_path=settings.yolo_weights_path,
        scenario=settings.DEMO_SCENARIO,
        confidence_threshold=settings.YOLO_CONFIDENCE_THRESHOLD,
    )


def reset_perception_provider() -> None:
    """Drop the cached provider so configuration changes take effect."""
    get_perception_provider.cache_clear()


def get_route_engine() -> RouteEngine:
    # The accessibility-aware routing engine lands in the routing
    # milestone; until then the API reports degraded mode honestly.
    return NotConfiguredRouteEngine()
