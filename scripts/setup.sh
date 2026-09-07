#!/usr/bin/env bash
set -euo pipefail

echo "Setting up AccessCopilot development environment..."

# Create .env from example if it doesn't exist
if [ ! -f ".env" ]; then
  cp .env.example .env
  echo "Created .env from .env.example (edit it with your keys)"
else
  echo ".env already exists, skipping"
fi

echo "Done."
