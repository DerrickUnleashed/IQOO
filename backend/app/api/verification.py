"""Verification endpoints: closed-loop checks on planned actions."""

from fastapi import APIRouter

from app.schemas.assistant import (
    VerificationRequest,
    VerificationResult,
)

router = APIRouter(tags=["verification"])


def _verify(req: VerificationRequest) -> VerificationResult:
    """Check whether the requested action state was observed.

    Deterministic for now: a temporary blockage currently visible means
    the action did not complete and replanning is required. Smarter
    verification is layered in later milestones.
    """
    blocked = any(o.temporary_blockage for o in req.scene_objects)
    relevant = [
        o for o in req.scene_objects if o.type in {"step", "ramp", "elevator"}
    ]

    if blocked:
        return VerificationResult(
            action_id=req.action_id,
            verified=False,
            confidence=0.9,
            message="A temporary blockage is currently visible.",
            replan_required=True,
        )

    detected = any(o.currently_visible and o.confidence >= 0.5 for o in relevant)
    if detected:
        return VerificationResult(
            action_id=req.action_id,
            verified=True,
            confidence=0.7,
            message="The expected scene element was confirmed.",
        )

    return VerificationResult(
        action_id=req.action_id,
        verified=False,
        confidence=0.3,
        message="No confirming evidence observed yet.",
    )


@router.post("/verification/check", response_model=VerificationResult)
def check_verification(req: VerificationRequest) -> VerificationResult:
    return _verify(req)