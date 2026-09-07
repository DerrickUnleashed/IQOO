"""Perception provider abstraction.

Separates REAL inference (YOLO + Depth + OCR) from MOCK/DEMO providers
so the system works end-to-end without live inference. The interface is
the contract the whole pipeline depends on.
"""

import abc
from typing import Any

from app.core.logging import stage_logger
from app.schemas.perception import Detection

_log = stage_logger("perception")


class PerceptionProvider(abc.ABC):
    """Analyzes an image frame into structured detections."""

    name: str = "perception"

    @abc.abstractmethod
    async def analyze_frame(self, frame: bytes) -> list[Detection]:
        """Return structured detections for a raw image frame."""
        raise NotImplementedError


class NotConfiguredPerceptionProvider(PerceptionProvider):
    """Degraded mode: perception engines are not running."""

    name = "not_configured"

    async def analyze_frame(self, frame: bytes) -> list[Detection]:
        _log.warning("perception engine not configured; returning empty detections")
        return []


def build_perception_provider(has_models: bool) -> PerceptionProvider:
    """Select the provider based on configuration (real engines come later)."""
    if has_models:
        # Real YOLO/Depth/OCR providers are wired in the perception milestone.
        return NotConfiguredPerceptionProvider()
    return NotConfiguredPerceptionProvider()