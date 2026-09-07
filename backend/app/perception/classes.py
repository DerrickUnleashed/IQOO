"""Accessibility object taxonomy and detector label mapping.

The scene graph and the accessibility rules reason over a fixed vocabulary,
not over whatever labels a particular detector happens to emit. This module
is the single place that translates raw detector labels into that
vocabulary, so swapping weights never leaks model-specific names into the
rest of the pipeline.

Two kinds of weights are supported:

* **Accessibility weights** - a model fine-tuned on the classes below emits
  them directly and is passed through unchanged.
* **COCO weights** - stock YOLOv11 checkpoints are trained on COCO, which
  contains none of the accessibility features that matter here (no stairs,
  ramp, elevator or handrail). The bridge below recovers what COCO *can*
  legitimately contribute - people and path obstructions - and nothing more.
  Callers must treat that as partial coverage, not as a working
  accessibility detector; see ``coverage_for``.
"""

from typing import Final

from app.schemas.common import Direction

# The canonical vocabulary the rest of the system reasons over.
STAIRS: Final = "stairs"
RAMP: Final = "ramp"
ELEVATOR: Final = "elevator"
DOOR: Final = "door"
ACCESSIBLE_DOOR: Final = "accessible_door"
OBSTACLE: Final = "obstacle"
PERSON: Final = "person"
CROSSWALK: Final = "crosswalk"
TRAFFIC_SIGNAL: Final = "traffic_signal"
HANDRAIL: Final = "handrail"
TACTILE_PATH: Final = "tactile_path"
WHEELCHAIR_SYMBOL: Final = "wheelchair_symbol"
SIGN: Final = "sign"

ACCESSIBILITY_CLASSES: Final[frozenset[str]] = frozenset(
    {
        STAIRS,
        RAMP,
        ELEVATOR,
        DOOR,
        ACCESSIBLE_DOOR,
        OBSTACLE,
        PERSON,
        CROSSWALK,
        TRAFFIC_SIGNAL,
        HANDRAIL,
        TACTILE_PATH,
        WHEELCHAIR_SYMBOL,
        SIGN,
    }
)

# Accessibility features a COCO-trained model structurally cannot report.
# Used to describe coverage honestly rather than implying full support.
COCO_BLIND_SPOTS: Final[frozenset[str]] = frozenset(
    {STAIRS, RAMP, ELEVATOR, ACCESSIBLE_DOOR, HANDRAIL, TACTILE_PATH, WHEELCHAIR_SYMBOL}
)

# COCO label -> accessibility class. Only mappings that are defensible are
# listed; anything absent is dropped rather than guessed at.
_COCO_BRIDGE: Final[dict[str, str]] = {
    "person": PERSON,
    "traffic light": TRAFFIC_SIGNAL,
    "stop sign": SIGN,
    # Things that physically block a pedestrian path.
    "bench": OBSTACLE,
    "chair": OBSTACLE,
    "couch": OBSTACLE,
    "bed": OBSTACLE,
    "dining table": OBSTACLE,
    "potted plant": OBSTACLE,
    "suitcase": OBSTACLE,
    "backpack": OBSTACLE,
    "handbag": OBSTACLE,
    "fire hydrant": OBSTACLE,
    "bicycle": OBSTACLE,
    "motorcycle": OBSTACLE,
    "car": OBSTACLE,
    "bus": OBSTACLE,
    "truck": OBSTACLE,
    "train": OBSTACLE,
    "parking meter": OBSTACLE,
    "toilet": OBSTACLE,
    "tv": OBSTACLE,
    "refrigerator": OBSTACLE,
}


def normalize_label(label: str) -> str | None:
    """Map a raw detector label to the accessibility vocabulary.

    Returns ``None`` when the label carries no accessibility meaning, so the
    caller drops it instead of forwarding noise into the scene graph.
    """
    cleaned = label.strip().lower().replace("-", "_")
    if cleaned in ACCESSIBILITY_CLASSES:
        return cleaned
    spaced = cleaned.replace("_", " ")
    return _COCO_BRIDGE.get(spaced)


def is_accessibility_vocabulary(labels: object) -> bool:
    """True when a model's own label set already speaks our vocabulary."""
    if not labels:
        return False
    try:
        names = {str(name).strip().lower() for name in labels}
    except TypeError:
        return False
    # A fine-tuned accessibility model carries the features COCO cannot.
    return bool(names & COCO_BLIND_SPOTS)


def coverage_for(labels: object) -> str:
    """Describe how much of the vocabulary a model's labels can cover.

    ``full`` for accessibility-tuned weights, ``partial`` for COCO weights
    (people and obstructions only). This is surfaced to clients so an
    instruction is never presented as more informed than it is.
    """
    return "full" if is_accessibility_vocabulary(labels) else "partial"


def direction_from_bbox(bbox: list[float], frame_width: float) -> Direction:
    """Bucket a box into left/front/right by its horizontal centre.

    Bearing is deliberately coarse: monocular geometry does not support a
    finer claim, and spoken guidance uses these three buckets anyway.
    """
    if frame_width <= 0:
        return Direction.front
    centre_x = (bbox[0] + bbox[2]) / 2.0
    ratio = centre_x / frame_width
    if ratio < 0.33:
        return Direction.left
    if ratio > 0.67:
        return Direction.right
    return Direction.front


__all__ = [
    "ACCESSIBILITY_CLASSES",
    "COCO_BLIND_SPOTS",
    "coverage_for",
    "direction_from_bbox",
    "is_accessibility_vocabulary",
    "normalize_label",
]
