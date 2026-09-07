"""Route planning contracts for accessibility-aware routing."""

from typing import Any, Optional

from pydantic import BaseModel, Field

from .common import Location
from .profile import AccessibilityProfile


class RouteStep(BaseModel):
    """A single incremental instruction; one action at a time."""

    instruction: str
    distance_m: Optional[float] = Field(default=None, ge=0.0)
    action_type: str = "walk"
    required_accessibility: Optional[str] = None
    node_id: Optional[int] = None
    attributes: dict[str, Any] = Field(default_factory=dict)


class Route(BaseModel):
    """An accessibility-aware route with a cost breakdown."""

    route_id: str
    distance_m: float = Field(ge=0.0)
    duration_estimate_s: Optional[int] = Field(default=None, ge=0)
    accessibility_score: float = Field(default=1.0, ge=0.0, le=1.0)
    steps: list[RouteStep] = Field(default_factory=list)
    cost_breakdown: dict[str, float] = Field(default_factory=dict)


class RouteRequest(BaseModel):
    """Calculate a route from origin to destination for a user."""

    session_id: Optional[str] = None
    origin: Location
    destination: Location
    profile: AccessibilityProfile = AccessibilityProfile()


class ReplanRequest(BaseModel):
    """Replan from the current position because the route is blocked."""

    session_id: str
    current: Location
    destination: Location
    reason: Optional[str] = None
    profile: AccessibilityProfile = AccessibilityProfile()