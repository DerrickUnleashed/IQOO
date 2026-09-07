"""End-to-end tests for the mobile backend API contracts.

These hit the live Postgres/PostGIS instance (docker compose up -d db).
A db fixture isolates user records per test.
"""

import base64
import uuid

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import get_perception_provider
from app.db.base import SessionLocal
from app.main import app
from app.models import Building, User
from app.models import Session as SessionModel
from app.perception.provider import MODE_SCRIPTED, build_perception_provider

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


def test_building_list_and_detail_roundtrip() -> None:
    db = SessionLocal()
    try:
        building = Building(name="Test Pavilion", address="1 Test Way")
        db.add(building)
        db.commit()
        db.refresh(building)
        building_id = building.id
    finally:
        db.close()

    try:
        response = client.get("/api/v1/buildings")
        assert response.status_code == 200
        ids = [b["id"] for b in response.json()]
        assert building_id in ids

        detail = client.get(f"/api/v1/buildings/{building_id}")
        assert detail.status_code == 200
        body = detail.json()
        assert body["name"] == "Test Pavilion"
        assert body["has_floor_plan"] is False
    finally:
        db = SessionLocal()
        try:
            db.query(Building).filter(Building.id == building_id).delete()
            db.commit()
        finally:
            db.close()


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
    # A frame that was never sent must not read as "nothing is there".
    assert body["scene_summary"]["frame_received"] is False


def test_analyze_frame_reports_how_the_scene_was_produced() -> None:
    """Clients must be able to tell scripted playback from real inference."""
    provider = build_perception_provider(mode=MODE_SCRIPTED, scenario="stairs_ramp")
    app.dependency_overrides[get_perception_provider] = lambda: provider
    try:
        response = client.post(
            "/api/v1/perception/analyze",
            json={
                "frame_id": "f2",
                "session_id": "s1",
                "encoded_frame": base64.b64encode(b"frame-bytes").decode(),
            },
        )
    finally:
        app.dependency_overrides.pop(get_perception_provider, None)

    assert response.status_code == 200
    body = response.json()
    summary = body["scene_summary"]
    assert summary["mode"] == MODE_SCRIPTED
    assert summary["frame_received"] is True
    assert summary["detection_count"] == len(body["detections"])
    assert body["detections"], "scripted playback should produce a scene"
    assert all(d["source"] == "scripted" for d in body["detections"])


def test_readiness_reports_the_active_perception_engine() -> None:
    body = client.get("/api/v1/readiness").json()
    assert body["perception"]["mode"] in {"real", "scripted", "off"}
    assert "coverage" in body["perception"]