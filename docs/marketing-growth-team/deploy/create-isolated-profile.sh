#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="${TEMPLATE_DIR:-docs/marketing-growth-team}"
DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
IMAGE="${HERMES_IMAGE:-hermes-agent}"
BASE_PORT="${BASE_PORT:-9120}"
BASE_DOMAIN="${BASE_DOMAIN:-activi-apps.io}"
START_DASHBOARD=1
PROFILE_INPUT=""
DESCRIPTION=""
PORT=""

usage() {
  cat <<EOF
Usage:
  $0 [--name NAME] [--port PORT] [--domain DOMAIN] [--description TEXT] [--no-dashboard]

Creates an isolated Hermes profile from the marketing-growth template.

Examples:
  $0 --name Arnela --port 9120
  $0 --name "Sales Team" --description "Sales department workspace"
EOF
}

normalize_profile() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

port_in_use() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"
  elif command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"
  else
    return 1
  fi
}

next_free_port() {
  local port="$BASE_PORT"
  while port_in_use "$port"; do
    port=$((port + 1))
  done
  printf '%s\n' "$port"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name)
      PROFILE_INPUT="${2:-}"
      shift 2
      ;;
    --port)
      PORT="${2:-}"
      shift 2
      ;;
    --domain)
      BASE_DOMAIN="${2:-}"
      shift 2
      ;;
    --description)
      DESCRIPTION="${2:-}"
      shift 2
      ;;
    --no-dashboard)
      START_DASHBOARD=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$PROFILE_INPUT" ]; then
  read -r -p "Project/person/department name: " PROFILE_INPUT
fi

PROFILE="$(normalize_profile "$PROFILE_INPUT")"
if [ -z "$PROFILE" ]; then
  echo "Profile name becomes empty after normalization. Use letters/numbers." >&2
  exit 2
fi

if [ -z "$DESCRIPTION" ]; then
  DESCRIPTION="${PROFILE_INPUT} isolated Hermes workspace"
fi

if [ -z "$PORT" ] && [ "$START_DASHBOARD" -eq 1 ]; then
  suggested="$(next_free_port)"
  read -r -p "Dashboard port [$suggested]: " PORT
  PORT="${PORT:-$suggested}"
fi

if [ "$START_DASHBOARD" -eq 1 ] && ! printf '%s' "$PORT" | grep -Eq '^[0-9]+$'; then
  echo "Dashboard port must be numeric." >&2
  exit 2
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required." >&2
  exit 1
fi

if ! docker inspect hermes >/dev/null 2>&1; then
  echo "Container 'hermes' not found. Start the Hermes stack first." >&2
  exit 1
fi

if [ ! -f "$TEMPLATE_DIR/config/config.yaml" ]; then
  echo "Template config not found: $TEMPLATE_DIR/config/config.yaml" >&2
  exit 1
fi

if [ ! -f "$TEMPLATE_DIR/config/.env.example" ]; then
  echo "Template env example not found: $TEMPLATE_DIR/config/.env.example" >&2
  exit 1
fi

PROFILE_DIR="$DATA_ROOT/profiles/$PROFILE"
WORKSPACE_DIR="$DATA_ROOT/profile-workspaces/$PROFILE"
CONTAINER_WORKSPACE_DIR="/opt/data/profile-workspaces/$PROFILE"

echo "== Creating/updating profile: $PROFILE =="

if docker exec hermes hermes profile show "$PROFILE" >/dev/null 2>&1; then
  echo "Profile already exists: $PROFILE"
else
  docker exec hermes hermes profile create "$PROFILE" --clone --description "$DESCRIPTION"
fi

mkdir -p "$PROFILE_DIR" "$WORKSPACE_DIR"
cp -a "$TEMPLATE_DIR/." "$WORKSPACE_DIR/"

sed \
  -e "s#docs/marketing-growth-team#$CONTAINER_WORKSPACE_DIR#g" \
  -e "s#/opt/data/marketing-growth-team#$CONTAINER_WORKSPACE_DIR#g" \
  -e "s#marketing-growth#$PROFILE#g" \
  "$TEMPLATE_DIR/config/config.yaml" > "$PROFILE_DIR/config.yaml"

if [ ! -f "$PROFILE_DIR/.env" ]; then
  cp "$TEMPLATE_DIR/config/.env.example" "$PROFILE_DIR/.env"
  echo "Created $PROFILE_DIR/.env from template."
else
  echo "$PROFILE_DIR/.env exists; not overwritten."
fi

mkdir -p "$PROFILE_DIR/skills"
if [ -d "$DATA_ROOT/skills" ]; then
  cp -a "$DATA_ROOT/skills/." "$PROFILE_DIR/skills/"
fi

if [ "$START_DASHBOARD" -eq 1 ]; then
  printf '%s\n' "$PORT" > "$PROFILE_DIR/.dashboard-port"
fi

chown -R "${HERMES_UID:-10000}:${HERMES_GID:-10000}" "$PROFILE_DIR" "$WORKSPACE_DIR" 2>/dev/null || true

echo "== Migrating/checking profile =="
docker exec hermes hermes -p "$PROFILE" doctor --fix

if [ "$START_DASHBOARD" -eq 1 ]; then
  DASH_CONTAINER="hermes-dashboard-$PROFILE"
  echo "== Starting isolated dashboard: $DASH_CONTAINER on 127.0.0.1:$PORT =="
  docker rm -f "$DASH_CONTAINER" >/dev/null 2>&1 || true
  docker run -d \
    --name "$DASH_CONTAINER" \
    --restart unless-stopped \
    --network host \
    -v "$PROFILE_DIR:/opt/data" \
    -v "$WORKSPACE_DIR:/opt/data/profile-workspaces/$PROFILE" \
    -e "HERMES_HOME=/opt/data" \
    -e "HERMES_DASHBOARD_PUBLIC_URL=https://${PROFILE}.${BASE_DOMAIN}" \
    -e "HERMES_UID=${HERMES_UID:-10000}" \
    -e "HERMES_GID=${HERMES_GID:-10000}" \
    "$IMAGE" \
    dashboard --isolated --host 127.0.0.1 --port "$PORT" --no-open --skip-build >/dev/null
fi

cat <<EOF

Done.

Profile:
  $PROFILE

Server chat command:
  Hermes $PROFILE
  docker exec -it hermes hermes -p $PROFILE chat

Dashboard:
  http://127.0.0.1:${PORT:-9119}/?profile=$PROFILE

Local tunnel command to run on your local computer:
  ssh -N -L ${PORT:-9119}:127.0.0.1:${PORT:-9119} root@<SERVER_HOST>

Termius Local Forwarding:
  Local host:        127.0.0.1
  Local port:        ${PORT:-9119}
  Destination host:  127.0.0.1
  Destination port:  ${PORT:-9119}
EOF
