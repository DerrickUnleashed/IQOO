"""Indoor accessibility graph ORM models.

Structure:

    Building
     ├── Floor
     │    ├── Room
     │    ├── Corridor / Node
     │    ├── Elevator / Node
     │    ├── Ramp / Node
     │    ├── Stairs / Node
     │    └── Door / Node (edge attributes)

Graph edges carry accessibility-relevant attributes (slope, width,
surface, temporary blockages) so the route engine can compute an
accessibility-aware cost rather than plain distance.
"""

from datetime import datetime
from typing import Optional

from geoalchemy2 import Geometry
from sqlalchemy import (
    JSON,
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Building(Base):
    __tablename__ = "buildings"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(128), index=True)
    address: Mapped[Optional[str]] = mapped_column(String(256))
    geolocation: Mapped[Optional[str]] = mapped_column(
        Geometry(geometry_type="POINT", spatial_index=False)
    )
    external_id: Mapped[Optional[str]] = mapped_column(String(128), unique=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    floors: Mapped[list["Floor"]] = relationship(back_populates="building")


class Floor(Base):
    __tablename__ = "floors"

    id: Mapped[int] = mapped_column(primary_key=True)
    building_id: Mapped[int] = mapped_column(
        ForeignKey("buildings.id", ondelete="CASCADE")
    )
    name: Mapped[str] = mapped_column(String(64))
    level: Mapped[int] = mapped_column(Integer, default=0)
    surface: Mapped[Optional[str]] = mapped_column(String(32))

    building: Mapped[Building] = relationship(back_populates="floors")
    nodes: Mapped[list["Node"]] = relationship(back_populates="floor")


class Node(Base):
    """A point in the accessibility graph (room, corridor point, elevator...)."""

    __tablename__ = "nodes"

    id: Mapped[int] = mapped_column(primary_key=True)
    floor_id: Mapped[int] = mapped_column(ForeignKey("floors.id", ondelete="CASCADE"))
    node_type: Mapped[str] = mapped_column(
        String(32), index=True
    )  # room | corridor | elevator | ramp | stairs | door | junction | landmark
    name: Mapped[Optional[str]] = mapped_column(String(128))
    position: Mapped[str] = mapped_column(
        Geometry(geometry_type="POINT", spatial_index=False)
    )
    attributes: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    floor: Mapped[Floor] = relationship(back_populates="nodes")


class Edge(Base):
    """A traversable connection between two nodes (direction-agnostic edge)."""

    # Named graph_edges to avoid colliding with the PostGIS tiger
    # geocoder's system "edges" table.
    __tablename__ = "graph_edges"

    id: Mapped[int] = mapped_column(primary_key=True)
    floor_id: Mapped[int] = mapped_column(ForeignKey("floors.id", ondelete="CASCADE"))
    source_node_id: Mapped[int] = mapped_column(ForeignKey("nodes.id"))
    target_node_id: Mapped[int] = mapped_column(ForeignKey("nodes.id"))
    distance_m: Mapped[Optional[float]] = mapped_column(Float)
    slope: Mapped[Optional[float]] = mapped_column(Float)
    width_m: Mapped[Optional[float]] = mapped_column(Float)
    surface: Mapped[Optional[str]] = mapped_column(String(32))
    wheelchair_accessible: Mapped[Optional[bool]] = mapped_column(Boolean)
    temporary_blockage: Mapped[bool] = mapped_column(Boolean, default=False)
    confidence: Mapped[Optional[float]] = mapped_column(Float)
    attributes: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class AccessibilityFeature(Base):
    """Static accessibility feature annotations on nodes."""

    __tablename__ = "accessibility_features"

    id: Mapped[int] = mapped_column(primary_key=True)
    node_id: Mapped[int] = mapped_column(ForeignKey("nodes.id", ondelete="CASCADE"))
    feature_type: Mapped[str] = mapped_column(
        String(32)
    )  # ramp | handrail | tactile_path | ...
    attributes: Mapped[dict] = mapped_column(JSON, default=dict)
    verified: Mapped[bool] = mapped_column(Boolean, default=False)