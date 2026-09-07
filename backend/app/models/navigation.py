"""Route and navigation event ORM models."""

from datetime import datetime
from typing import Optional

from sqlalchemy import JSON, DateTime, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Route(Base):
    __tablename__ = "routes"

    id: Mapped[int] = mapped_column(primary_key=True)
    session_id: Mapped[int] = mapped_column(ForeignKey("sessions.id"))
    origin: Mapped[Optional[str]] = mapped_column(String(128))
    destination: Mapped[Optional[str]] = mapped_column(String(128))
    distance_m: Mapped[Optional[float]] = mapped_column(Float)
    accessibility_score: Mapped[Optional[float]] = mapped_column(Float)
    is_active: Mapped[bool] = mapped_column(default=False)
    status: Mapped[str] = mapped_column(String(32), default="planned")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    steps: Mapped[list["RouteStep"]] = relationship(
        back_populates="route", order_by="RouteStep.seq"
    )


class RouteStep(Base):
    __tablename__ = "route_steps"

    id: Mapped[int] = mapped_column(primary_key=True)
    route_id: Mapped[int] = mapped_column(ForeignKey("routes.id", ondelete="CASCADE"))
    seq: Mapped[int] = mapped_column(Integer)
    instruction: Mapped[str] = mapped_column(String(512))
    action_type: Mapped[Optional[str]] = mapped_column(String(32))
    distance_m: Mapped[Optional[float]] = mapped_column(Float)
    node_id: Mapped[Optional[int]] = mapped_column(ForeignKey("nodes.id"))
    status: Mapped[str] = mapped_column(String(32), default="pending")
    attributes: Mapped[dict] = mapped_column(JSON, default=dict)

    route: Mapped[Route] = relationship(back_populates="steps")


class VerificationEvent(Base):
    """Result of a closed-loop camera verification of a planned action."""

    __tablename__ = "verification_events"

    id: Mapped[int] = mapped_column(primary_key=True)
    session_id: Mapped[int] = mapped_column(ForeignKey("sessions.id"))
    route_step_id: Mapped[int] = mapped_column(
        ForeignKey("route_steps.id"), nullable=True
    )
    expected_action: Mapped[Optional[str]] = mapped_column(String(256))
    verified: Mapped[bool] = mapped_column(default=False)
    confidence: Mapped[Optional[float]] = mapped_column(Float)
    replanned: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class NavigationEvent(Base):
    """Privacy-conscious analytics event for navigation sessions."""

    __tablename__ = "navigation_events"

    id: Mapped[int] = mapped_column(primary_key=True)
    session_id: Mapped[int] = mapped_column(ForeignKey("sessions.id"), index=True)
    event_type: Mapped[str] = mapped_column(String(64), index=True)
    payload: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )