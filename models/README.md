# AccessCopilot Model Configurations

Model weights are downloaded at runtime and are **not** committed to the repository.

## YOLO (Object Detection)

YOLOv11 for accessibility-oriented object detection.

Accessibility-specific classes:
```
stairs, ramp, elevator, door, accessible_door, obstacle, person,
crosswalk, traffic_signal, handrail, tactile_path, wheelchair_symbol, sign
```

### Enabling real inference

1. Install the optional engines (this pulls in torch and is a large download):
   ```
   pip install -r backend/requirements-ai.txt
   ```
2. Place a checkpoint at `models/yolo/yolo11n.pt`, or point `YOLO_WEIGHTS`
   at another path (relative paths resolve against `MODELS_DIR`).
3. Set `PERCEPTION_MODE=real` (or leave it on `auto`).

`GET /api/v1/readiness` reports which engine is actually running:

```json
{"provider": "yolo", "mode": "real", "coverage": "partial"}
```

### Coverage: stock COCO weights are not enough

A stock `yolo11n.pt` is trained on COCO, which contains **none** of the
accessibility features this product depends on - no stairs, ramp, elevator,
handrail, tactile path or wheelchair symbol. With those weights the detector
reports `coverage: "partial"` and can only contribute people and path
obstructions.

Full accessibility coverage requires weights fine-tuned on the class list
above. The pipeline detects this automatically: if the loaded model's label
set includes the accessibility classes it reports `coverage: "full"`, and
otherwise it logs a warning and maps the usable COCO labels through the
bridge in `backend/app/perception/classes.py`.

Distances are never inferred from bounding-box geometry. Detections leave
this stage with `estimated_distance_m: null`; depth estimation populates it.

### Perception modes

| Mode | Behaviour |
| --- | --- |
| `auto` | Real inference when weights load, scripted playback otherwise |
| `real` | Real inference only; degrades visibly rather than substituting scripted data |
| `scripted` | Deterministic scenario playback, no inference (tests and demos) |
| `off` | Perception disabled |

Scripted detections are stamped `source: "scripted"` and
`attributes.synthetic: true` so they can never be mistaken for observations.

## Depth (Depth Anything V2)

Relative and absolute monocular depth estimation. Converts detections like
"There are stairs" into "stairs, distance ≈ 5.8m, direction = front".

## OCR (PaddleOCR)

Text detection and recognition for room numbers, signs, arrows, and
accessibility signage. Example: "LIFT →" becomes structured scene info.
