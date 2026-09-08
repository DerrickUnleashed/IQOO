"""Assistant/agent interaction contracts."""

from typing import Any, Optional

from pydantic import BaseModel, Field

from .profile import AccessibilityProfile
from .scene import SceneObject


class Action(BaseModel):
    """The recommended next action — the core product output."""

    title: str
    detail: Optional[str] = None
    kind: str = "instruction"  # instruction | warning | confirmation | query
    confidence: float = Field(default=0.5, ge=0.0, le=1.0)
    haptics: Optional[str] = None  # none | light | double | strong


class VerificationResult(BaseModel):
    """Closed-loop camera verification of a planned action."""

    action_id: str
    verified: bool
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    message: Optional[str] = None
    replan_required: bool = False


class VerificationRequest(BaseModel):
    """Ask the system to verify whether a planned action succeeded."""

    session_id: str
    action_id: str
    scene_objects: list[SceneObject] = Field(default_factory=list)


class AssistantQuery(BaseModel):
    """A voice-text command from the user (Whisper transcript)."""

    session_id: Optional[str] = None
    text: str
    intent: Optional[str] = None
    profile: Optional[AccessibilityProfile] = None


class AssistantResponse(BaseModel):
    """Natural-language response, always grounded in structured state."""

    reply: str
    action: Optional[Action] = None
    detections: list[SceneObject] = Field(default_factory=list)
    route_change: bool = False
    debug: dict[str, Any] = Field(default_factory=dict)