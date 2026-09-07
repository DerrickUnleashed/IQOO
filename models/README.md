# AccessCopilot Model Configurations

Model weights are downloaded at runtime and are **not** committed to the repository.

## YOLO (Object Detection)

YOLOv11 for accessibility-oriented object detection.

Accessibility-specific classes:
```
stairs, ramp, elevator, door, accessible_door, obstacle, person,
crosswalk, traffic_signal, handrail, tactile_path, wheelchair_symbol, sign
```

## Depth (Depth Anything V2)

Relative and absolute monocular depth estimation. Converts detections like
"There are stairs" into "stairs, distance ≈ 5.8m, direction = front".

## OCR (PaddleOCR)

Text detection and recognition for room numbers, signs, arrows, and
accessibility signage. Example: "LIFT →" becomes structured scene info.
