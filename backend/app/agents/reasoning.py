"""LLM reasoning provider.

Separates REAL reasoning (Groq) from a deterministic NOT_CONFIGURED
fallback, so the assistant works end-to-end without a live LLM key. This
is the only module in the backend that talks to an LLM.

The LLM explains and phrases; it never decides. Every fact it is allowed
to mention here — which objects exist, their distance, direction,
accessibility, and confidence — is computed upstream by perception and
the scene graph's deterministic rules (see ``app/services/scene.py``)
and handed to it as data it is instructed not to contradict. It cannot
invent objects, override an accessibility judgement, or assert certainty
the data doesn't support. If the LLM is unavailable, the deterministic
fallback below produces a real (if less fluent) answer from the same
data, so the assistant is never silent.
"""

from __future__ import annotations

import abc
import json
from typing import Any

from app.core.logging import stage_logger
from app.schemas.common import Direction
from app.schemas.profile import AccessibilityProfile
from app.schemas.scene import SceneObject

_log = stage_logger("reasoning")

MODE_REAL = "real"
MODE_OFF = "off"

_LOW_CONFIDENCE = 0.5
_VERBOSITY_LIMIT = {"concise": 1, "normal": 2, "detailed": 3}

_SYSTEM_PROMPT = """You are AccessCopilot, a spoken accessibility guidance assistant.

You explain what the user's camera has already detected. You never invent
objects, distances, directions, or accessibility judgements that are not
present in the SCENE data given to you. If SCENE is empty, say so plainly;
do not guess what might be nearby.

Rules:
- Only mention objects present in SCENE. Never invent additional hazards,
  routes, doors, or landmarks.
- Never state a distance, direction, or accessibility status that isn't
  given in SCENE.
- If an object's confidence is below 0.5, express uncertainty ("I may have
  detected...", "not fully sure") instead of asserting it as fact.
- Priority order: (1) safety — inaccessible or blocked objects close to the
  user first, (2) the user's stated question, (3) brief extra context.
- Match the user's guidance_style: "concise" = one short sentence, "normal"
  = one or two sentences, "detailed" = up to three sentences.
- Never claim a path is "definitely clear" or "certainly safe" — the scene
  is a single snapshot, not a guarantee.
- Speak directly to the user in plain spoken language. No bullet points, no
  markdown, no object IDs, no mention of JSON or "the data"."""


class ReasoningUnavailable(RuntimeError):
    """Raised when the reasoning engine cannot produce a response."""


class ReasoningProvider(abc.ABC):
    """Turns structured, already-decided scene state into spoken language."""

    name: str = "reasoning"
    mode: str = MODE_OFF

    @abc.abstractmethod
    async def explain(
        self,
        query: str,
        scene: list[SceneObject],
        profile: AccessibilityProfile,
    ) -> str:
        """Return a spoken-language reply grounded in ``scene``."""
        raise NotImplementedError

    def status(self) -> dict[str, Any]:
        return {"provider": self.name, "mode": self.mode}


class NotConfiguredReasoningProvider(ReasoningProvider):
    """Deterministic degraded-mode fallback — no LLM required.

    Used both when no Groq key is configured and as the safety-net when a
    configured Groq call fails, so the assistant is never silent.
    """

    name = "not_configured"
    mode = MODE_OFF

    def __init__(self, reason: str = "reasoning engine not configured") -> None:
        self.reason = reason

    async def explain(
        self,
        query: str,
        scene: list[SceneObject],
        profile: AccessibilityProfile,
    ) -> str:
        if scene:
            return describe_scene_deterministically(scene, profile)
        return (
            "I received your message, but I don't have live AI reasoning "
            f'configured right now and no scene is available. You said: "{query}"'
        )

    def status(self) -> dict[str, Any]:
        return {**super().status(), "reason": self.reason}


class GroqReasoningProvider(ReasoningProvider):
    """Real reasoning via the Groq chat completions API."""

    name = "groq"
    mode = MODE_REAL

    def __init__(self, api_key: str, model: str, timeout_s: float = 8.0) -> None:
        self._api_key = api_key
        self._model = model
        self._timeout_s = timeout_s
        self._client: Any | None = None

    def _get_client(self) -> Any:
        if self._client is None:
            try:
                from groq import AsyncGroq  # imported lazily: optional dependency
            except ImportError as exc:  # pragma: no cover - depends on env
                raise ReasoningUnavailable(
                    "groq is not installed; "
                    "install backend/requirements-ai.txt to enable real reasoning"
                ) from exc
            self._client = AsyncGroq(api_key=self._api_key, timeout=self._timeout_s)
        return self._client

    async def explain(
        self,
        query: str,
        scene: list[SceneObject],
        profile: AccessibilityProfile,
    ) -> str:
        client = self._get_client()
        user_prompt = _build_user_prompt(query, scene, profile)
        try:
            response = await client.chat.completions.create(
                model=self._model,
                messages=[
                    {"role": "system", "content": _SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt},
                ],
                temperature=0.3,
                max_tokens=400,
                # Reasoning-tuned models (e.g. gpt-oss) draw hidden "thinking"
                # tokens from the same max_tokens budget as the reply; on a
                # detailed grounding prompt like ours that can consume the
                # whole budget and leave an empty reply. "low" keeps enough
                # headroom for the actual answer. Models that don't support
                # this field are expected to ignore it (OpenAI-compatible
                # APIs pass through unknown optional fields); if a given
                # model errors on it instead, the except below still
                # degrades cleanly rather than crashing the endpoint.
                reasoning_effort="low",
            )
        except Exception as exc:  # pragma: no cover - network/SDK errors
            _log.error("groq request failed", error=str(exc))
            raise ReasoningUnavailable(f"Groq request failed: {exc}") from exc

        reply = (response.choices[0].message.content or "").strip()
        if not reply:
            raise ReasoningUnavailable("Groq returned an empty response")
        return reply


def build_reasoning_provider(
    api_key: str, model: str, timeout_s: float = 8.0
) -> ReasoningProvider:
    """Select a provider from configuration.

    Mirrors the perception provider's honesty: no key means degraded mode,
    reported as such, never a silent substitution.
    """
    if not api_key:
        return NotConfiguredReasoningProvider("no GROQ_API_KEY configured")
    return GroqReasoningProvider(api_key=api_key, model=model, timeout_s=timeout_s)


# -- grounding: scene -> prompt / deterministic text ------------------------


def _scene_to_json(scene: list[SceneObject]) -> str:
    payload = [
        {
            "type": o.type,
            "distance_m": o.distance_m,
            "direction": o.direction.value if isinstance(o.direction, Direction) else o.direction,
            "accessible": o.accessible,
            "confidence": round(o.confidence, 2),
            "currently_visible": o.currently_visible,
            "temporary_blockage": o.temporary_blockage,
            "state": o.state,
        }
        for o in scene
    ]
    return json.dumps(payload, ensure_ascii=False)


def _build_user_prompt(
    query: str, scene: list[SceneObject], profile: AccessibilityProfile
) -> str:
    return (
        f"User accessibility profile: mobility={profile.mobility}, "
        f"vision={profile.vision}, guidance_style={profile.guidance_style}.\n\n"
        f"SCENE (ground truth, JSON — do not contradict or add to this):\n"
        f"{_scene_to_json(scene)}\n\n"
        f'User said: "{query}"\n\n'
        "Respond with the single best spoken reply."
    )


def describe_scene_deterministically(
    scene: list[SceneObject], profile: AccessibilityProfile
) -> str:
    """Phrase the current scene without any LLM call.

    This is the deterministic ground truth the LLM's phrasing is checked
    against, and the real fallback used whenever the LLM is unavailable.
    """
    visible = [o for o in scene if o.currently_visible]
    if not visible:
        return "I don't see anything notable in the current scene yet."

    def _priority(o: SceneObject) -> tuple[int, float]:
        hazard = 0 if (o.temporary_blockage or o.accessible is False) else 1
        return (hazard, o.distance_m if o.distance_m is not None else 999.0)

    ranked = sorted(visible, key=_priority)
    limit = _VERBOSITY_LIMIT.get(profile.guidance_style, 2)
    return " ".join(_phrase_object(o) for o in ranked[:limit])


def _phrase_object(o: SceneObject) -> str:
    label = o.type.replace("_", " ")
    direction = o.direction.value if isinstance(o.direction, Direction) else o.direction
    location = "ahead" if direction in (None, "front") else f"to your {direction}"

    parts = [f"{label.capitalize()} {location}"]
    if o.distance_m is not None:
        parts.append(
            "very close" if o.distance_m < 1 else f"{o.distance_m:.0f} metres away"
        )
    sentence = ", ".join(parts) + "."

    if o.confidence < _LOW_CONFIDENCE:
        sentence = "I may have detected " + sentence[0].lower() + sentence[1:]
    elif o.temporary_blockage:
        sentence += " It's currently blocking the way."
    elif o.accessible is False:
        sentence += " Not accessible."
    elif o.accessible is True:
        sentence += " Accessible."
    return sentence


__all__ = [
    "MODE_OFF",
    "MODE_REAL",
    "GroqReasoningProvider",
    "NotConfiguredReasoningProvider",
    "ReasoningProvider",
    "ReasoningUnavailable",
    "build_reasoning_provider",
    "describe_scene_deterministically",
]
