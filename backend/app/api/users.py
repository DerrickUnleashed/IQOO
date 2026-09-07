"""User and accessibility profile endpoints."""

from fastapi import APIRouter, Body, Depends
from sqlalchemy.orm import Session as OrmSession

from app.db.base import get_db
from app.models import UserProfile
from app.schemas.profile import AccessibilityProfile, ProfileUpdate
from app.schemas.session import UserOut
from app.services import SessionService

router = APIRouter(tags=["users"])


@router.get("/users/me", response_model=UserOut)
def get_me(
    device_id: str,
    db: OrmSession = Depends(get_db),
) -> UserOut:
    """Return the current user (identified by device id for now)."""
    service = SessionService(db)
    user = service.get_or_create_user(device_id)
    return UserOut(id=user.id, device_id=user.device_id, created_at=user.created_at)


@router.get("/users/me/profile", response_model=AccessibilityProfile)
def get_profile(
    device_id: str,
    db: OrmSession = Depends(get_db),
) -> AccessibilityProfile:
    service = SessionService(db)
    user = service.get_or_create_user(device_id)
    profile: UserProfile = service.get_profile(user.id)

    return AccessibilityProfile(
        mobility=profile.mobility or "none",
        vision=profile.vision or "none",
        hearing=profile.hearing or "none",
        guidance_style=profile.guidance_style or "normal",
        walking_speed_mps=profile.walking_speed_mps or 1.2,
        max_comfortable_distance_m=profile.max_comfortable_distance_m or 100,
        cognitive_load_preference=profile.cognitive_load_preference or 1,
    )


@router.put("/users/me/profile", response_model=AccessibilityProfile)
def update_profile(
    device_id: str,
    update: ProfileUpdate = Body(...),
    db: OrmSession = Depends(get_db),
) -> AccessibilityProfile:
    service = SessionService(db)
    user = service.get_or_create_user(device_id)
    profile: UserProfile = service.get_profile(user.id)

    for field, value in update.model_dump(exclude_none=True).items():
        setattr(profile, field, value)
    db.commit()
    db.refresh(profile)

    return AccessibilityProfile(
        mobility=profile.mobility or "none",
        vision=profile.vision or "none",
        hearing=profile.hearing or "none",
        guidance_style=profile.guidance_style or "normal",
        walking_speed_mps=profile.walking_speed_mps or 1.2,
        max_comfortable_distance_m=profile.max_comfortable_distance_m or 100,
        cognitive_load_preference=profile.cognitive_load_preference or 1,
    )