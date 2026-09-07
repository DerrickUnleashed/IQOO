"""Accessibility-aware route engine abstraction.

Route selection minimizes accessibility cost, not just distance.
Provider isolation lets OSRM/outdoor and custom indoor routers be
swapped independently of the agent.
"""

import abc

from app.core.logging import stage_logger
from app.schemas.common import Location
from app.schemas.profile import AccessibilityProfile
from app.schemas.route import Route, RouteStep

_log = stage_logger("routes")


class RouteEngine(abc.ABC):
    """Computes accessibility-aware routes between two locations."""

    name: str = "route_engine"

    @abc.abstractmethod
    def calculate(
        self,
        origin: Location,
        destination: Location,
        profile: AccessibilityProfile,
    ) -> Route:
        raise NotImplementedError

    @abc.abstractmethod
    def replan(
        self,
        current: Location,
        destination: Location,
        profile: AccessibilityProfile,
        reason: str | None = None,
    ) -> Route:
        raise NotImplementedError


class NotConfiguredRouteEngine(RouteEngine):
    """Degraded mode: returns an explicit empty route."""

    name = "not_configured"

    def calculate(
        self,
        origin: Location,
        destination: Location,
        profile: AccessibilityProfile,
    ) -> Route:
        _log.warning(
            "route engine not configured; returning degraded route",
            origin=(origin.latitude, origin.longitude),
        )
        return Route(
            route_id="degraded",
            distance_m=0.0,
            accessibility_score=0.0,
            steps=[
                RouteStep(
                    instruction="Route planning is not available right now.",
                    action_type="info",
                )
            ],
        )

    def replan(
        self,
        current: Location,
        destination: Location,
        profile: AccessibilityProfile,
        reason: str | None = None,
    ) -> Route:
        return self.calculate(current, destination, profile)