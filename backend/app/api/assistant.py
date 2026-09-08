"""Assistant query endpoint (primary app interaction surface)."""

from fastapi import APIRouter, Depends

from app.agents.reasoning import (
    MODE_REAL,
    NotConfiguredReasoningProvider,
    ReasoningProvider,
    ReasoningUnavailable,
)
from app.core.logging import stage_logger
from app.schemas.assistant import AssistantQuery, AssistantResponse
from app.schemas.profile import AccessibilityProfile
from app.services.scene import SceneGraphService

from .dependencies import get_reasoning_provider, get_scene_service

router = APIRouter(tags=["assistant"])

_log = stage_logger("assistant")

_HELP_REPLY = (
    "I can guide you through spaces, watch for obstructions, and replan "
    "routes when something is blocked. Ask me to scan the area or "
    "describe what you see."
)


@router.post("/assistant/query", response_model=AssistantResponse)
async def assistant_query(
    req: AssistantQuery,
    reasoning: ReasoningProvider = Depends(get_reasoning_provider),
    scene_service: SceneGraphService = Depends(get_scene_service),
) -> AssistantResponse:
    """Handle a user's voice/text command.

    Free-form queries are explained by the reasoning provider (Groq when
    configured, a deterministic fallback otherwise) grounded in the
    session's current scene graph. "help" and status queries stay
    hardcoded rather than LLM-phrased, since they're claims about what
    this system can do — not something an LLM should be free to embellish.
    """
    text = req.text.strip()
    lowered = text.lower()
    profile = req.profile or AccessibilityProfile()

    _log.info(
        "assistant query received",
        session_id=req.session_id,
        intent=req.intent,
        reasoning_mode=reasoning.mode,
    )

    if req.intent == "system_status":
        return AssistantResponse(
            reply=_status_reply(reasoning),
            debug={"reasoning": reasoning.status()},
        )

    if any(word in lowered for word in ("help", "what can you do")):
        return AssistantResponse(reply=_HELP_REPLY)

    scene = scene_service.get(req.session_id) if req.session_id else []

    # ``used`` tracks whichever provider actually produced ``reply`` — the
    # debug block must describe that, not the one that was merely attempted
    # and failed, or a client would be told "real" reasoning answered when
    # it was actually the deterministic fallback.
    used: ReasoningProvider = reasoning
    try:
        reply = await reasoning.explain(text, scene, profile)
    except ReasoningUnavailable as exc:
        _log.warning(
            "reasoning engine unavailable; using deterministic fallback",
            reason=str(exc),
        )
        used = NotConfiguredReasoningProvider(f"Groq call failed: {exc}")
        reply = await used.explain(text, scene, profile)

    return AssistantResponse(
        reply=reply,
        detections=scene,
        debug={"reasoning": used.status()},
    )


def _status_reply(reasoning: ReasoningProvider) -> str:
    if reasoning.mode == MODE_REAL:
        return "I'm connected to live AI reasoning and the scene graph is active."
    return (
        "I'm running in degraded mode — live AI reasoning isn't configured. "
        "I can still describe what's been detected and plan routes."
    )
