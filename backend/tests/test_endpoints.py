"""End-to-end tests for the mobile backend API contracts.

These hit the live Postgres/PostGIS instance (docker compose up -d db).
A db fixture isolates user records per test.
"""

import uuid

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.db.base import SessionLocal
from app.models import Session as SessionModel
from app.models import User

client = TestClient(app)


@pytest.fixture()
def device_id() -> str:
    return f"test-{uuid.uuid4().hex[:12]}"


def _cleanup(device_id: str) -> None:
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.device_id == device_id).first()
        if user:
            db.query(SessionModel).filter(
                SessionModel.user_id == user.id
            ).delete()
            db.delete(user)
            db.commit()
    finally:
        db.close()


def test_session_endpoint_roundtrip(device_id: str) -> None:
    try:
        response = client.post(
            "/api/v1/auth/session",
            json={"device_id": device_id, "mode": "indoor"},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["session_id"]
        assert body["status"] == "active"
        assert body["user_id"] > 0
    finally:
        _cleanup(device_id)


def test_profile_roundtrip(device_id: str) -> None:
    try:
        client.post("/api/v1/auth/session", json={"device_id": device_id})

        get_resp = client.get("/api/v1/users/me/profile", params={"device_id": device_id})
        assert get_resp.status_code == 200
        assert get_resp.json()["mobility"] == "none"

        put_resp = client.put(
            "/api/v1/users/me/profile",
            params={"device_id": device_id},
            json={"mobility": "wheelchair", "guidance_style": "detailed"},
        )
        assert put_resp.status_code == 200
        profile = put_resp.json()
        assert profile["mobility"] == "wheelchair"
        assert profile["guidance_style"] == "detailed"
    finally:
        _cleanup(device_id)


def test_building_missing_returns_404() -> None:
    response = client.get("/api/v1/buildings/999999")
    assert response.status_code == 404


def test_analyze_frame_degrades_gracefully() -> None:
    response = client.post(
        "/api/v1/perception/analyze",
        json={
            "frame_id": "f1",
            "session_id": "s1",
            "encoded_frame": None,
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["frame_id"] == "f1"
    assert body["detections"] == []