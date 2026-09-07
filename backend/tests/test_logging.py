"""Tests for structured, JSON-lines logging."""

import io
import json
import logging

from fastapi.testclient import TestClient

from app.core.logging import JsonFormatter, RedactFilter
from app.main import app


class _CaptureHandler(logging.Handler):
    def __init__(self) -> None:
        super().__init__()
        self.records: list[logging.LogRecord] = []
        self.stream = io.StringIO()

    def emit(self, record: logging.LogRecord) -> None:
        self.records.append(record)
        self.stream.write(self.format(record))
        self.stream.write("\n")


def _record(**extra) -> logging.LogRecord:
    r = logging.LogRecord(
        name="accesscopilot.test",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg="check",
        args=(),
        exc_info=None,
    )
    for key, value in extra.items():
        setattr(r, key, value)
    return r


def test_json_formatter_emits_single_line_json() -> None:
    formatter = JsonFormatter()
    out = formatter.format(_record(stage="perception", frame_count=3))
    assert "\n" not in out
    payload = json.loads(out)
    assert payload["event"] == "check"
    assert payload["stage"] == "perception"
    assert payload["level"] == "info"
    assert payload["frame_count"] == 3


def test_json_formatter_defaults_stage_to_core() -> None:
    payload = json.loads(JsonFormatter().format(_record()))
    assert payload["stage"] == "core"


def test_redact_filter_hides_sensitive_fields() -> None:
    redactor = RedactFilter()
    record = _record(api_key="super-secret", frame_count=2)
    redactor.filter(record)
    assert record.api_key == "[REDACTED]"
    assert record.frame_count == 2


def test_redact_covers_authorization_and_encoded_frame() -> None:
    redactor = RedactFilter()
    record = _record(authorization="Bearer abc", encoded_frame=b"\xff\x00")
    redactor.filter(record)
    assert record.authorization == "[REDACTED]"
    assert record.encoded_frame == "[REDACTED]"


def test_stage_logger_stamps_stage_and_fields() -> None:
    from app.core.logging import StageLogger

    handler = _CaptureHandler()
    handler.setFormatter(JsonFormatter())
    logger = logging.getLogger("accesscopilot.stagetest")
    logger.addHandler(handler)
    logger.setLevel(logging.DEBUG)

    stage = StageLogger(logger, "routes")
    stage.info("route computed", distance_m=42.0)

    payload = json.loads(handler.stream.getvalue().strip())
    assert payload["stage"] == "routes"
    assert payload["event"] == "route computed"
    assert payload["distance_m"] == 42.0


def test_middleware_returns_request_id_header() -> None:
    client = TestClient(app)
    response = client.post(
        "/api/v1/verification/check",
        json={
            "session_id": "s1",
            "action_id": "a1",
            "scene_objects": [
                {"id": "o1", "type": "barrier", "temporary_blockage": True},
            ],
        },
    )
    assert response.status_code == 200
    assert response.headers.get("X-Request-Id") is not None