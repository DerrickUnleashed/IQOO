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

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter, Dart, Material 3, Riverpod, GoRouter |
| Backend | Python, FastAPI, WebSockets, PostgreSQL, PostGIS |
| AI/CV | YOLOv11, Depth Anything V2, PaddleOCR, Whisper |
| LLM | Groq (reasoning) + LangGraph (agent orchestration) |
| Routing | OSRM (outdoor), Custom graph (indoor) |
| Infra | Docker, PostgreSQL + PostGIS |

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

- Flutter SDK 3.x
- Python 3.11+
- PostgreSQL 15+ with PostGIS
- Docker (optional)

### Environment Setup

```bash
cp .env.example .env
# Edit .env with your API keys
```

### Mobile App

```bash
cd apps/mobile
flutter pub get
flutter run
```

### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Demo Mode

The application supports a deterministic demo mode for development and presentations without requiring live AI inference.

## Core Loop

```
PERCEIVE → UNDERSTAND → PERSONALIZE → PLAN → ACT → VERIFY → ADAPT
```

## Privacy

Camera and microphone data are processed locally where possible. Raw frames are discarded after structured extraction. The system follows data minimization principles.

## License

Proprietary - All rights reserved.
