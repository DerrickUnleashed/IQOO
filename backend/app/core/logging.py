"""Structured JSON-lines logging for the service.

Every record is emitted as a single JSON object (one per line) with
``ts``, ``level``, ``logger``, ``event`` and any structured fields.
Events are tagged with a ``stage`` (the pipeline domain that produced
them: `api`, `perception`, `scene`, `routes`, `verification`,
`assistant`, `ui`). Secrets are redacted before records are emitted.
"""

import json
import logging
import re
import sys
import time
from typing import Any, Mapping

from app.core.config import settings

_JSON_SEPARATORS = (",", ":")
_SENSITIVE = re.compile(
    r"(api[_-]?key|secret|token|authorization|password|credential|"
    r"session[_-]?id|encoded[_-]?frame|device[_-]?id)",
    re.IGNORECASE,
)
_REDACTED = "[REDACTED]"
_CONFIGURED = False


class RedactFilter(logging.Filter):
    """Replace sensitive field values with a constant redaction marker."""

    def filter(self, record: logging.LogRecord) -> bool:
        for key in list(record.__dict__.keys()):
            if _SENSITIVE.search(key):
                record.__dict__[key] = _REDACTED
        return True


class JsonFormatter(logging.Formatter):
    """Render a log record as a single-line JSON object."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "ts": f"{record.created:.3f}",
            "level": record.levelname.lower(),
            "logger": record.name,
            "event": record.getMessage(),
            "stage": getattr(record, "stage", "core"),
        }
        for key, value in record.__dict__.items():
            if key in {
                "ts", "level", "logger", "event", "stage", "args", "msg",
                "name", "created", "levelname", "levelno", "pathname",
                "filename", "module", "exc_info", "exc_text", "stack_info",
                "lineno", "funcName", "msecs", "relativeCreated", "process",
                "thread", "threadName", "taskName", "message",
            }:
                continue
            if key.startswith("_"):
                continue
            payload[key] = value
        if record.exc_info:
            payload["exc"] = "".join(
                logging.Formatter.formatException(self, record.exc_info)
            )
        return json.dumps(payload, separators=_JSON_SEPARATORS, default=str)


def configure_logging() -> None:
    """Configure structured, level-aware logging for the service."""
    global _CONFIGURED
    if _CONFIGURED:
        return

    level = logging.DEBUG if settings.DEBUG else logging.INFO

    formatter = JsonFormatter()
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)
    handler.addFilter(RedactFilter())

    root = logging.getLogger()
    root.setLevel(level)
    for existing in list(root.handlers):
        root.removeHandler(existing)
    root.addHandler(handler)
    root.addFilter(RedactFilter())

    for noisy in ("uvicorn.access", "httpx", "httpcore"):
        logging.getLogger(noisy).setLevel(logging.WARNING)

    _CONFIGURED = True


def get_logger(name: str) -> logging.Logger:
    """Return a logger configured for the application."""
    configure_logging()
    return logging.getLogger(name)


class StageLogger:
    """Logger bound to a pipeline stage that stamps structured fields.

    ``stage`` records which subsystem produced the event so traces can
    be filtered per pipeline domain:
      logger.info("scan started", extra={"stage": "perception", "frame": 12})
    """

    def __init__(self, logger: logging.Logger, stage: str) -> None:
        self._logger = logger
        self.stage = stage

    def log(
        self,
        level: int,
        event: str,
        params: Mapping[str, Any] | None = None,
        exc_info: bool = False,
    ) -> None:
        extra: dict[str, Any] = {"stage": self.stage}
        if params:
            extra.update(params)
        self._logger.log(level, event, extra=extra, exc_info=exc_info)

    def debug(self, event: str, **params: Any) -> None:
        self.log(logging.DEBUG, event, params)

    def info(self, event: str, **params: Any) -> None:
        self.log(logging.INFO, event, params)

    def warning(self, event: str, **params: Any) -> None:
        self.log(logging.WARNING, event, params)

    def error(self, event: str, **params: Any) -> None:
        self.log(logging.ERROR, event, params, exc_info=True)


def stage_logger(stage: str, name: str | None = None) -> StageLogger:
    """Return a stage-tagged logger for a pipeline domain."""
    return StageLogger(get_logger(name or f"accesscopilot.{stage}"), stage)


class Timing:
    """Small elapsed-time helper for middleware and providers."""

    def __init__(self) -> None:
        self._start = time.perf_counter()

    @property
    def elapsed_ms(self) -> float:
        return (time.perf_counter() - self._start) * 1000.0


__all__ = [
    "JsonFormatter",
    "RedactFilter",
    "StageLogger",
    "configure_logging",
    "get_logger",
    "stage_logger",
]