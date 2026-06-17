#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

mkdir -p "$HERMES_HOME"
mkdir -p "$HERMES_HOME/skills/marketing-growth"
mkdir -p "$HERMES_HOME/campaigns/step2job"

if [ ! -f "$HERMES_HOME/.env" ]; then
  cp "$ROOT_DIR/config/.env.example" "$HERMES_HOME/.env"
  echo "Created $HERMES_HOME/.env from template. Add API keys before production use."
fi

if [ ! -f "$HERMES_HOME/config.yaml" ]; then
  cp "$ROOT_DIR/config/config.yaml" "$HERMES_HOME/config.yaml"
  echo "Created $HERMES_HOME/config.yaml from marketing-growth template."
else
  echo "$HERMES_HOME/config.yaml already exists. Merge $ROOT_DIR/config/config.yaml manually if needed."
fi

echo
echo "Recommended checks:"
echo "  hermes doctor"
echo "  hermes skills list"
echo "  hermes plugins list"
echo "  hermes mcp test marketing_fs"
echo
echo "Start CLI:"
echo "  hermes chat --profile marketing-growth"
echo
echo "Start Web Dashboard:"
echo "  hermes dashboard --profile marketing-growth"

