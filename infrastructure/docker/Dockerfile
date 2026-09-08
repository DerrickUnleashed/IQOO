FROM python:3.11-slim

WORKDIR /app

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
# Lightweight LLM reasoning deps only — the heavy CV stack (ultralytics,
# torch) in requirements-ai.txt stays out of the default image; perception
# runs scripted here regardless, so it isn't needed.
RUN pip install --no-cache-dir "groq>=0.11,<1.0"

COPY backend/app ./app
COPY models ./models

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
