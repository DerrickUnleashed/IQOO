"""Perception and OCR detection contracts.

Mirrors the exact shape used by the mobile app so both sides agree on
the scene representation without arbitrary JSON.
"""

from typing import Any, Optional

from pydantic import BaseModel, Field

from .common import Confidence, Direction, DistanceEstimate


class Detection(BaseModel):
    """A single perceived object, fused from detection + depth + OCR."""

    object_type: str
    confidence: float = Field(ge=0.0, le=1.0)
    estimated_distance_m: Optional[float] = Field(default=None, ge=0.0)
    distance_confidence: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    direction: Direction = Direction.front
    bbox: Optional[list[float]] = Field(default=None, min_length=4, max_length=4)
    text: Optional[str] = Field(default=None)
    source: str = "detector"  # yolo | depth | ocr | fused
    attributes: dict[str, Any] = Field(default_factory=dict)


class AnalyzeFrameRequest(BaseModel):
    """A single frame sent for analysis (frames are throttled client-side)."""

    frame_id: str
    session_id: str
    encoded_frame: Optional[bytes] = None
    source: Optional[str] = None


class AnalyzeFrameResponse(BaseModel):
    """Structured result; raw frames are never stored."""

    frame_id: str
    detections: list[Detection]
    scene_summary: dict[str, Any] = Field(default_factory=dict)
    processing_ms: int = Field(default=0, ge=0)