"""Authentication and session endpoints."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as OrmSession

from app.db.base import get_db
from app.schemas.session import SessionCreate, SessionOut
from app.services import SessionService

router = APIRouter(tags=["auth"])


@router.post("/auth/session", response_model=SessionOut)
def create_auth_session(
    body: SessionCreate,
    db: OrmSession = Depends(get_db),
) -> SessionOut:
    """Exchange a device id for a session (the app's identity model)."""
    service = SessionService(db)
    try:
        user = service.get_or_create_user(body.device_id)
    except Exception as exc:  # pragma: no cover - defensive
        raise HTTPException(status_code=500, detail="Could not create session") from exc

    session = service.create_session(user, body.mode)

    return SessionOut(
        session_id=session.session_uuid,
        user_id=session.user_id,
        started_at=session.started_at,
        status=session.status,
    )