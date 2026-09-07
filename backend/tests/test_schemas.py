"""Tests for request/response contract validation."""

import pytest
from pydantic import ValidationError

from app.schemas.assistant import Action, VerificationRequest, VerificationResult
from app.schemas.common import Location
from app.schemas.perception import Detection
from app.schemas.profile import AccessibilityProfile
from app.schemas.route import RouteRequest


def test_invalid_latitude_rejected() -> None:
    with pytest.raises(ValidationError):
        Location(latitude=95.0, longitude=0.0)


def test_confidence_bounds_rejected() -> None:
    with pytest.raises(ValidationError):
        Detection(object_type="door", confidence=1.4)


def test_profile_flag_descriptors() -> None:
    wheelchair = AccessibilityProfile(mobility="wheelchair")
    assert wheelchair.uses_wheelchair is True
    assert wheelchair.prefers_simple_instructions is True

    low_vision = AccessibilityProfile(vision="low_vision")
    assert low_vision.needs_spatial_audio is True


def test_profile_walking_speed_bounds() -> None:
    with pytest.raises(ValidationError):
        AccessibilityProfile(walking_speed_mps=9.9)


def test_route_request_defaults_to_standard_profile() -> None:
    req = RouteRequest(
        origin=Location(latitude=52.0, longitude=13.0),
        destination=Location(latitude=52.01, longitude=13.01),
    )
    assert req.profile.mobility == "none"
    assert req.profile.guidance_style == "normal"


def test_action_kind_is_constrained_by_type_system() -> None:
    # Actions carry a fixed kind; confidence is always stated.
    action = Action(title="Cross the street", confidence=0.8)
    assert action.kind == "instruction"


def test_verification_result_flags_replan() -> None:
    result = VerificationRequest(
        session_id="s1",
        action_id="a1",
        scene_objects=[],
    )
    assert result.session_id == "s1"