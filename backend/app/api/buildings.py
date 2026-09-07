"""Building lookups and accessibility summaries."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as OrmSession

from app.db.base import get_db
from app.schemas.session import BuildingAccessibilityOut, BuildingOut
from app.services import BuildingService

router = APIRouter(tags=["buildings"])


@router.get("/buildings/{building_id}", response_model=BuildingOut)
def get_building(
    building_id: int,
    db: OrmSession = Depends(get_db),
) -> BuildingOut:
    building = BuildingService(db).get_building(building_id)
    if building is None:
        raise HTTPException(status_code=404, detail="Building not found")

    floors = [f for f in building.floors]
    return BuildingOut(
        id=building.id,
        name=building.name,
        address=building.address,
        has_floor_plan=len(floors) > 0,
    )


@router.get("/buildings/{building_id}/accessibility", response_model=BuildingAccessibilityOut)
def get_building_accessibility(
    building_id: int,
    db: OrmSession = Depends(get_db),
) -> BuildingAccessibilityOut:
    service = BuildingService(db)
    building = service.get_building(building_id)
    if building is None:
        raise HTTPException(status_code=404, detail="Building not found")

    summary = service.building_summary(building)
    return BuildingAccessibilityOut(**summary)