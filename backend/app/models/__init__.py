"""Import all ORM models so Alembic autogenerate sees the full metadata."""

from app.models.graph import (
    AccessibilityFeature,
    Building,
    Edge,
    Floor,
    Node,
)
from app.models.navigation import (
    NavigationEvent,
    Route,
    RouteStep,
    VerificationEvent,
)
from app.models.scene import DetectedObject, SceneObservation
from app.models.user import (
    AccessibilityPreference,
    Session,
    User,
    UserProfile,
)

__all__ = [
    "AccessibilityFeature",
    "AccessibilityPreference",
    "Building",
    "DetectedObject",
    "Edge",
    "Floor",
    "NavigationEvent",
    "Node",
    "Route",
    "RouteStep",
    "SceneObservation",
    "Session",
    "User",
    "UserProfile",
    "VerificationEvent",
]