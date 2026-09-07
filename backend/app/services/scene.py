"""Stateful, in-memory accessibility scene graph.

Retains recent observations per session rather than treating frames as
independent. This is the foundation the agent reasons over; a durable
PostGIS-backed version is layered in the scene-graph milestone.
"""

import threading
import uuid
from collections import OrderedDict
from datetime import datetime, timezone
from typing import Any

from app.schemas.common import Direction
from app.schemas.perception import Detection
from app.schemas.scene import SceneObject

_MAX_OBJECTS_PER_SESSION = 24


class SceneGraphService:
    """Holds per-session scene state with bounded memory."""

    def __init__(self) -> None:
        self._sessions: dict[str, OrderedDict[str, SceneObject]] = {}
        self._lock = threading.Lock()

    def apply(
        self, session_id: str, detections: list[Detection]
    ) -> dict[str, Any]:
        with self._lock:
            graph = self._sessions.setdefault(session_id, OrderedDict())

            for detection in detections:
                key = detection.object_type
                # Merge: newer higher-confidence detection of the same
                # class wins, but keep the older observation in history.
                existing = graph.get(key)
                if existing is None or detection.confidence >= existing.confidence:
                    graph[key] = self._to_scene_object(detection)

            # Soft-bounds memory to the most recent, most relevant objects.
            while len(graph) > _MAX_OBJECTS_PER_SESSION:
                graph.popitem(last=False)

            self._mark_visibility(graph, detections)

            return {
                "session_id": session_id,
                "scene_objects": list(graph.values()),
                "updated_at": datetime.now(timezone.utc),
                "observation_id": None,
            }

    def get(self, session_id: str) -> list[SceneObject]:
        with self._lock:
            return list(self._sessions.get(session_id, OrderedDict()).values())

    def clear(self, session_id: str) -> None:
        with self._lock:
            self._sessions.pop(session_id, None)

    @staticmethod
    def _to_scene_object(d: Detection) -> SceneObject:
        accessible = SceneGraphService._accessibility_hint(d.object_type)
        return SceneObject(
            id=f"{d.object_type}_{uuid.uuid4().hex[:6]}",
            type=d.object_type,
            distance_m=d.estimated_distance_m,
            direction=d.direction if isinstance(d.direction, Direction) else Direction.front,
            accessible=accessible,
            temporary_blockage=d.object_type in {"obstacle", "barrier"},
            confidence=d.confidence,
            currently_visible=True,
            state=d.text,
            attributes=dict(d.attributes),
        )

    @staticmethod
    def _accessibility_hint(object_type: str) -> bool | None:
        inaccessible = {"stairs", "obstacle", "barrier", "construction"}
        accessible = {"ramp", "elevator", "handrail", "tactile_path", "crosswalk"}
        if object_type in inaccessible:
            return False
        if object_type in accessible:
            return True
        return None  # unknown door/sign/etc.

    @staticmethod
    def _mark_visibility(
        graph: "OrderedDict[str, SceneObject]",
        detections: list[Detection],
    ) -> None:
        """Mark objects seen again as visible, degrade confidence of others."""
        seen = {d.object_type for d in detections}
        for key, obj in graph.items():
            if key in seen:
                obj.currently_visible = True
                continue
            # Slight confidence decay for recently-unseen objects.
            obj.confidence = max(0.0, obj.confidence - 0.05)