"""Session, user and building contracts."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field

from .common import Location
from .profile import AccessibilityProfile


class SessionCreate(BaseModel):
    """Start a new assistance session."""

    device_id: str = Field(min_length=1)
    mode: Optional[str] = None


class SessionOut(BaseModel):
    session_id: str
    user_id: int
    started_at: datetime
    status: str = "active"


class UserOut(BaseModel):
    id: int
    device_id: str
    created_at: datetime


class BuildingOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    address: Optional[str] = None
    has_floor_plan: bool = False


class BuildingAccessibilityOut(BaseModel):
    building_id: int
    accessible_entrances: list[Location] = Field(default_factory=list)
    elevators: int = 0
    ramps: int = 0
    wheelchair_accessible_floors: list[int] = Field(default_factory=list)
    notes: list[str] = Field(default_factory=list)