"""Perception and scene observation ORM models."""

from datetime import datetime
from typing import Optional

from sqlalchemy import JSON, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class SceneObservation(Base):
    """A structured snapshot of what the camera perceived at a moment.

    Raw frames are discarded; only structured information is stored
    (data minimization).
    """

    __tablename__ = "scene_observations"

    id: Mapped[int] = mapped_column(primary_key=True)
    session_id: Mapped[int] = mapped_column(
        ForeignKey("sessions.id", ondelete="CASCADE"), index=True
    )
    captured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    location: Mapped[Optional[str]] = mapped_column(
        # PostGIS point; kept as Geometry via raw type for simplicity in tests.
        String
    )
    context: Mapped[dict] = mapped_column(JSON, default=dict)

    detections: Mapped[list["DetectedObject"]] = relationship(
        back_populates="observation"
    )


class DetectedObject(Base):
    """A single perceived object with confidence and distance estimates."""

    __tablename__ = "detected_objects"

    id: Mapped[int] = mapped_column(primary_key=True)
    observation_id: Mapped[int] = mapped_column(
        ForeignKey("scene_observations.id", ondelete="CASCADE")
    )
    object_type: Mapped[str] = mapped_column(String(64), index=True)
    confidence: Mapped[Optional[float]] = mapped_column(Float)
    estimated_distance_m: Mapped[Optional[float]] = mapped_column(Float)
    distance_confidence: Mapped[Optional[float]] = mapped_column(Float)
    direction: Mapped[Optional[str]] = mapped_column(String(16))  # front|left|right
    bbox: Mapped[Optional[dict]] = mapped_column(JSON)
    attributes: Mapped[dict] = mapped_column(JSON, default=dict)

    observation: Mapped[SceneObservation] = relationship(back_populates="detections")