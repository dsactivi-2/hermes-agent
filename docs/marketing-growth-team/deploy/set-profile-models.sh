#!/usr/bin/env bash
set -euo pipefail

PROVIDER="${PROVIDER:-openrouter}"
MODEL="${MODEL:-x-ai/grok-4.3}"
PROFILES=()
RUN_DOCTOR=1
RESTART_GATEWAY=0

usage() {
  cat <<EOF
Usage:
  $0 [--provider PROVIDER] [--model MODEL] [--no-doctor] [--restart-gateway] [profile...]

Sets Hermes model defaults for one or more profiles.

Defaults:
  provider: $PROVIDER
  model:    $MODEL
  profiles: arnela denis arman testing

Examples:
  $0
  $0 --provider openrouter --model x-ai/grok-4.3 arnela denis
  $0 --provider openrouter --model anthropic/claude-sonnet-4.6 --restart-gateway
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --provider)
      PROVIDER="${2:-}"
      shift 2
      ;;
    --model)
      MODEL="${2:-}"
      shift 2
      ;;
    --no-doctor)
      RUN_DOCTOR=0
      shift
      ;;
    --restart-gateway)
      RESTART_GATEWAY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        PROFILES+=("$1")
        shift
      done
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      PROFILES+=("$1")
      shift
      ;;
  esac
done

if [ -z "$PROVIDER" ] || [ -z "$MODEL" ]; then
  echo "Provider and model must not be empty." >&2
  exit 2
fi

if [ "${#PROFILES[@]}" -eq 0 ]; then
  PROFILES=(arnela denis arman testing)
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required." >&2
  exit 1
fi

if ! docker inspect hermes >/dev/null 2>&1; then
  echo "Container 'hermes' not found. Start the Hermes stack first." >&2
  exit 1
fi

echo "Setting model defaults:"
echo "  provider: $PROVIDER"
echo "  model:    $MODEL"
echo "  profiles: ${PROFILES[*]}"
echo

for profile in "${PROFILES[@]}"; do
  echo "== $profile =="
  if ! docker exec hermes hermes profile show "$profile" >/dev/null 2>&1; then
    echo "Profile not found: $profile" >&2
    exit 1
  fi

  docker exec hermes hermes -p "$profile" config set model.provider "$PROVIDER"
  docker exec hermes hermes -p "$profile" config set model.model "$MODEL"

  if [ "$RUN_DOCTOR" -eq 1 ]; then
    docker exec hermes hermes -p "$profile" doctor --fix >/dev/null
  fi

  if [ "$RESTART_GATEWAY" -eq 1 ]; then
    docker exec hermes hermes -p "$profile" gateway restart >/dev/null 2>&1 \
      || docker exec hermes hermes -p "$profile" gateway start >/dev/null 2>&1 \
      || true
  fi

  docker exec hermes hermes profile show "$profile" | sed -n '1,8p'
  echo
done

cat <<EOF
Done.

If a dashboard chat is already open, refresh/reconnect that profile's dashboard.
If API gateways are running, use --restart-gateway next time or restart them now.
EOF

