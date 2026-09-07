"""Tests for the object detection pipeline.

Real inference is not exercised here (weights and torch are optional); what
is tested is the contract every caller depends on: label normalisation,
bearing, provider mode selection, and the refusal to disguise scripted
output as inference.
"""

import asyncio
from pathlib import Path

import pytest

from app.perception import classes
from app.perception.detector import (
    ObjectDetector,
    PerceptionUnavailable,
    YoloObjectDetector,
)
from app.perception.provider import (
    MODE_OFF,
    MODE_REAL,
    MODE_SCRIPTED,
    DetectorPerceptionProvider,
    NotConfiguredPerceptionProvider,
    build_perception_provider,
)
from app.perception.scenarios import (
    SCENARIOS,
    ScriptedObjectDetector,
    get_scenario,
)
from app.schemas.common import Direction
from app.schemas.perception import Detection

# --- label taxonomy -------------------------------------------------------


@pytest.mark.parametrize("label", sorted(classes.ACCESSIBILITY_CLASSES))
def test_vocabulary_labels_pass_through(label: str) -> None:
    assert classes.normalize_label(label) == label


@pytest.mark.parametrize(
    "raw, expected",
    [
        ("person", "person"),
        ("traffic light", "traffic_signal"),
        ("stop sign", "sign"),
        ("bench", "obstacle"),
        ("car", "obstacle"),
        # Case and separators are tolerated.
        ("Traffic Light", "traffic_signal"),
        ("traffic_light", "traffic_signal"),
        ("STAIRS", "stairs"),
        ("accessible-door", "accessible_door"),
    ],
)
def test_coco_labels_map_into_the_vocabulary(raw: str, expected: str) -> None:
    assert classes.normalize_label(raw) == expected


@pytest.mark.parametrize("raw", ["banana", "kite", "toothbrush", "", "   "])
def test_meaningless_labels_are_dropped(raw: str) -> None:
    """Unmapped COCO classes are dropped, not forwarded as noise."""
    assert classes.normalize_label(raw) is None


def test_coco_weights_report_partial_coverage() -> None:
    coco_names = ["person", "bicycle", "car", "traffic light", "bench"]
    assert classes.coverage_for(coco_names) == "partial"
    assert classes.is_accessibility_vocabulary(coco_names) is False


def test_accessibility_weights_report_full_coverage() -> None:
    tuned = ["stairs", "ramp", "elevator", "handrail", "door"]
    assert classes.coverage_for(tuned) == "full"
    assert classes.is_accessibility_vocabulary(tuned) is True


def test_coverage_of_no_labels_is_partial() -> None:
    assert classes.coverage_for([]) == "partial"
    assert classes.coverage_for(None) == "partial"


# --- bearing --------------------------------------------------------------


@pytest.mark.parametrize(
    "bbox, expected",
    [
        ([0.0, 0.0, 100.0, 100.0], Direction.left),
        ([440.0, 0.0, 640.0, 100.0], Direction.right),
        ([270.0, 0.0, 370.0, 100.0], Direction.front),
    ],
)
def test_direction_is_bucketed_from_the_box_centre(
    bbox: list[float], expected: Direction
) -> None:
    assert classes.direction_from_bbox(bbox, 640.0) == expected


def test_direction_defaults_to_front_without_a_frame_width() -> None:
    """An unknown frame width must not produce a fabricated bearing."""
    assert classes.direction_from_bbox([0.0, 0.0, 10.0, 10.0], 0.0) == Direction.front


# --- scripted scenarios ---------------------------------------------------


def test_all_documented_scenarios_exist() -> None:
    assert set(SCENARIOS) == {
        "stairs_ramp",
        "stairs_elevator",
        "blocked_corridor",
        "room_navigation",
        "outdoor_crossing",
    }


def test_scenario_detections_use_the_shared_vocabulary() -> None:
    for scenario in SCENARIOS.values():
        for frame in scenario.frames:
            for detection in frame:
                assert detection.object_type in classes.ACCESSIBILITY_CLASSES, (
                    f"{scenario.key} emits unknown class {detection.object_type}"
                )


def test_scripted_detections_are_marked_synthetic() -> None:
    """Nothing scripted may be mistaken for a real observation."""
    for scenario in SCENARIOS.values():
        for frame in scenario.frames:
            for detection in frame:
                assert detection.source == "scripted"
                assert detection.attributes["synthetic"] is True


def test_unknown_scenario_falls_back_to_the_default() -> None:
    assert get_scenario("nope").key == "stairs_ramp"
    assert get_scenario(None).key == "stairs_ramp"


def test_scripted_detector_advances_through_frames() -> None:
    detector = ScriptedObjectDetector("stairs_ramp")
    first = detector.detect(b"frame")
    second = detector.detect(b"frame")
    assert [d.object_type for d in first] == ["stairs", "handrail"]
    assert "ramp" in [d.object_type for d in second]


def test_scripted_detector_holds_on_the_last_frame() -> None:
    detector = ScriptedObjectDetector("stairs_ramp")
    frames = [detector.detect(b"f") for _ in range(10)]
    assert frames[-1] == frames[-2]
    assert frames[-1], "the story should end on a real frame, not an empty one"


def test_scripted_detector_reset_restarts_the_sequence() -> None:
    detector = ScriptedObjectDetector("stairs_ramp")
    first = detector.detect(b"f")
    detector.detect(b"f")
    detector.reset()
    assert detector.detect(b"f") == first


def test_scripted_detector_can_switch_scenarios() -> None:
    detector = ScriptedObjectDetector("stairs_ramp")
    detector.detect(b"f")
    detector.select("outdoor_crossing")
    assert detector.scenario.key == "outdoor_crossing"
    assert "crosswalk" in [d.object_type for d in detector.detect(b"f")]


def test_scripted_output_cannot_be_mutated_by_callers() -> None:
    detector = ScriptedObjectDetector("stairs_ramp")
    detector.detect(b"f")[0].confidence = 0.01
    detector.reset()
    assert detector.detect(b"f")[0].confidence == pytest.approx(0.94)


# --- provider selection ---------------------------------------------------


class _StubDetector(ObjectDetector):
    name = "stub"
    coverage = "full"

    def __init__(self, detections: list[Detection] | None = None) -> None:
        self.detections = detections or []
        self.calls = 0

    def detect(self, frame: bytes) -> list[Detection]:
        self.calls += 1
        return self.detections


class _FailingDetector(ObjectDetector):
    name = "failing"

    def detect(self, frame: bytes) -> list[Detection]:
        raise PerceptionUnavailable("engine exploded")


def test_off_mode_disables_perception() -> None:
    provider = build_perception_provider(mode=MODE_OFF)
    assert isinstance(provider, NotConfiguredPerceptionProvider)
    assert provider.status()["mode"] == MODE_OFF
    assert asyncio.run(provider.analyze_frame(b"frame")) == []


def test_scripted_mode_reports_itself_as_scripted() -> None:
    provider = build_perception_provider(mode=MODE_SCRIPTED, scenario="stairs_ramp")
    status = provider.status()
    assert status["mode"] == MODE_SCRIPTED
    detections = asyncio.run(provider.analyze_frame(b"frame"))
    assert detections and all(d.source == "scripted" for d in detections)


def test_real_mode_degrades_rather_than_substituting_scripted_data(
    tmp_path: Path,
) -> None:
    """An explicit request for real inference must never be faked."""
    provider = build_perception_provider(
        mode=MODE_REAL, weights_path=tmp_path / "absent.pt"
    )
    assert isinstance(provider, NotConfiguredPerceptionProvider)
    assert provider.status()["mode"] == MODE_OFF
    assert asyncio.run(provider.analyze_frame(b"frame")) == []


def test_auto_mode_falls_back_to_scripted_when_weights_are_missing(
    tmp_path: Path,
) -> None:
    provider = build_perception_provider(
        mode="auto", weights_path=tmp_path / "absent.pt"
    )
    assert provider.status()["mode"] == MODE_SCRIPTED


def test_unknown_mode_disables_perception() -> None:
    provider = build_perception_provider(mode="wishful-thinking")
    assert provider.status()["mode"] == MODE_OFF


def test_provider_returns_nothing_for_an_empty_frame() -> None:
    detector = _StubDetector([Detection(object_type="stairs", confidence=0.9)])
    provider = DetectorPerceptionProvider(detector, MODE_REAL)
    assert asyncio.run(provider.analyze_frame(b"")) == []
    assert detector.calls == 0, "an empty frame should not reach the engine"


def test_provider_survives_an_engine_failure() -> None:
    """A failing engine yields no detections instead of raising at the API."""
    provider = DetectorPerceptionProvider(_FailingDetector(), MODE_REAL)
    assert asyncio.run(provider.analyze_frame(b"frame")) == []


# --- real detector guardrails ---------------------------------------------


def test_yolo_detector_refuses_missing_weights(tmp_path: Path) -> None:
    detector = YoloObjectDetector(tmp_path / "missing.pt")
    with pytest.raises(PerceptionUnavailable, match="weights not found"):
        detector.load()


def test_yolo_detector_returns_nothing_for_an_empty_frame(tmp_path: Path) -> None:
    """No weights are loaded for an empty frame, so this must not raise."""
    detector = YoloObjectDetector(tmp_path / "missing.pt")
    assert detector.detect(b"") == []


def test_yolo_detector_never_invents_a_distance() -> None:
    """Distance comes from depth estimation, not from box geometry."""
    detector = YoloObjectDetector("unused.pt")
    box = _FakeBox(cls=0, conf=0.9, xyxy=[0.0, 0.0, 100.0, 200.0])
    result = _FakeResult(names={0: "person"}, boxes=[box], orig_shape=(480, 640))

    detections = detector._to_detections([result])

    assert len(detections) == 1
    assert detections[0].object_type == "person"
    assert detections[0].estimated_distance_m is None
    assert detections[0].distance_confidence is None
    assert detections[0].source == "yolo"


def test_yolo_detector_drops_unmapped_and_malformed_boxes() -> None:
    detector = YoloObjectDetector("unused.pt")
    result = _FakeResult(
        names={0: "person", 1: "banana"},
        boxes=[
            _FakeBox(cls=1, conf=0.9, xyxy=[0.0, 0.0, 10.0, 10.0]),  # unmapped
            _FakeBox(cls=0, conf=0.5, xyxy=[]),  # malformed
            _FakeBox(cls=0, conf=0.8, xyxy=[0.0, 0.0, 10.0, 10.0]),  # kept
        ],
        orig_shape=(480, 640),
    )
    detections = detector._to_detections([result])
    assert [d.object_type for d in detections] == ["person"]


def test_yolo_detections_are_ordered_by_confidence() -> None:
    detector = YoloObjectDetector("unused.pt")
    result = _FakeResult(
        names={0: "person", 1: "bench"},
        boxes=[
            _FakeBox(cls=0, conf=0.4, xyxy=[0.0, 0.0, 10.0, 10.0]),
            _FakeBox(cls=1, conf=0.9, xyxy=[0.0, 0.0, 10.0, 10.0]),
        ],
        orig_shape=(480, 640),
    )
    confidences = [d.confidence for d in detector._to_detections([result])]
    assert confidences == sorted(confidences, reverse=True)


class _FakeBox:
    """Minimal stand-in for an ultralytics Boxes row."""

    def __init__(self, cls: int, conf: float, xyxy: list[float]) -> None:
        self.cls = cls
        self.conf = conf
        self.xyxy = [xyxy] if xyxy else []


class _FakeResult:
    """Minimal stand-in for an ultralytics Results object."""

    def __init__(
        self, names: dict[int, str], boxes: list[_FakeBox], orig_shape: tuple[int, int]
    ) -> None:
        self.names = names
        self.boxes = boxes
        self.orig_shape = orig_shape
