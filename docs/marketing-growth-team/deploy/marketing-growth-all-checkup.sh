#!/usr/bin/env bash
set -u

DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
DOMAIN="${DOMAIN:-activi-apps.io}"
PUBLIC_HOST="${PUBLIC_HOST:-46.225.222.164}"
TUNNEL_NAME="${TUNNEL_NAME:-hermes-marketing-growth}"
TUNNEL_ID="${TUNNEL_ID:-9d718440-c210-463b-a280-d41893dec0e3}"
CLOUDFLARED_CONFIG="${CLOUDFLARED_CONFIG:-/etc/cloudflared/config.yml}"
PROFILES=(arnela denis arman testing)

usage() {
  cat <<EOF
Usage:
  $0 [--domain DOMAIN] [--public-host IP_OR_HOST] [--tunnel-id UUID]

Read-only all-in checkup for the Marketing & Growth Hermes stack.
It does not modify files, containers, Cloudflare, firewall, gateways, or profiles.

Examples:
  $0
  $0 --domain activi-apps.io --public-host 46.225.222.164
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --domain)
      DOMAIN="${2:-}"
      shift 2
      ;;
    --public-host)
      PUBLIC_HOST="${2:-}"
      shift 2
      ;;
    --tunnel-id)
      TUNNEL_ID="${2:-}"
      shift 2
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

section() { printf '\n== %s ==\n' "$1"; }
value() { printf '%-38s %s\n' "$1:" "$2"; }
pass() { printf 'PASS %-36s %s\n' "$1" "$2"; }
warn() { printf 'WARN %-36s %s\n' "$1" "$2"; }
fail() { printf 'FAIL %-36s %s\n' "$1" "$2"; }
info() { printf 'INFO %-36s %s\n' "$1" "$2"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

dashboard_port() {
  case "$1" in
    arnela) printf '9120' ;;
    denis) printf '9121' ;;
    arman) printf '9122' ;;
    testing) printf '9123' ;;
    *) printf '' ;;
  esac
}

api_port() {
  case "$1" in
    arnela) printf '8643' ;;
    denis) printf '8644' ;;
    arman) printf '8645' ;;
    testing) printf '8646' ;;
    *) printf '' ;;
  esac
}

hostname_for_profile() {
  printf '%s.%s' "$1" "$DOMAIN"
}

http_code() {
  local url="$1"
  local code
  if ! command_exists curl; then
    printf 'curl-missing'
    return
  fi
  if code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 6 "$url" 2>/dev/null)"; then
    printf '%s' "$code"
  else
    printf 'fail'
  fi
}

listener_line_for_port() {
  local port="$1"
  if [ -z "$port" ]; then
    return
  fi
  if command_exists ss; then
    ss -ltnp 2>/dev/null | awk -v port=":${port}" '$4 ~ port {print}'
  elif command_exists netstat; then
    netstat -ltnp 2>/dev/null | awk -v port=":${port}" '$4 ~ port {print}'
  fi
}

extract_dashboard_token() {
  local port="$1"
  command_exists curl || return
  curl -sS --max-time 6 "http://127.0.0.1:${port}/" 2>/dev/null \
    | sed -n 's/.*window.__HERMES_SESSION_TOKEN__="\([^"]*\)".*/\1/p' \
    | head -1
}

visible_profiles() {
  local port="$1"
  local token
  token="$(extract_dashboard_token "$port")"
  if [ -z "$token" ] || ! command_exists curl; then
    printf 'unknown'
    return
  fi
  curl -sS --max-time 6 \
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

container_status() {
  local container="$1"
  if ! command_exists docker || ! docker inspect "$container" >/dev/null 2>&1; then
    printf 'missing'
    return
  fi
  docker inspect -f '{{.State.Status}} exit={{.State.ExitCode}} image={{.Config.Image}}' "$container" 2>/dev/null
}

container_env_value() {
  local container="$1"
  local key="$2"
  command_exists docker || return
  docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$container" 2>/dev/null \
    | sed -n "s/^${key}=//p" \
    | tail -1
}

container_mounts() {
  local container="$1"
  command_exists docker || return
  docker inspect -f '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}' "$container" 2>/dev/null
}

has_mount_destination() {
  local container="$1"
  local dest="$2"
  container_mounts "$container" | awk -F' -> ' -v dest="$dest" '$2 == dest {found=1} END {exit found ? 0 : 1}'
}

logs_contain_recent() {
  local container="$1"
  local pattern="$2"
  command_exists docker || return 1
  docker logs "$container" --tail 200 2>/dev/null | grep -Eiq "$pattern"
}

gateway_status_for_profile() {
  local profile="$1"
  local output
  if ! command_exists docker || ! docker inspect hermes >/dev/null 2>&1; then
    printf 'unknown'
    return
  fi
  output="$(docker exec hermes hermes -p "$profile" gateway status 2>/dev/null || true)"
  if [ -z "$output" ]; then
    printf 'unknown'
    return
  fi
  if printf '%s\n' "$output" | grep -Eiq 'Gateway:[[:space:]]+running|Gateway is running|✓ Gateway is running'; then
    printf 'running'
  elif printf '%s\n' "$output" | grep -Eiq 'Gateway:[[:space:]]+stopped|Gateway is stopped|not running|stopped'; then
    printf 'stopped'
  else
    printf 'unknown'
  fi
}

mask_secret() {
  local value="$1"
  if [ -z "$value" ]; then
    printf 'not set'
  elif [ "${#value}" -le 10 ]; then
    printf 'set length=%s' "${#value}"
  else
    printf '%s...%s length=%s' "${value:0:6}" "${value: -4}" "${#value}"
  fi
}

env_value() {
  local file="$1"
  local key="$2"
  [ -f "$file" ] || return
  grep -E "^${key}=" "$file" 2>/dev/null | tail -1 | cut -d= -f2-
}

section "All-In Checkup"
value "date utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
value "cwd" "$(pwd)"
value "data root" "$DATA_ROOT"
value "domain" "$DOMAIN"
value "public host" "$PUBLIC_HOST"
value "tunnel name" "$TUNNEL_NAME"
value "tunnel id" "$TUNNEL_ID"
if command_exists git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  value "git branch" "$(git branch --show-current 2>/dev/null || true)"
  value "git head" "$(git rev-parse --short HEAD 2>/dev/null || true)"
  dirty="$(git status --short docs/marketing-growth-team hermes_cli/web_server.py tests/hermes_cli/test_dashboard_auth_ws_auth.py 2>/dev/null | wc -l | tr -d ' ')"
  value "git dirty relevant" "$dirty changed/untracked"
fi

section "Required Tools"
for tool in docker curl python3 ss systemctl cloudflared; do
  if command_exists "$tool"; then
    pass "$tool" "$(command -v "$tool")"
  else
    warn "$tool" "not found"
  fi
done

section "Docker Containers"
if command_exists docker; then
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null || true
else
  fail "docker" "not available"
fi

section "Cloudflared"
if command_exists systemctl; then
  if systemctl is-active --quiet cloudflared 2>/dev/null; then
    pass "cloudflared service" "active"
  else
    warn "cloudflared service" "not active"
  fi
fi
if command_exists cloudflared; then
  cloudflared --version 2>/dev/null || true
fi
if [ -f "$CLOUDFLARED_CONFIG" ]; then
  value "config" "$CLOUDFLARED_CONFIG"
  if grep -q '^protocol: http2$' "$CLOUDFLARED_CONFIG"; then
    pass "cloudflared protocol" "http2"
  else
    warn "cloudflared protocol" "missing protocol: http2"
  fi
  for profile in "${PROFILES[@]}"; do
    host="$(hostname_for_profile "$profile")"
    if grep -q "hostname: ${host}" "$CLOUDFLARED_CONFIG"; then
      pass "cloudflared hostname $profile" "$host"
    else
      fail "cloudflared hostname $profile" "$host missing"
    fi
  done
  count_host_header="$(grep -c 'httpHostHeader: 127.0.0.1' "$CLOUDFLARED_CONFIG" 2>/dev/null || printf '0')"
  if [ "$count_host_header" -ge 4 ]; then
    pass "cloudflared host header" "127.0.0.1 entries=$count_host_header"
  else
    warn "cloudflared host header" "expected 4 entries, got $count_host_header"
  fi
else
  fail "cloudflared config" "$CLOUDFLARED_CONFIG missing"
fi

section "Per-Profile Dashboard/API"
printf '%-8s %-9s %-10s %-13s %-12s %-14s %-22s\n' \
  "PROFILE" "DASH" "API" "VISIBLE" "CF-ORIGIN" "GATEWAY" "PUBLIC"
for profile in "${PROFILES[@]}"; do
  dash_port="$(dashboard_port "$profile")"
  api_port="$(api_port "$profile")"
  container="hermes-dashboard-${profile}"
  dash_code="$(http_code "http://127.0.0.1:${dash_port}/")"
  api_code="$(http_code "http://127.0.0.1:${api_port}/health")"
  visible="$(visible_profiles "$dash_port")"
  public_url="$(container_env_value "$container" HERMES_DASHBOARD_PUBLIC_URL)"
  single_profile="$(container_env_value "$container" HERMES_DASHBOARD_SINGLE_PROFILE)"
  gateway_state="$(gateway_status_for_profile "$profile")"
  printf '%-8s %-9s %-10s %-13s %-12s %-14s %-22s\n' \
    "$profile" "local:$dash_code" "local:$api_code" "$visible" \
    "${public_url:+set}" "$gateway_state" "https://$(hostname_for_profile "$profile")"

  if [ "$dash_code" = "200" ]; then
    pass "$profile dashboard local" "http://127.0.0.1:${dash_port}/"
  else
    fail "$profile dashboard local" "http_code=$dash_code"
  fi
  if [ "$api_code" = "200" ]; then
    pass "$profile api local" "http://127.0.0.1:${api_port}/health"
  else
    warn "$profile api local" "http_code=$api_code"
  fi
  expected_public="https://$(hostname_for_profile "$profile")"
  if [ "$public_url" = "$expected_public" ]; then
    pass "$profile public origin env" "$public_url"
  else
    warn "$profile public origin env" "expected=$expected_public actual=${public_url:-missing}"
  fi
  if [ "$visible" = "$profile" ]; then
    pass "$profile visible profiles" "$visible"
  elif [ "$visible" = "unknown" ] || [ "$visible" = "parse-failed" ]; then
    warn "$profile visible profiles" "$visible"
  else
    fail "$profile visible profiles" "sibling exposure? $visible"
  fi
  if [ "$single_profile" = "$profile" ]; then
    pass "$profile single profile env" "$single_profile"
  else
    warn "$profile single profile env" "expected=$profile actual=${single_profile:-missing}"
  fi
done

section "Dashboard Container Isolation"
for profile in "${PROFILES[@]}"; do
  container="hermes-dashboard-${profile}"
  profile_dir="${DATA_ROOT}/profiles/${profile}"
  workspace_dir="${DATA_ROOT}/profile-workspaces/${profile}"
  printf '\n-- %s --\n' "$profile"
  value "container status" "$(container_status "$container")"
  value "HERMES_HOME" "$(container_env_value "$container" HERMES_HOME)"
  value "HERMES_DASHBOARD_SINGLE_PROFILE" "$(container_env_value "$container" HERMES_DASHBOARD_SINGLE_PROFILE)"
  value "HERMES_DASHBOARD_PUBLIC_URL" "$(container_env_value "$container" HERMES_DASHBOARD_PUBLIC_URL)"
  value "container API_SERVER_ENABLED" "$(container_env_value "$container" API_SERVER_ENABLED)"
  value "mounts" ""
  container_mounts "$container" | sed 's#^#  #'

  if has_mount_destination "$container" "/opt/data" \
    && container_mounts "$container" | grep -q "^${DATA_ROOT} -> /opt/data$"; then
    fail "$profile broad root mount" "${DATA_ROOT} -> /opt/data"
  else
    pass "$profile no broad root mount" "ok"
  fi
  if has_mount_destination "$container" "/opt/data/profiles/${profile}"; then
    pass "$profile profile mount" "${profile_dir}"
  else
    warn "$profile profile mount" "missing /opt/data/profiles/${profile}"
  fi
  if has_mount_destination "$container" "/opt/data/profile-workspaces/${profile}"; then
    pass "$profile workspace mount" "${workspace_dir}"
  else
    warn "$profile workspace mount" "missing /opt/data/profile-workspaces/${profile}"
  fi
  if [ "$(container_env_value "$container" API_SERVER_ENABLED)" = "false" ]; then
    pass "$profile dashboard api disabled" "API_SERVER_ENABLED=false"
  else
    warn "$profile dashboard api disabled" "container should set API_SERVER_ENABLED=false"
  fi
done

section "Recent Dashboard Errors"
for profile in "${PROFILES[@]}"; do
  container="hermes-dashboard-${profile}"
  if logs_contain_recent "$container" 'origin_mismatch|pty refused'; then
    fail "$profile websocket origin" "recent origin_mismatch/pty refused in logs"
  else
    pass "$profile websocket origin" "no recent origin_mismatch/pty refused"
  fi
  if logs_contain_recent "$container" 'Port 864[0-9] already in use'; then
    warn "$profile dashboard gateway" "old API port collision in recent logs; recreate container if it persists"
  else
    pass "$profile dashboard gateway" "no recent API port collision"
  fi
  if logs_contain_recent "$container" "no such gateway '${profile}'"; then
    warn "$profile restart button" "dashboard restart button cannot restart this isolated gateway"
  fi
done

section "Profile Env, Masked"
for profile in "${PROFILES[@]}"; do
  env_file="${DATA_ROOT}/profiles/${profile}/.env"
  soul_file="${DATA_ROOT}/profiles/${profile}/SOUL.md"
  printf '\n-- %s --\n' "$profile"
  value "env file" "$env_file"
  value "API_SERVER_ENABLED" "$(env_value "$env_file" API_SERVER_ENABLED)"
  value "API_SERVER_HOST" "$(env_value "$env_file" API_SERVER_HOST)"
  value "API_SERVER_PORT" "$(env_value "$env_file" API_SERVER_PORT)"
  value "API_SERVER_KEY" "$(mask_secret "$(env_value "$env_file" API_SERVER_KEY)")"
  if [ -f "$soul_file" ] && grep -q 'marketing-growth-orchestrator-persona:managed' "$soul_file"; then
    pass "$profile orchestrator persona" "SOUL.md bound"
  else
    warn "$profile orchestrator persona" "run bind-orchestrator-persona.sh $profile"
  fi
done

section "Recommended Next Checks"
cat <<EOF
# Browser:
#   1. Open a private/incognito window.
#   2. Visit https://denis.${DOMAIN}
#   3. Confirm Cloudflare Access login appears when no Access session exists.
#   4. Confirm the profile switcher shows only: denis.
#   5. Confirm "events feed disconnected" is gone.

# If events feed still disconnects:
docker logs hermes-dashboard-denis --tail 160 | grep -i "origin_mismatch\\|pty refused\\|websocket\\|api/pty" || true
journalctl -u cloudflared -n 120 --no-pager

# If a dashboard can see sibling profiles:
bash docs/marketing-growth-team/deploy/harden-dashboard-containers.sh --apply --domain ${DOMAIN}

# Do not use the dashboard "Restart gateway" button for these isolated dashboards.
# Restart gateways from the main container instead:
for p in arnela denis arman testing; do
  docker exec hermes hermes -p "\$p" gateway status || true
done
EOF
