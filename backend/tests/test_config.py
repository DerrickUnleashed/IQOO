"""Configuration loading tests.

These cover the two ways settings silently misloaded before: the repo-root
``.env`` being missed when the process runs from ``backend/``, and the
documented comma-separated ``ALLOWED_ORIGINS`` form failing to parse.
"""

from pathlib import Path

import pytest

from app.core.config import Settings, settings


def _settings(**overrides: object) -> Settings:
    """Build Settings without reading any .env file from disk."""
    return Settings(_env_file=None, **overrides)  # type: ignore[arg-type]


def test_env_file_is_resolved_from_the_repo_root() -> None:
    """The canonical .env sits beside docker-compose.yml, not in backend/."""
    env_files = Settings.model_config["env_file"]
    root_env = Path(env_files[0])
    assert root_env.name == ".env"
    assert (root_env.parent / "docker-compose.yml").exists()


@pytest.mark.parametrize(
    "raw, expected",
    [
        (
            "http://localhost:3000,http://localhost:8080",
            ["http://localhost:3000", "http://localhost:8080"],
        ),
        # Whitespace around entries is tolerated.
        (" http://a.test , http://b.test ", ["http://a.test", "http://b.test"]),
        # Single origin, no separator.
        ("http://only.test", ["http://only.test"]),
        # JSON form still works for existing deployments.
        ('["http://a.test", "http://b.test"]', ["http://a.test", "http://b.test"]),
        # Empty means "no extra origins", not a parse error.
        ("", []),
    ],
)
def test_allowed_origins_accepts_documented_forms(
    raw: str, expected: list[str]
) -> None:
    assert _settings(ALLOWED_ORIGINS=raw).ALLOWED_ORIGINS == expected


def test_allowed_origins_passes_through_a_real_list() -> None:
    origins = ["http://a.test"]
    assert _settings(ALLOWED_ORIGINS=origins).ALLOWED_ORIGINS == origins


def test_has_ai_capabilities_tracks_the_groq_key() -> None:
    assert _settings(GROQ_API_KEY="").has_ai_capabilities is False
    assert _settings(GROQ_API_KEY="k").has_ai_capabilities is True


def test_module_level_settings_expose_a_usable_origin_list() -> None:
    assert isinstance(settings.ALLOWED_ORIGINS, list)
    assert all(isinstance(origin, str) for origin in settings.ALLOWED_ORIGINS)
