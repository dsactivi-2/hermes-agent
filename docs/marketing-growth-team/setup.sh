#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$ROOT/config"
ENV_FILE="$CONFIG_DIR/.env"
ENV_EXAMPLE="$CONFIG_DIR/.env.example"

if [ ! -f "$ENV_FILE" ]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  echo "Created $ENV_FILE from .env.example"
else
  echo "$ENV_FILE already exists"
fi

missing=0
for path in "$CONFIG_DIR/config.yaml" "$ROOT/agents/orchestrator/SYSTEM.md"; do
  if [ ! -f "$path" ]; then
    echo "Missing required file: $path" >&2
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  exit 1
fi

echo "Marketing & Growth team blueprint is ready."
echo "Start with: $ROOT/agents/orchestrator/SYSTEM.md"
