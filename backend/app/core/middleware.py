"""ASGI middleware emitting structured request lifecycle logs.

A request id is minted per call (and surfaced via the ``X-Request-Id``
header) so a single trace can be correlated across api, perception,
routing and agent stages.
"""

import uuid

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.core.logging import StageLogger, Timing

MIDDLEWARE_LOGGER = None


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Logs every request/response lifecycle with timing and status."""

    def __init__(self, app, logger=None) -> None:
        super().__init__(app)
        self._logger = logger or _stage()

    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = uuid.uuid4().hex[:16]
        timing = Timing()

        self._logger.info(
            "request started",
            request_id=request_id,
            method=request.method,
            path=request.url.path,
        )

        response = await call_next(request)

        self._logger.info(
            "request completed",
            request_id=request_id,
            method=request.method,
            path=request.url.path,
            status=response.status_code,
            duration_ms=round(timing.elapsed_ms, 1),
        )
        response.headers["X-Request-Id"] = request_id
        return response


def _stage() -> StageLogger:
    from app.core.logging import stage_logger

    return stage_logger("api", "accesscopilot.api")