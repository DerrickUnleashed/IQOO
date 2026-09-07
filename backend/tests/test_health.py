"""Tests for the health and readiness endpoints."""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_returns_ok() -> None:
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["service"] == "accesscopilot"


def test_readiness_reports_capabilities() -> None:
    response = client.get("/api/v1/readiness")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert "ai_enabled" in body
    assert isinstance(body["ai_enabled"], bool)


def test_ping_returns_pong() -> None:
    response = client.get("/api/v1/ping")
    assert response.status_code == 200
    assert response.json() == {"ping": "pong"}


def test_unknown_route_returns_404() -> None:
    response = client.get("/api/v1/does-not-exist")
    assert response.status_code == 404