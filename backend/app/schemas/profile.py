"""Personal accessibility profile contract.

User-dependent by design: the same environment produces different
recommendations for different users. Everything is optional so a user
can use the app without labelling themselves.
"""

from typing import Literal, Optional

from pydantic import BaseModel, Field

MobilityAssistance = Literal[
    "none", "temporary_mobility", "wheelchair", "walking_aid", "cane"
]
VisionAssistance = Literal[
    "none", "temporary_vision", "low_vision", "blind"
]
HearingAssistance = Literal["none", "hearing_aid", "deaf"]
GuidanceStyle = Literal["concise", "normal", "detailed"]


class AccessibilityProfile(BaseModel):
    """Recommendations are derived from this profile."""

    mobility: MobilityAssistance = "none"
    vision: VisionAssistance = "none"
    hearing: HearingAssistance = "none"
    guidance_style: GuidanceStyle = "normal"
    walking_speed_mps: float = Field(default=1.2, gt=0.0, le=4.0)
    max_comfortable_distance_m: int = Field(default=100, ge=10, le=10000)
    cognitive_load_preference: int = Field(default=1, ge=1, le=3)

    # Derived flags used by the route and guidance engines.
    @property
    def uses_wheelchair(self) -> bool:
        return self.mobility == "wheelchair"

    @property
    def needs_spatial_audio(self) -> bool:
        return self.vision in {"low_vision", "blind", "temporary_vision"}

    @property
    def prefers_simple_instructions(self) -> bool:
        return self.cognitive_load_preference <= 1


class ProfileUpdate(BaseModel):
    """Partial update; omitted fields keep their current value."""

    mobility: Optional[MobilityAssistance] = None
    vision: Optional[VisionAssistance] = None
    hearing: Optional[HearingAssistance] = None
    guidance_style: Optional[GuidanceStyle] = None
    walking_speed_mps: Optional[float] = Field(default=None, gt=0.0, le=4.0)
    max_comfortable_distance_m: Optional[int] = Field(
        default=None, ge=10, le=10000
    )
    cognitive_load_preference: Optional[int] = Field(
        default=None, ge=1, le=3
    )