"""Building and indoor-graph queries."""

from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from app.models import Building, Floor, Node


class BuildingService:
    def __init__(self, db: OrmSession) -> None:
        self.db = db

    def get_building(self, building_id: int) -> Optional[Building]:
        return self.db.get(Building, building_id)

    def building_summary(self, building: Building) -> dict:
        """Aggregated accessibility summary for a building."""
        floors = self.db.scalars(
            select(Floor).where(Floor.building_id == building.id)
        ).all()
        floor_ids = [f.id for f in floors]

        nodes: list[Node] = []
        if floor_ids:
            nodes = list(
                self.db.scalars(
                    select(Node).where(Node.floor_id.in_(floor_ids))
                ).all()
            )

        elevators = sum(1 for n in nodes if n.node_type == "elevator")
        ramps = sum(1 for n in nodes if n.node_type == "ramp")
        accessible_floors = [f.level for f in floors if f.name.lower() != "basement"]

        return {
            "building_id": building.id,
            "accessible_entrances": [],
            "elevators": elevators,
            "ramps": ramps,
            "wheelchair_accessible_floors": accessible_floors,
            "notes": ["Floor plan available"] if floors else [],
        }