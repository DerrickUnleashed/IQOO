"""Perception provider abstraction.

Separates REAL inference (YOLO, plus depth and OCR in later stages) from
SCRIPTED providers so the system works end-to-end without live inference.
The interface is the contract the whole pipeline depends on.

Three modes, never blurred:

``real``
    Live model inference. If the engine cannot start, the provider degrades
    to ``NotConfiguredPerceptionProvider`` and says so - it does not quietly
    substitute scripted data.
``scripted``
    Deterministic scenario playback for tests, offline development and
    demonstrations. Output is stamped synthetic.
``off``
    No perception. Returns nothing and reports degraded mode.
"""

from __future__ import annotations

import abc
from pathlib import Path
from typing import Any

from app.core.logging import stage_logger
from app.perception.detector import (
    ObjectDetector,
    PerceptionUnavailable,
    YoloObjectDetector,
)
from app.perception.scenarios import ScriptedObjectDetector
from app.schemas.perception import Detection

_log = stage_logger("perception")

MODE_REAL = "real"
MODE_SCRIPTED = "scripted"
MODE_OFF = "off"
MODE_AUTO = "auto"


class PerceptionProvider(abc.ABC):
    """Analyzes an image frame into structured detections."""

    name: str = "perception"
    #: One of MODE_REAL / MODE_SCRIPTED / MODE_OFF.
    mode: str = MODE_OFF
    #: ``full``, ``partial`` or ``none`` - vocabulary coverage of this engine.
    coverage: str = "none"

    @abc.abstractmethod
    async def analyze_frame(self, frame: bytes) -> list[Detection]:
        """Return structured detections for a raw image frame."""
        raise NotImplementedError

    def status(self) -> dict[str, Any]:
        """Describe this provider for readiness checks and clients."""
        return {"provider": self.name, "mode": self.mode, "coverage": self.coverage}


class NotConfiguredPerceptionProvider(PerceptionProvider):
    """Degraded mode: perception engines are not running."""

    name = "not_configured"
    mode = MODE_OFF
    coverage = "none"

    def __init__(self, reason: str = "perception engine not configured") -> None:
        self.reason = reason

    async def analyze_frame(self, frame: bytes) -> list[Detection]:
        _log.warning("perception unavailable; returning no detections",
                     reason=self.reason)
        return []

    def status(self) -> dict[str, Any]:
        return {**super().status(), "reason": self.reason}


class DetectorPerceptionProvider(PerceptionProvider):
    """Runs a detector and returns its detections unchanged.

    Depth fusion and OCR are layered on in the following stages; this
    provider deliberately does not invent the fields they will populate.
    """

    def __init__(self, detector: ObjectDetector, mode: str) -> None:
        self._detector = detector
        self.name = detector.name
        self.mode = mode
        self.coverage = detector.coverage

    @property
    def detector(self) -> ObjectDetector:
        return self._detector

    async def analyze_frame(self, frame: bytes) -> list[Detection]:
        if not frame:
            return []
        try:
            detections = self._detector.detect(frame)
        except PerceptionUnavailable as exc:
            # A frame that cannot be processed yields nothing; the caller
            # reports degraded perception rather than guessing.
            _log.error("perception engine failed on frame", reason=str(exc))
            return []
        # Coverage can only be known once real weights are loaded.
        self.coverage = self._detector.coverage
        _log.debug("frame analyzed", detections=len(detections), mode=self.mode)
        return detections


def build_perception_provider(
    mode: str = MODE_AUTO,
    weights_path: str | Path | None = None,
    scenario: str | None = None,
    confidence_threshold: float = 0.35,
) -> PerceptionProvider:
    """Select a provider from configuration.

    ``auto`` prefers real inference when weights are present and falls back
    to scripted playback otherwise, which keeps a developer machine useful
    without ever disguising scripted output as inference.
    """
    requested = (mode or MODE_AUTO).strip().lower()

    if requested == MODE_OFF:
        return NotConfiguredPerceptionProvider("perception disabled by configuration")

    if requested == MODE_SCRIPTED:
        return DetectorPerceptionProvider(
            ScriptedObjectDetector(scenario), MODE_SCRIPTED
        )

    if requested in {MODE_REAL, MODE_AUTO}:
        provider = _try_real(weights_path, confidence_threshold)
        if provider is not None:
            return provider
        if requested == MODE_REAL:
            # Explicitly asked for real inference: do not silently substitute.
            return NotConfiguredPerceptionProvider(
                "real perception requested but the detector could not be started"
            )
        _log.info("no usable weights; falling back to scripted perception")
        return DetectorPerceptionProvider(
            ScriptedObjectDetector(scenario), MODE_SCRIPTED
        )

    _log.warning("unknown perception mode; disabling perception", requested=requested)
    return NotConfiguredPerceptionProvider(f"unknown perception mode {requested!r}")


def _try_real(
    weights_path: str | Path | None, confidence_threshold: float
) -> PerceptionProvider | None:
    """Build a real detector, or return None if it cannot start."""
    if not weights_path:
        return None
    if not Path(weights_path).exists():
        _log.warning("configured YOLO weights are missing", path=str(weights_path))
        return None
    detector = YoloObjectDetector(
        weights_path, confidence_threshold=confidence_threshold
    )
    try:
        detector.load()
    except PerceptionUnavailable as exc:
        _log.warning("real perception unavailable", reason=str(exc))
        return None
    return DetectorPerceptionProvider(detector, MODE_REAL)


__all__ = [
    "MODE_AUTO",
    "MODE_OFF",
    "MODE_REAL",
    "MODE_SCRIPTED",
    "DetectorPerceptionProvider",
    "NotConfiguredPerceptionProvider",
    "PerceptionProvider",
    "build_perception_provider",
]
