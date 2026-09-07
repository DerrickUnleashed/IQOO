"""Assistant query endpoint (primary app interaction surface)."""

from fastapi import APIRouter

from app.schemas.assistant import AssistantQuery, AssistantResponse

router = APIRouter(tags=["assistant"])


@router.post("/assistant/query", response_model=AssistantResponse)
async def assistant_query(req: AssistantQuery) -> AssistantResponse:
    """Handle a user's voice/text command.

    The LangGraph agent gets wired here in the agent milestone. Until
    then a deterministic fallback provides graceful degraded responses.
    """
    text = req.text.strip()
    lowered = text.lower()

    if req.intent == "system_status":
        return AssistantResponse(
            reply="I'm running in degraded mode — live AI models aren't "
            "configured yet. I can still plan routes and verify actions "
            "when the scene graph is active.",
        )

    if any(word in lowered for word in ("help", "what can you do")):
        return AssistantResponse(
            reply="I can guide you through spaces, watch for obstructions, "
            "and replan routes when something is blocked. Ask me to scan "
            "the area or describe what you see.",
        )

    return AssistantResponse(
        reply="I received your message. Full interpretation needs the AI "
        f"agent, which is being enabled. You said: \"{text}\"",
    )