"""Tests for the LLM reasoning provider.

The Groq client is never hit over the network here — ``GroqReasoningProvider``
is exercised with a fake client injected directly, so these tests are fast,
deterministic, and offline. What matters is the contract: the LLM only
receives data it must not contradict, a failed or unconfigured LLM degrades
to real (if less fluent) output instead of going silent, and the
deterministic phrasing itself is safe and correctly prioritised.
"""

import json

import pytest

from app.agents.reasoning import (
    MODE_OFF,
    MODE_REAL,
    GroqReasoningProvider,
    NotConfiguredReasoningProvider,
    ReasoningUnavailable,
    build_reasoning_provider,
    describe_scene_deterministically,
)
from app.schemas.common import Direction
from app.schemas.profile import AccessibilityProfile
from app.schemas.scene import SceneObject


def _obj(
    type_: str,
    distance_m: float | None = 3.0,
    direction: Direction = Direction.front,
    accessible: bool | None = None,
    confidence: float = 0.9,
    currently_visible: bool = True,
    temporary_blockage: bool = False,
) -> SceneObject:
    return SceneObject(
        id=f"{type_}_1",
        type=type_,
        distance_m=distance_m,
        direction=direction,
        accessible=accessible,
        confidence=confidence,
        currently_visible=currently_visible,
        temporary_blockage=temporary_blockage,
    )


# --- provider selection -----------------------------------------------------


def test_no_key_selects_not_configured_provider() -> None:
    provider = build_reasoning_provider(api_key="", model="m")
    assert isinstance(provider, NotConfiguredReasoningProvider)
    assert provider.status()["mode"] == MODE_OFF


def test_key_present_selects_groq_provider() -> None:
    provider = build_reasoning_provider(api_key="sk-something", model="m")
    assert isinstance(provider, GroqReasoningProvider)
    assert provider.status()["mode"] == MODE_REAL


# --- deterministic fallback phrasing ----------------------------------------


def test_empty_scene_says_so_plainly() -> None:
    text = describe_scene_deterministically([], AccessibilityProfile())
    assert "don't see" in text.lower()


def test_invisible_objects_are_not_mentioned() -> None:
    scene = [_obj("stairs", currently_visible=False)]
    text = describe_scene_deterministically(scene, AccessibilityProfile())
    assert "don't see" in text.lower()


def test_inaccessible_object_is_labelled_not_accessible() -> None:
    scene = [_obj("stairs", accessible=False)]
    text = describe_scene_deterministically(scene, AccessibilityProfile())
    assert "not accessible" in text.lower()


def test_accessible_object_is_labelled_accessible() -> None:
    scene = [_obj("ramp", accessible=True)]
    text = describe_scene_deterministically(scene, AccessibilityProfile())
    assert "accessible" in text.lower()
    assert "not accessible" not in text.lower()


def test_low_confidence_object_is_hedged() -> None:
    scene = [_obj("ramp", confidence=0.3)]
    text = describe_scene_deterministically(scene, AccessibilityProfile())
    assert "may have detected" in text.lower()


def test_blockage_is_flagged() -> None:
    scene = [_obj("obstacle", temporary_blockage=True)]
    text = describe_scene_deterministically(scene, AccessibilityProfile())
    assert "blocking the way" in text.lower()


def test_hazards_are_prioritised_over_distance() -> None:
    """A far inaccessible hazard must be mentioned before a near accessible one."""
    scene = [
        _obj("ramp", distance_m=1.0, accessible=True),
        _obj("stairs", distance_m=8.0, accessible=False),
    ]
    text = describe_scene_deterministically(
        scene, AccessibilityProfile(guidance_style="concise")
    )
    assert "stairs" in text.lower()
    assert "ramp" not in text.lower()  # concise = 1 object, hazard wins


@pytest.mark.parametrize(
    "style, expected_count",
    [("concise", 1), ("normal", 2), ("detailed", 3)],
)
def test_guidance_style_controls_verbosity(style: str, expected_count: int) -> None:
    scene = [
        _obj("stairs", distance_m=1.0, accessible=False),
        _obj("ramp", distance_m=2.0, accessible=True),
        _obj("elevator", distance_m=3.0, accessible=True),
        _obj("door", distance_m=4.0, accessible=None),
    ]
    text = describe_scene_deterministically(
        scene, AccessibilityProfile(guidance_style=style)
    )
    # Each phrased object ends its sentence with a period; count sentences.
    assert text.count(".") >= expected_count
    # And no more than expected_count objects were surfaced.
    mentioned = sum(
        1 for o in scene if o.type.replace("_", " ") in text.lower()
    )
    assert mentioned == expected_count


def test_direction_is_phrased_naturally() -> None:
    scene = [_obj("ramp", direction=Direction.right, accessible=True)]
    text = describe_scene_deterministically(scene, AccessibilityProfile())
    assert "to your right" in text.lower()


def test_front_direction_reads_as_ahead_not_to_your_front() -> None:
    scene = [_obj("stairs", direction=Direction.front, accessible=False)]
    text = describe_scene_deterministically(scene, AccessibilityProfile())
    assert "ahead" in text.lower()
    assert "to your front" not in text.lower()


# --- NotConfiguredReasoningProvider -----------------------------------------


@pytest.mark.asyncio
async def test_not_configured_explain_uses_deterministic_scene_text() -> None:
    provider = NotConfiguredReasoningProvider()
    scene = [_obj("stairs", accessible=False)]
    reply = await provider.explain("what's ahead?", scene, AccessibilityProfile())
    assert "stairs" in reply.lower()


@pytest.mark.asyncio
async def test_not_configured_explain_without_scene_echoes_the_query() -> None:
    provider = NotConfiguredReasoningProvider()
    reply = await provider.explain("hello?", [], AccessibilityProfile())
    assert "hello?" in reply


# --- GroqReasoningProvider (fake client, no network) ------------------------


class _FakeMessage:
    def __init__(self, content: str | None) -> None:
        self.content = content


class _FakeChoice:
    def __init__(self, content: str | None) -> None:
        self.message = _FakeMessage(content)


class _FakeCompletionResponse:
    def __init__(self, content: str | None) -> None:
        self.choices = [_FakeChoice(content)]


class _FakeCompletions:
    def __init__(self, content: str | None = None, error: Exception | None = None) -> None:
        self._content = content
        self._error = error
        self.last_call: dict | None = None

    async def create(self, **kwargs) -> _FakeCompletionResponse:
        self.last_call = kwargs
        if self._error:
            raise self._error
        return _FakeCompletionResponse(self._content)


class _FakeChat:
    def __init__(self, completions: _FakeCompletions) -> None:
        self.completions = completions


class _FakeGroqClient:
    def __init__(self, content: str | None = None, error: Exception | None = None) -> None:
        self.chat = _FakeChat(_FakeCompletions(content, error))


def _provider_with_fake_client(content: str | None = None, error: Exception | None = None):
    provider = GroqReasoningProvider(api_key="k", model="m")
    provider._client = _FakeGroqClient(content, error)  # bypass the lazy import
    return provider


@pytest.mark.asyncio
async def test_groq_provider_returns_the_model_reply() -> None:
    provider = _provider_with_fake_client(content="Stairs ahead, avoid them.")
    reply = await provider.explain("what's ahead?", [], AccessibilityProfile())
    assert reply == "Stairs ahead, avoid them."


@pytest.mark.asyncio
async def test_groq_provider_sends_scene_as_ungameable_json() -> None:
    """The model must receive the scene as data it can quote, not prose it can drift from."""
    provider = _provider_with_fake_client(content="ok")
    scene = [_obj("stairs", distance_m=5.8, accessible=False, confidence=0.94)]
    await provider.explain("what's ahead?", scene, AccessibilityProfile())

    call = provider._client.chat.completions.last_call
    user_message = call["messages"][1]["content"]
    # Extract and parse the embedded JSON scene block.
    json_start = user_message.index("[")
    json_end = user_message.rindex("]") + 1
    parsed = json.loads(user_message[json_start:json_end])
    assert parsed == [
        {
            "type": "stairs",
            "distance_m": 5.8,
            "direction": "front",
            "accessible": False,
            "confidence": 0.94,
            "currently_visible": True,
            "temporary_blockage": False,
            "state": None,
        }
    ]


@pytest.mark.asyncio
async def test_groq_provider_raises_on_empty_reply() -> None:
    provider = _provider_with_fake_client(content="")
    with pytest.raises(ReasoningUnavailable):
        await provider.explain("hi", [], AccessibilityProfile())


@pytest.mark.asyncio
async def test_groq_provider_raises_on_client_error() -> None:
    provider = _provider_with_fake_client(error=RuntimeError("network down"))
    with pytest.raises(ReasoningUnavailable, match="network down"):
        await provider.explain("hi", [], AccessibilityProfile())


@pytest.mark.asyncio
async def test_groq_provider_without_package_installed_raises_cleanly(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A missing optional dependency must fail with a clear, catchable error."""
    import builtins

    real_import = builtins.__import__

    def _blocked_import(name, *args, **kwargs):
        if name == "groq":
            raise ImportError("no module named groq")
        return real_import(name, *args, **kwargs)

    monkeypatch.setattr(builtins, "__import__", _blocked_import)
    provider = GroqReasoningProvider(api_key="k", model="m")
    with pytest.raises(ReasoningUnavailable, match="groq is not installed"):
        await provider.explain("hi", [], AccessibilityProfile())
