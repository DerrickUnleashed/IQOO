"""Shared primitive contracts used across the API."""

from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class Direction(str, Enum):
    front = "front"
    left = "left"
    right = "right"
    behind = "behind"


class Confidence(BaseModel):
    """A perception estimate never claims certainty."""

    value: float = Field(ge=0.0, le=1.0)
    label: str = "unknown"

    @property
    def is_high(self) -> bool:
        return self.value >= 0.8

    @property
    def is_low(self) -> bool:
        return self.value < 0.5


class Location(BaseModel):
    """A geographic position (WGS84)."""

    latitude: float = Field(ge=-90.0, le=90.0)
    longitude: float = Field(ge=-180.0, le=180.0)
    accuracy_m: Optional[float] = Field(default=None, ge=0.0)
    floor_level: Optional[int] = Field(default=None)


class DistanceEstimate(BaseModel):
    """Distance plus its own confidence, so uncertainty propagates."""

    meters: Optional[float] = Field(default=None, ge=0.0)
    confidence: Confidence = Confidence(value=0.0)


__all__ = [
    "Confidence",
    "Direction",
    "DistanceEstimate",
    "Location",
]