"""Unit tests for the stateful scene graph service."""

from app.schemas.common import Direction
from app.schemas.perception import Detection
from app.services.scene import SceneGraphService


def _det(
    object_type: str,
    confidence: float = 0.9,
    distance: float = 2.0,
) -> Detection:
    return Detection(
        object_type=object_type,
        confidence=confidence,
        estimated_distance_m=distance,
        direction=Direction.front,
        source="test",
    )


def test_initial_update_populates_scene() -> None:
    service = SceneGraphService()
    result = service.apply(
        "s1", [_det("door"), _det("stairs")]
    )
    types = {o.type for o in result["scene_objects"]}
    assert types == {"door", "stairs"}


def test_merge_keeps_higher_confidence_detection() -> None:
    service = SceneGraphService()
    service.apply("s1", [_det("door", confidence=0.6)])
    result = service.apply("s1", [_det("door", confidence=0.95)])
    door = next(o for o in result["scene_objects"] if o.type == "door")
    assert door.confidence == 0.95


def test_unseen_objects_decay_confidence() -> None:
    service = SceneGraphService()
    service.apply("s1", [_det("door", confidence=0.9), _det("ramp", confidence=0.9)])
    result = service.apply("s1", [_det("ramp", confidence=0.9)])
    door = next(o for o in result["scene_objects"] if o.type == "door")
    assert door.confidence < 0.9


def test_blockage_marked_for_obstacles() -> None:
    service = SceneGraphService()
    result = service.apply("s1", [_det("obstacle")])
    obstacle = next(o for o in result["scene_objects"] if o.type == "obstacle")
    assert obstacle.temporary_blockage is True


def test_sessions_are_isolated() -> None:
    service = SceneGraphService()
    service.apply("s1", [_det("door")])
    result = service.apply("s2", [_det("ramp")])
    assert all(o.type == "ramp" for o in result["scene_objects"])