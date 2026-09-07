"""Scripted perception scenarios for development and demonstrations.

These are **not** inference. Every detection produced here is synthetic and
is stamped ``synthetic=True`` so no downstream stage, log line or client can
mistake a scripted frame for a real observation.

They exist so the full PERCEIVE -> UNDERSTAND -> PLAN -> VERIFY loop can be
exercised - in tests, on a laptop with no GPU, and on stage - without live
model inference.
"""

from __future__ import annotations

import itertools
import threading
from dataclasses import dataclass, field

from app.core.logging import stage_logger
from app.perception.detector import ObjectDetector
from app.schemas.common import Direction
from app.schemas.perception import Detection

_log = stage_logger("perception")


def _detection(
    object_type: str,
    confidence: float,
    distance_m: float | None,
    direction: Direction,
    distance_confidence: float | None = None,
    text: str | None = None,
) -> Detection:
    """Build one synthetic detection, explicitly marked as such."""
    return Detection(
        object_type=object_type,
        confidence=confidence,
        estimated_distance_m=distance_m,
        distance_confidence=distance_confidence,
        direction=direction,
        source="scripted",
        text=text,
        attributes={"synthetic": True},
    )


@dataclass(frozen=True)
class Scenario:
    """A deterministic sequence of frames telling one accessibility story."""

    key: str
    title: str
    description: str
    frames: list[list[Detection]] = field(default_factory=list)

    def frame(self, index: int) -> list[Detection]:
        """Return a frame, holding on the last one once the story ends."""
        if not self.frames:
            return []
        return self.frames[min(index, len(self.frames) - 1)]


# Scenario 1 - stairs block the direct path; a ramp is available to the right.
_STAIRS_AND_RAMP = Scenario(
    key="stairs_ramp",
    title="Stairs and ramp",
    description="Stairs ahead with an accessible ramp to the right.",
    frames=[
        [
            _detection("stairs", 0.94, 5.8, Direction.front, 0.81),
            _detection("handrail", 0.72, 5.6, Direction.front, 0.64),
        ],
        [
            _detection("stairs", 0.95, 5.2, Direction.front, 0.83),
            # Low confidence on first sighting: the agent must verify, not assert.
            _detection("ramp", 0.58, 8.2, Direction.right, 0.44),
        ],
        [
            _detection("ramp", 0.88, 6.4, Direction.right, 0.71),
            _detection("stairs", 0.91, 5.0, Direction.front, 0.79),
        ],
        [
            _detection("ramp", 0.93, 2.1, Direction.front, 0.86),
        ],
    ],
)

# Scenario 2 - stairs, with signage pointing to a lift.
_STAIRS_AND_ELEVATOR = Scenario(
    key="stairs_elevator",
    title="Stairs and elevator",
    description="Stairs ahead; signage points to an accessible lift.",
    frames=[
        [
            _detection("stairs", 0.93, 4.6, Direction.front, 0.80),
            _detection("sign", 0.84, 4.4, Direction.right, 0.70, text="LIFT →"),
        ],
        [
            _detection("sign", 0.86, 3.2, Direction.right, 0.74, text="LIFT →"),
            _detection("elevator", 0.64, 11.4, Direction.right, 0.49),
        ],
        [
            _detection("elevator", 0.91, 6.0, Direction.right, 0.77),
            _detection("wheelchair_symbol", 0.79, 5.9, Direction.right, 0.70),
        ],
        [
            _detection("elevator", 0.96, 1.8, Direction.front, 0.89),
            _detection("door", 0.88, 1.7, Direction.front, 0.85),
        ],
    ],
)

# Scenario 3 - the planned corridor is blocked and the route must change.
_BLOCKED_CORRIDOR = Scenario(
    key="blocked_corridor",
    title="Blocked corridor",
    description="Construction barrier invalidates the current route.",
    frames=[
        [
            _detection("door", 0.81, 12.0, Direction.front, 0.62),
        ],
        [
            _detection("obstacle", 0.92, 3.4, Direction.front, 0.84),
            _detection("sign", 0.71, 3.6, Direction.front, 0.58, text="CLOSED"),
        ],
        [
            _detection("obstacle", 0.94, 2.6, Direction.front, 0.88),
            _detection("door", 0.76, 7.5, Direction.left, 0.61),
        ],
        [
            _detection("door", 0.89, 3.0, Direction.left, 0.79),
        ],
    ],
)

# Scenario 4 - indoor wayfinding to a numbered room.
_ROOM_NAVIGATION = Scenario(
    key="room_navigation",
    title="Room navigation",
    description="Following corridor signage to Room 204.",
    frames=[
        [
            _detection("sign", 0.87, 6.5, Direction.front, 0.66, text="201-210 →"),
        ],
        [
            _detection("door", 0.83, 4.2, Direction.left, 0.71, text="201"),
            _detection("sign", 0.80, 5.0, Direction.front, 0.63, text="204 →"),
        ],
        [
            _detection("door", 0.85, 3.1, Direction.left, 0.74, text="203"),
        ],
        [
            _detection("door", 0.92, 2.8, Direction.front, 0.81, text="204"),
            _detection("accessible_door", 0.74, 2.8, Direction.front, 0.68),
        ],
    ],
)

# Scenario 5 - outdoor crossing, where certainty matters most.
_OUTDOOR_CROSSING = Scenario(
    key="outdoor_crossing",
    title="Outdoor crossing",
    description="A signalised pedestrian crossing.",
    frames=[
        [
            _detection("crosswalk", 0.86, 7.2, Direction.front, 0.63),
            _detection("traffic_signal", 0.78, 8.0, Direction.front, 0.55),
        ],
        [
            _detection("crosswalk", 0.90, 3.5, Direction.front, 0.74),
            _detection("traffic_signal", 0.83, 4.4, Direction.front, 0.66),
            _detection("person", 0.88, 3.0, Direction.left, 0.72),
        ],
        [
            _detection("crosswalk", 0.92, 1.2, Direction.front, 0.83),
            _detection("tactile_path", 0.69, 1.0, Direction.front, 0.61),
        ],
    ],
)

SCENARIOS: dict[str, Scenario] = {
    s.key: s
    for s in (
        _STAIRS_AND_RAMP,
        _STAIRS_AND_ELEVATOR,
        _BLOCKED_CORRIDOR,
        _ROOM_NAVIGATION,
        _OUTDOOR_CROSSING,
    )
}

DEFAULT_SCENARIO = _STAIRS_AND_RAMP.key


def get_scenario(key: str | None) -> Scenario:
    """Look up a scenario, falling back to the default when unknown."""
    if key and key in SCENARIOS:
        return SCENARIOS[key]
    if key:
        _log.warning("unknown scenario requested; using default", requested=key)
    return SCENARIOS[DEFAULT_SCENARIO]


class ScriptedObjectDetector(ObjectDetector):
    """Replays a scenario frame by frame; never performs inference."""

    name = "scripted"
    coverage = "full"

    def __init__(self, scenario_key: str | None = None) -> None:
        self._scenario = get_scenario(scenario_key)
        self._counter = itertools.count()
        self._lock = threading.Lock()

    @property
    def scenario(self) -> Scenario:
        return self._scenario

    def select(self, scenario_key: str | None) -> None:
        """Switch scenarios and restart the sequence."""
        with self._lock:
            self._scenario = get_scenario(scenario_key)
            self._counter = itertools.count()

    def reset(self) -> None:
        with self._lock:
            self._counter = itertools.count()

    def detect(self, frame: bytes) -> list[Detection]:
        with self._lock:
            index = next(self._counter)
            scenario = self._scenario
        # Copies keep callers from mutating the scripted source data.
        return [d.model_copy(deep=True) for d in scenario.frame(index)]


__all__ = [
    "DEFAULT_SCENARIO",
    "SCENARIOS",
    "Scenario",
    "ScriptedObjectDetector",
    "get_scenario",
]
