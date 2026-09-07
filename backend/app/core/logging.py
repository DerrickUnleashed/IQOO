import logging
import sys
from typing import Any

from app.core.config import settings

_CONFIGURED = False


def configure_logging() -> None:
    """Configure structured, level-aware logging for the service."""
    global _CONFIGURED
    if _CONFIGURED:
        return

    level = logging.DEBUG if settings.DEBUG else logging.INFO
    handlers: list[Any] = [logging.StreamHandler(sys.stdout)]

    logging.basicConfig(
        level=level,
        format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
        handlers=handlers,
        force=True,
    )

    # Keep noisy third-party loggers readable.
    for noisy in ("uvicorn.access", "httpx", "httpcore"):
        logging.getLogger(noisy).setLevel(logging.WARNING)

    _CONFIGURED = True


def get_logger(name: str) -> logging.Logger:
    """Return a logger configured for the application."""
    configure_logging()
    return logging.getLogger(name)