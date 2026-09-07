"""Route calculation and replanning endpoints."""

from fastapi import APIRouter, Depends

from app.routing.engine import RouteEngine
from app.schemas.route import ReplanRequest, Route, RouteRequest

from .dependencies import get_route_engine

router = APIRouter(tags=["routes"])


@router.post("/routes/calculate", response_model=Route)
def calculate_route(
    req: RouteRequest,
    engine: RouteEngine = Depends(get_route_engine),
) -> Route:
    """Calculate an accessibility-aware route for the user's profile."""
    return engine.calculate(req.origin, req.destination, req.profile)


@router.post("/routes/replan", response_model=Route)
def replan_route(
    req: ReplanRequest,
    engine: RouteEngine = Depends(get_route_engine),
) -> Route:
    """Replan from the current position when the route is blocked."""
    return engine.replan(req.current, req.destination, req.profile, req.reason)