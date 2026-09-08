# AccessCopilot

**An AI-powered accessibility action engine**

> Do not merely tell the user what is around them. Determine what the user should safely do next, based on the environment, their accessibility profile, their destination, and the current task.

---

## Problem Statement

People with disabilities face daily navigation challenges that existing solutions fail to address adequately. Current apps tell you *what* is around you, but not *what to do next*. They don't personalize recommendations, don't verify actions, and don't adapt when plans fail.

## Solution

AccessCopilot is a camera-to-action accessibility copilot that:

1. **Perceives** the environment using computer vision, depth estimation, and OCR
2. **Understands** the scene through an accessibility scene graph
3. **Personalizes** recommendations based on user accessibility profiles
4. **Plans** accessible routes using cost-aware graph traversal
5. **Acts** by providing clear, actionable voice instructions
6. **Verifies** user progress through camera feedback
7. **Adapts** by replanning when routes fail

## Key Innovation

The system separates **perception** (YOLO, depth, OCR) from **reasoning** (Groq LLM) from **safety rules** (deterministic constraints). The LLM generates natural language but cannot override safety-critical decisions.

## Architecture

```
                 ┌──────────────────────┐
                 │      FLUTTER APP     │
                 │  Camera / Mic / GPS  │
                 │  TTS / UI / Haptics  │
                 └──────────┬───────────┘
                            │
                 ┌──────────▼───────────┐
                 │      FASTAPI         │
                 │      BACKEND         │
                 └──────────┬───────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
        Perception       Scene Graph    Location
        YOLO/Depth/OCR   PostGIS        OSM/OSRM
              │             │             │
              └──────┬──────┘             │
                     ▼                    │
              Structured Scene ───────────┘
                     │
              Accessibility Rules
                     │
                Route Engine
                     │
                 LangGraph
              ┌──────┴──────┐
              ▼             ▼
           Groq         Route Planner
              │             │
              └──────┬──────┘
                     ▼
              Action Planner
                     │
              Voice Guidance
                     │
                 USER ACTION
                     │
              CAMERA VERIFY
               ┌─────┴─────┐
               ▼           ▼
            SUCCESS      FAILURE
               │           │
               ▼           ▼
            CONTINUE     REPLAN
```

## Tech Stack

| Layer | Technology | Status |
|-------|-----------|--------|
| Mobile | Flutter, Dart, Riverpod, GoRouter | Built |
| Backend | Python, FastAPI, PostgreSQL, PostGIS | Built |
| Perception | YOLOv11 (real, optional) or scripted scenarios | Built |
| Reasoning | Groq (grounded in the scene graph, degrades to deterministic phrasing) | Built |
| Scene graph | Stateful, per-session, deterministic accessibility rules | Built |
| Depth, OCR | Depth Anything V2, PaddleOCR | Planned |
| Agent orchestration | LangGraph (full PERCEIVE→PLAN→VERIFY state graph) | Planned |
| Routing | OSRM (outdoor), custom graph (indoor) | Planned |
| Infra | Docker, PostgreSQL + PostGIS | Built |

Perception and reasoning each have a real mode and an honest degraded mode — see [`models/README.md`](models/README.md) and `PERCEPTION_MODE` / `GROQ_API_KEY` in `.env.example`. Neither silently fakes the other; a missing key or missing weights degrades visibly instead of pretending.

## Project Structure

```
accesscopilot/
├── apps/mobile/          # Flutter application
├── backend/              # FastAPI backend
├── models/               # AI model configs
├── infrastructure/       # Docker, database migrations
├── docs/                 # Documentation
└── scripts/              # Build/utility scripts
```

## Getting Started

### Prerequisites

- Flutter SDK (stable channel)
- Python 3.11+
- Docker + Docker Compose (recommended — runs PostgreSQL/PostGIS and the backend together)

### Environment Setup

```bash
cp .env.example .env
```

Everything runs in degraded/scripted mode with the defaults as-is — no keys required. To enable real Groq reasoning, add a free key from [console.groq.com/keys](https://console.groq.com/keys) as `GROQ_API_KEY`.

If you already run PostgreSQL locally on port 5432, set `POSTGRES_HOST_PORT` in `.env` to something else (e.g. `5433`) before starting the containers, or the `db` container's port publish will silently fail to bind.

### Backend

```bash
docker compose up -d --build
curl http://localhost:8000/api/v1/readiness   # confirms perception + reasoning mode
```

Or without Docker:

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
```

`requirements-ai.txt` is optional — install it to enable real YOLO perception and Groq reasoning locally outside Docker; the backend runs fully without it.

### Mobile App

```bash
cd apps/mobile
flutter pub get
flutter run -d chrome   # or a connected device/emulator
```

If the project and your global Pub cache are on different drives on Windows, set `PUB_CACHE` to a path on the same drive as the project first — Kotlin's incremental compiler can't resolve relative paths across drive letters and the Android build will fail with an unrelated-looking error.

### Demo Mode

Both perception and reasoning have a deterministic, non-AI fallback (five scripted scenarios: stairs+ramp, stairs+elevator, blocked corridor, room navigation, outdoor crossing — see `PERCEPTION_MODE` and `DEMO_SCENARIO` in `.env.example`), so the full PERCEIVE → PLAN → VERIFY loop works end-to-end for development and demos without any live AI inference or API keys.

## Core Loop

```
PERCEIVE → UNDERSTAND → PERSONALIZE → PLAN → ACT → VERIFY → ADAPT
```

## Privacy

Camera and microphone data are processed locally where possible. Raw frames are discarded after structured extraction. The system follows data minimization principles.

## License

Proprietary - All rights reserved.
