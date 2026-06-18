#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/create-isolated-profile.sh" --name Arnela --port 9120 --description "Arnela isolated Hermes workspace"
"$SCRIPT_DIR/create-isolated-profile.sh" --name Denis --port 9121 --description "Denis isolated Hermes workspace"
"$SCRIPT_DIR/create-isolated-profile.sh" --name Arman --port 9122 --description "Arman isolated Hermes workspace"
"$SCRIPT_DIR/create-isolated-profile.sh" --name Testing --port 9123 --description "Testing isolated Hermes workspace"

