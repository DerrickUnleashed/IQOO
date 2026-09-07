"""Accessibility scene graph contracts.

The scene graph is stateful: it retains recent observations instead of
treating every camera frame as independent.
"""

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field

from .common import Direction
from .perception import Detection


class SceneObject(BaseModel):
    """A node in the scene graph derived from one or more detections."""

    id: str
    type: str
    distance_m: Optional[float] = Field(default=None, ge=0.0)
    direction: Direction = Direction.front
    accessible: Optional[bool] = None
    temporary_blockage: bool = False
    confidence: float = Field(default=0.5, ge=0.0, le=1.0)
    currently_visible: bool = True
    state: Optional[str] = None  # e.g. "closed" for doors
    attributes: dict[str, Any] = Field(default_factory=dict)


class SceneUpdate(BaseModel):
    """Incremental update of the live scene graph."""

    session_id: str
    detections: list[Detection] = Field(default_factory=list)
    location: Optional[dict[str, Any]] = None


class SceneUpdateResponse(BaseModel):
    """The merged scene after applying the update."""

    session_id: str
    scene_objects: list[SceneObject]
    updated_at: datetime
    observation_id: Optional[int] = None