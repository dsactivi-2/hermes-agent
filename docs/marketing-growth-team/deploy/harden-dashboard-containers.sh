#!/usr/bin/env bash
set -u

DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
IMAGE="${HERMES_IMAGE:-}"
BASE_DOMAIN="${BASE_DOMAIN:-activi-apps.io}"
APPLY=false

usage() {
  cat <<EOF
Usage:
  $0 [--apply] [--domain DOMAIN] [profile...]

Read-only by default. Checks whether each Marketing & Growth dashboard
container can see all Hermes profiles or only its own profile.

With --apply, recreates each dashboard container with narrow mounts:
- profile directory mounted as /opt/data/profiles/<profile>
- matching profile workspace mounted under /opt/data/profile-workspaces/<profile>

This prevents a dashboard opened through one profile hostname from using the
dashboard API to read/write sibling profile homes.

Defaults:
  profiles: arnela denis arman testing

Examples:
  $0
  $0 --apply
  $0 --apply --domain activi-apps.io
  $0 --apply denis arman
EOF
}

profiles=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=true
      shift
      ;;
    --domain)
      BASE_DOMAIN="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        profiles+=("$1")
        shift
      done
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      profiles+=("$1")
      shift
      ;;
  esac
done

if [ "${#profiles[@]}" -eq 0 ]; then
  profiles=(arnela denis arman testing)
fi

section() {
  printf '\n== %s ==\n' "$1"
}

value() {
  printf '%-34s %s\n' "$1:" "$2"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

dashboard_port() {
  case "$1" in
    arnela) printf '9120' ;;
    denis) printf '9121' ;;
    arman) printf '9122' ;;
    testing) printf '9123' ;;
    *) printf '' ;;
  esac
}

http_code() {
  local url="$1"
  local code
  if command_exists curl; then
    if code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 4 "$url" 2>/dev/null)"; then
      printf '%s' "$code"
    else
      printf 'fail'
    fi
  else
    printf 'curl-missing'
  fi
}

container_image() {
  local container="$1"
  if [ -n "$IMAGE" ]; then
    printf '%s' "$IMAGE"
    return
  fi
  if command_exists docker && docker inspect "$container" >/dev/null 2>&1; then
    docker inspect -f '{{.Config.Image}}' "$container" 2>/dev/null
  else
    printf 'hermes-agent'
  fi
}

mount_summary() {
  local container="$1"
  if ! command_exists docker || ! docker inspect "$container" >/dev/null 2>&1; then
    printf 'container not found'
    return
  fi
  docker inspect -f '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}' "$container" 2>/dev/null \
    | sed 's#^#  #'
}

extract_dashboard_token() {
  local port="$1"
  if ! command_exists curl; then
    return
  fi
  curl -sS --max-time 4 "http://127.0.0.1:${port}/" 2>/dev/null \
    | sed -n 's/.*window.__HERMES_SESSION_TOKEN__="\([^"]*\)".*/\1/p' \
    | head -1
}

profile_count_from_dashboard() {
  local port="$1"
  local token
  token="$(extract_dashboard_token "$port")"
  if [ -z "$token" ] || ! command_exists curl; then
    printf 'unknown'
    return
  fi
  curl -sS --max-time 4 \
    -H "X-Hermes-Session-Token: $token" \
    "http://127.0.0.1:${port}/api/profiles" 2>/dev/null \
    | python3 -c 'import json,sys
try:
    data=json.load(sys.stdin)
    profiles=data.get("profiles") or []
    print(",".join(p.get("name","?") for p in profiles) or "none")
except Exception:
    print("parse-failed")
' 2>/dev/null || printf 'unknown'
}

recreate_dashboard() {
  local profile="$1"
  local port="$2"
  local container="hermes-dashboard-${profile}"
  local profile_dir="${DATA_ROOT}/profiles/${profile}"
  local workspace_dir="${DATA_ROOT}/profile-workspaces/${profile}"
  local image

  if [ ! -d "$profile_dir" ]; then
    echo "Profile directory not found: $profile_dir" >&2
    return 1
  fi
  if [ ! -d "$workspace_dir" ]; then
    echo "Workspace directory not found: $workspace_dir" >&2
    return 1
  fi

  image="$(container_image "$container")"
  docker rm -f "$container" >/dev/null 2>&1 || true
  docker run -d \
    --name "$container" \
    --restart unless-stopped \
    --network host \
    -v "${profile_dir}:/opt/data/profiles/${profile}" \
    -v "${workspace_dir}:/opt/data/profile-workspaces/${profile}" \
    -e "HERMES_HOME=/opt/data/profiles/${profile}" \
    -e "HERMES_DASHBOARD_PUBLIC_URL=https://${profile}.${BASE_DOMAIN}" \
    -e "HERMES_UID=${HERMES_UID:-10000}" \
    -e "HERMES_GID=${HERMES_GID:-10000}" \
    "$image" \
    dashboard --isolated --host 127.0.0.1 --port "$port" --no-open --skip-build >/dev/null
}

if ! command_exists docker; then
  echo "docker is required." >&2
  exit 1
fi

section "Dashboard Isolation"
value "mode" "$([ "$APPLY" = true ] && printf apply || printf read-only)"
value "data root" "$DATA_ROOT"
value "base domain" "$BASE_DOMAIN"

for profile in "${profiles[@]}"; do
  port="$(dashboard_port "$profile")"
  container="hermes-dashboard-${profile}"
  profile_dir="${DATA_ROOT}/profiles/${profile}"
  workspace_dir="${DATA_ROOT}/profile-workspaces/${profile}"

  printf '\n-- %s --\n' "$profile"
  value "container" "$container"
  value "dashboard port" "${port:-unknown}"
  value "profile dir" "$profile_dir -> /opt/data/profiles/$profile"
  value "workspace dir" "$workspace_dir -> /opt/data/profile-workspaces/$profile"
  value "public url" "https://${profile}.${BASE_DOMAIN}"
  value "local http before" "$(http_code "http://127.0.0.1:${port}/")"
  value "profiles visible before" "$(profile_count_from_dashboard "$port")"
  value "mounts before" ""
  mount_summary "$container"

  if [ "$APPLY" = true ]; then
    value "action" "recreate with narrow profile mounts"
    if recreate_dashboard "$profile" "$port"; then
      sleep 1
      value "local http after" "$(http_code "http://127.0.0.1:${port}/")"
      value "profiles visible after" "$(profile_count_from_dashboard "$port")"
      value "mounts after" ""
      mount_summary "$container"
    else
      value "recreate" "failed"
    fi
  fi
done

cat <<'EOF'

Expected hardened result:
- Mounts no longer show the whole Hermes data root mounted to /opt/data.
- Each dashboard sees only its own profile mounted under /opt/data/profiles.
- /api/profiles should not list sibling profiles.

Cloudflare Access still controls who can reach each hostname. This script
controls what that hostname's dashboard can see after login.
EOF
