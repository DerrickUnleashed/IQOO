#!/usr/bin/env bash
set -euo pipefail

echo "Checking for potential secrets before commit..."

# Search for common secrets in staged files
COMMON_SECRET_PATTERNS=(
  "sk-[A-Za-z0-9]"
  "AIza[0-9A-Za-z_-]"
  "-----BEGIN.*PRIVATE KEY-----"
  "AKIA[0-9A-Z]{16}"
)

STAGED=$(git diff --cached --name-only)

for file in $STAGED; do
  for pattern in "${COMMON_SECRET_PATTERNS[@]}"; do
    if grep -qE "$pattern" "$file" 2>/dev/null; then
      echo "WARNING: Possible secret pattern '$pattern' in $file"
      exit 1
    fi
  done
done

echo "No secrets detected. Safe to commit."
