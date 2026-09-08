"""Shared FastAPI dependencies for engine providers."""

from functools import lru_cache

from app.agents.reasoning import ReasoningProvider, build_reasoning_provider
from app.core.config import settings
from app.perception.provider import PerceptionProvider, build_perception_provider
from app.routing.engine import NotConfiguredRouteEngine, RouteEngine
from app.services.scene import SceneGraphService


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


@lru_cache(maxsize=1)
def get_scene_service() -> SceneGraphService:
    """Return the process-wide scene graph service.

    Must be a singleton: the scene graph is explicitly stateful across
    requests (it retains recent observations per session), so a fresh
    instance per request would silently discard everything on every call.
    """
    return SceneGraphService()


@lru_cache(maxsize=1)
def get_reasoning_provider() -> ReasoningProvider:
    """Return the process-wide LLM reasoning provider."""
    return build_reasoning_provider(
        api_key=settings.GROQ_API_KEY,
        model=settings.GROQ_MODEL,
        timeout_s=settings.GROQ_TIMEOUT_S,
    )


def get_route_engine() -> RouteEngine:
    # The accessibility-aware routing engine lands in the routing
    # milestone; until then the API reports degraded mode honestly.
    return NotConfiguredRouteEngine()
