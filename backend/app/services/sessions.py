"""Session lifecycle service."""

import uuid
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from app.models import Session, User, UserProfile


class SessionService:
    """Creates users + sessions, and reads/writes accessibility profiles."""

    def __init__(self, db: OrmSession) -> None:
        self.db = db

    def get_or_create_user(self, device_id: str) -> User:
        user = self.db.scalar(select(User).where(User.device_id == device_id))
        if user is None:
            user = User(device_id=device_id)
            self.db.add(user)
            self.db.commit()
            self.db.refresh(user)
        return user

    def get_profile(self, user_id: int) -> UserProfile:
        profile = self.db.scalar(
            select(UserProfile).where(UserProfile.user_id == user_id)
        )
        if profile is None:
            profile = UserProfile(user_id=user_id)
            self.db.add(profile)
            self.db.commit()
            self.db.refresh(profile)
        return profile

    def create_session(self, user: User, mode: Optional[str] = None) -> Session:
        session = Session(
            session_uuid=uuid.uuid4().hex,
            user_id=user.id,
            mode=mode,
            status="active",
        )
        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)
        return session