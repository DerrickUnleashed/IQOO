"""Perception and scene update endpoints."""

import time

from fastapi import APIRouter, Depends

from app.perception.provider import PerceptionProvider
from app.schemas.perception import (
    AnalyzeFrameRequest,
    AnalyzeFrameResponse,
    Detection,
)
from app.schemas.scene import SceneUpdate, SceneUpdateResponse
from app.services.scene import SceneGraphService

from .dependencies import get_perception_provider, get_scene_service

router = APIRouter(tags=["perception"])


@router.post("/perception/analyze", response_model=AnalyzeFrameResponse)
async def analyze_frame(
    req: AnalyzeFrameRequest,
    provider: PerceptionProvider = Depends(get_perception_provider),
) -> AnalyzeFrameResponse:
    start = time.perf_counter()
    frame = req.encoded_frame or b""
    detections: list[Detection] = await provider.analyze_frame(frame)
    # The client needs to know how the scene was produced: scripted playback
    # and partial-coverage weights must never read as a confident observation.
    summary = {
        **provider.status(),
        "detection_count": len(detections),
        "frame_received": bool(frame),
    }
    return AnalyzeFrameResponse(
        frame_id=req.frame_id,
        detections=detections,
        scene_summary=summary,
        processing_ms=int((time.perf_counter() - start) * 1000),
    )


@router.post("/scene/update", response_model=SceneUpdateResponse)
async def update_scene(
    req: SceneUpdate,
    service: SceneGraphService = Depends(get_scene_service),
) -> SceneUpdateResponse:
    """Apply detections to the stateful scene graph for a session."""
    scene = service.apply(session_id=req.session_id, detections=req.detections)
    return SceneUpdateResponse(
        session_id=req.session_id,
        scene_objects=scene["scene_objects"],
        updated_at=scene["updated_at"],
        observation_id=scene.get("observation_id"),
    )