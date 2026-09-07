"""Object detection engines behind a stable interface.

``ObjectDetector`` is the seam between the pipeline and whatever model is
actually running. ``YoloObjectDetector`` is real inference; it refuses to
start rather than pretending, so a misconfigured deployment degrades
visibly instead of silently returning plausible-looking nonsense.
"""

from __future__ import annotations

import abc
import io
import threading
from pathlib import Path
from typing import Any

from app.core.logging import stage_logger
from app.perception import classes
from app.schemas.perception import Detection

_log = stage_logger("perception")


class PerceptionUnavailable(RuntimeError):
    """Raised when an engine cannot be started with the given configuration."""


class ObjectDetector(abc.ABC):
    """Detects accessibility-relevant objects in a single frame."""

    name: str = "detector"
    #: ``full`` or ``partial`` - how much of the vocabulary this engine covers.
    coverage: str = "partial"

    @abc.abstractmethod
    def detect(self, frame: bytes) -> list[Detection]:
        """Return detections for a decoded image frame."""
        raise NotImplementedError


class YoloObjectDetector(ObjectDetector):
    """Real YOLOv11 inference via ultralytics.

    The model is loaded lazily on first use and reused across frames;
    ultralytics predict calls are serialised because a single model handle
    is not safe to call concurrently.
    """

    name = "yolo"

    def __init__(
        self,
        weights_path: str | Path,
        confidence_threshold: float = 0.35,
        max_detections: int = 20,
        image_size: int = 640,
    ) -> None:
        self._weights_path = Path(weights_path)
        self._confidence_threshold = confidence_threshold
        self._max_detections = max_detections
        self._image_size = image_size
        self._model: Any | None = None
        self._lock = threading.Lock()
        self.coverage = "partial"

    # -- lifecycle ---------------------------------------------------------

    def load(self) -> None:
        """Load the weights, raising ``PerceptionUnavailable`` on failure."""
        if self._model is not None:
            return
        with self._lock:
            if self._model is not None:
                return
            if not self._weights_path.exists():
                raise PerceptionUnavailable(
                    f"YOLO weights not found at {self._weights_path}"
                )
            try:
                from ultralytics import YOLO  # imported lazily: heavy optional dep
            except ImportError as exc:  # pragma: no cover - depends on env
                raise PerceptionUnavailable(
                    "ultralytics is not installed; "
                    "install backend/requirements-ai.txt to enable real detection"
                ) from exc
            try:
                model = YOLO(str(self._weights_path))
            except Exception as exc:  # pragma: no cover - depends on weights
                raise PerceptionUnavailable(
                    f"failed to load YOLO weights: {exc}"
                ) from exc

            self._model = model
            self.coverage = classes.coverage_for(self._label_names(model))
            _log.info(
                "yolo detector loaded",
                weights=self._weights_path.name,
                coverage=self.coverage,
            )
            if self.coverage == "partial":
                _log.warning(
                    "yolo weights do not cover accessibility classes; "
                    "stairs/ramp/elevator will never be reported",
                    weights=self._weights_path.name,
                )

    @staticmethod
    def _label_names(model: Any) -> list[str]:
        names = getattr(model, "names", None) or {}
        if isinstance(names, dict):
            return [str(v) for v in names.values()]
        return [str(v) for v in names]

    # -- inference ---------------------------------------------------------

    def detect(self, frame: bytes) -> list[Detection]:
        if not frame:
            return []
        self.load()
        image = self._decode(frame)
        with self._lock:
            results = self._model.predict(  # type: ignore[union-attr]
                image,
                conf=self._confidence_threshold,
                imgsz=self._image_size,
                max_det=self._max_detections,
                verbose=False,
            )
        return self._to_detections(results)

    @staticmethod
    def _decode(frame: bytes) -> Any:
        try:
            from PIL import Image  # lazily imported alongside ultralytics
        except ImportError as exc:  # pragma: no cover - depends on env
            raise PerceptionUnavailable("Pillow is required to decode frames") from exc
        try:
            return Image.open(io.BytesIO(frame)).convert("RGB")
        except Exception as exc:
            raise PerceptionUnavailable(f"frame could not be decoded: {exc}") from exc

    def _to_detections(self, results: Any) -> list[Detection]:
        detections: list[Detection] = []
        for result in results or []:
            names = getattr(result, "names", {}) or {}
            width = self._frame_width(result)
            for box in getattr(result, "boxes", None) or []:
                detection = self._box_to_detection(box, names, width)
                if detection is not None:
                    detections.append(detection)
        # Most confident first, so downstream truncation keeps the best signal.
        detections.sort(key=lambda d: d.confidence, reverse=True)
        return detections

    @staticmethod
    def _frame_width(result: Any) -> float:
        shape = getattr(result, "orig_shape", None)
        if shape and len(shape) >= 2:
            return float(shape[1])
        return 0.0

    def _box_to_detection(
        self, box: Any, names: dict[Any, Any], width: float
    ) -> Detection | None:
        try:
            raw_label = str(names.get(int(box.cls), "")) if names else ""
            confidence = float(box.conf)
            # Indexing (not next(iter(...))) on purpose: an empty box raises
            # IndexError, which is handled below, whereas StopIteration would
            # escape this frame's loop entirely.
            xyxy = [float(v) for v in list(box.xyxy)[0]]  # noqa: RUF015
        except (AttributeError, IndexError, TypeError, ValueError):
            _log.warning("skipping malformed detection box")
            return None

        label = classes.normalize_label(raw_label)
        if label is None:
            return None

        return Detection(
            object_type=label,
            confidence=min(max(confidence, 0.0), 1.0),
            direction=classes.direction_from_bbox(xyxy, width),
            bbox=xyxy,
            source="yolo",
            # Depth is fused in a later stage; distance stays unknown here
            # rather than being invented from box size.
            estimated_distance_m=None,
            distance_confidence=None,
            attributes={"raw_label": raw_label, "coverage": self.coverage},
        )


__all__ = ["ObjectDetector", "PerceptionUnavailable", "YoloObjectDetector"]
