#!/usr/bin/env bash
set -u

DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
PUBLIC_HOST="${PUBLIC_HOST:-}"
PROFILES=()

usage() {
  cat <<EOF
Usage:
  $0 [--public-host HOST_OR_IP] [profile...]

Read-only preflight for per-profile Hermes API isolation.

It checks the current state only. It does not modify env files, configs,
containers, gateways, firewall rules, or Cloudflare.

What it verifies per profile:
  - profile directory and .env/config presence
  - API_SERVER_ENABLED / HOST / PORT / KEY / MODEL_NAME from profile .env
  - API key fingerprint uniqueness without printing the key
  - expected API port mapping
  - local listener and /health /v1/models HTTP status
  - docker/hermes gateway status
  - dashboard containers do not run embedded API servers

Defaults:
  profiles: arnela denis arman testing

Examples:
  $0
  $0 --public-host 46.225.222.164
  $0 denis
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --public-host)
      PUBLIC_HOST="${2:-}"
      shift 2
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

if [ "${#PROFILES[@]}" -eq 0 ]; then
  PROFILES=(arnela denis arman testing)
fi

section() { printf '\n== %s ==\n' "$1"; }
value() { printf '%-38s %s\n' "$1:" "$2"; }
pass() { printf 'PASS %-36s %s\n' "$1" "$2"; }
warn() { printf 'WARN %-36s %s\n' "$1" "$2"; }
fail() { printf 'FAIL %-36s %s\n' "$1" "$2"; }
info() { printf 'INFO %-36s %s\n' "$1" "$2"; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

api_port() {
  case "$1" in
    arnela) printf '8643' ;;
    denis) printf '8644' ;;
    arman) printf '8645' ;;
    testing) printf '8646' ;;
    *) printf '' ;;
  esac
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

env_value() {
  local file="$1"
  local key="$2"
  [ -f "$file" ] || return
  grep -E "^${key}=" "$file" 2>/dev/null | tail -1 | cut -d= -f2-
}

fingerprint_secret() {
  local value="$1"
  if [ -z "$value" ]; then
    printf 'missing'
    return
  fi
  if command_exists sha256sum; then
    printf 'sha256:%s length=%s' "$(printf '%s' "$value" | sha256sum | awk '{print substr($1,1,12)}')" "${#value}"
  elif command_exists shasum; then
    printf 'sha256:%s length=%s' "$(printf '%s' "$value" | shasum -a 256 | awk '{print substr($1,1,12)}')" "${#value}"
  else
    printf 'set length=%s' "${#value}"
  fi
}

http_code() {
  local url="$1"
  local code
  if ! command_exists curl; then
    printf 'curl-missing'
    return
  fi
  code="$(curl -sS -o /tmp/hermes-api-preflight-body.$$ -w '%{http_code}' --max-time 5 "$url" 2>/tmp/hermes-api-preflight-curl.$$ || true)"
  if [ "$code" = "000" ] || [ -z "$code" ]; then
    printf 'fail'
  else
    printf '%s' "$code"
  fi
}

http_body_head() {
  if [ -s /tmp/hermes-api-preflight-body.$$ ]; then
    sed -n '1,2p' /tmp/hermes-api-preflight-body.$$
  fi
  rm -f /tmp/hermes-api-preflight-body.$$ /tmp/hermes-api-preflight-curl.$$
}

listener_line_for_port() {
  local port="$1"
  [ -n "$port" ] || return
  if command_exists ss; then
    ss -ltnp 2>/dev/null | awk -v port=":${port}" '$4 ~ port {print}'
  elif command_exists netstat; then
    netstat -ltnp 2>/dev/null | awk -v port=":${port}" '$4 ~ port {print}'
  fi
}

container_env_value() {
  local container="$1"
  local key="$2"
  command_exists docker || return
  docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$container" 2>/dev/null \
    | sed -n "s/^${key}=//p" \
    | tail -1
}

gateway_status_for_profile() {
  local profile="$1"
  local output
  if ! command_exists docker || ! docker inspect hermes >/dev/null 2>&1; then
    printf 'docker-unavailable'
    return
  fi
  output="$(docker exec hermes hermes -p "$profile" gateway status 2>/dev/null || true)"
  if [ -z "$output" ]; then
    printf 'unknown'
  elif printf '%s\n' "$output" | grep -Eiq 'Gateway:[[:space:]]+running|Gateway is running|✓ Gateway is running'; then
    printf 'running'
  elif printf '%s\n' "$output" | grep -Eiq 'Gateway:[[:space:]]+stopped|Gateway is stopped|not running|stopped'; then
    printf 'stopped'
  elif printf '%s\n' "$output" | grep -Eiq 'no such gateway'; then
    printf 'not-registered'
  else
    printf 'unknown'
  fi
}

section "Hermes API Isolation Preflight"
value "date utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
value "cwd" "$(pwd)"
value "data root" "$DATA_ROOT"
value "profiles" "${PROFILES[*]}"
[ -n "$PUBLIC_HOST" ] && value "public host" "$PUBLIC_HOST"
if command_exists git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  value "git head" "$(git rev-parse --short HEAD 2>/dev/null || true)"
fi

section "Summary"
printf '%-9s %-7s %-8s %-9s %-16s %-10s %-11s %-11s %-9s %-10s\n' \
  "PROFILE" "ENV" "API_ON" "PORT" "KEY_FP" "LISTENER" "HEALTH" "MODELS" "GATEWAY" "DASH_API"

declare -A key_fps
declare -A key_profiles

for profile in "${PROFILES[@]}"; do
  profile_dir="$DATA_ROOT/profiles/$profile"
  env_file="$profile_dir/.env"
  expected_port="$(api_port "$profile")"
  enabled="$(env_value "$env_file" API_SERVER_ENABLED)"
  host="$(env_value "$env_file" API_SERVER_HOST)"
  port="$(env_value "$env_file" API_SERVER_PORT)"
  key="$(env_value "$env_file" API_SERVER_KEY)"
  model_name="$(env_value "$env_file" API_SERVER_MODEL_NAME)"
  [ -z "$port" ] && port="$expected_port"
  key_fp="$(fingerprint_secret "$key")"
  listener="$(listener_line_for_port "$port")"
  listener_state="$([ -n "$listener" ] && printf yes || printf no)"
  health="skipped"
  models="skipped"
  if [ -n "$port" ]; then
    health="$(http_code "http://127.0.0.1:${port}/health")"
    http_body_head >/dev/null
    models="$(http_code "http://127.0.0.1:${port}/v1/models")"
    http_body_head >/dev/null
  fi
  gateway="$(gateway_status_for_profile "$profile")"
  dash_api="$(container_env_value "hermes-dashboard-$profile" API_SERVER_ENABLED)"
  [ -z "$dash_api" ] && dash_api="missing"
  env_state="$([ -f "$env_file" ] && printf ok || printf missing)"

  printf '%-9s %-7s %-8s %-9s %-16s %-10s %-11s %-11s %-9s %-10s\n' \
    "$profile" "$env_state" "${enabled:-unset}" "${port:-unset}" \
    "$(printf '%s' "$key_fp" | awk '{print $1}')" "$listener_state" \
    "$health" "$models" "$gateway" "$dash_api"

  if [ -n "$key" ]; then
    fp="$(printf '%s' "$key_fp" | awk '{print $1}')"
    if [ -n "${key_fps[$fp]:-}" ]; then
      key_profiles[$fp]="${key_profiles[$fp]} $profile"
    else
      key_fps[$fp]=1
      key_profiles[$fp]="$profile"
    fi
  fi
done

section "Per-Profile Details"
for profile in "${PROFILES[@]}"; do
  profile_dir="$DATA_ROOT/profiles/$profile"
  config_file="$profile_dir/config.yaml"
  env_file="$profile_dir/.env"
  expected_port="$(api_port "$profile")"
  dash_port="$(dashboard_port "$profile")"
  enabled="$(env_value "$env_file" API_SERVER_ENABLED)"
  host="$(env_value "$env_file" API_SERVER_HOST)"
  port="$(env_value "$env_file" API_SERVER_PORT)"
  key="$(env_value "$env_file" API_SERVER_KEY)"
  cors="$(env_value "$env_file" API_SERVER_CORS_ORIGINS)"
  model_name="$(env_value "$env_file" API_SERVER_MODEL_NAME)"
  [ -z "$port" ] && port="$expected_port"

  printf '\n-- %s --\n' "$profile"
  [ -d "$profile_dir" ] && pass "$profile profile dir" "$profile_dir" || fail "$profile profile dir" "$profile_dir missing"
  [ -f "$env_file" ] && pass "$profile env file" "$env_file" || fail "$profile env file" "$env_file missing"
  [ -f "$config_file" ] && pass "$profile config file" "$config_file" || warn "$profile config file" "$config_file missing"

  if [ "${enabled:-}" = "true" ]; then
    pass "$profile API_SERVER_ENABLED" "true"
  else
    warn "$profile API_SERVER_ENABLED" "${enabled:-unset}"
  fi
  [ -n "$host" ] && info "$profile API_SERVER_HOST" "$host" || info "$profile API_SERVER_HOST" "unset"
  if [ -n "$expected_port" ] && [ "$port" = "$expected_port" ]; then
    pass "$profile API_SERVER_PORT" "$port"
  elif [ -n "$port" ]; then
    warn "$profile API_SERVER_PORT" "actual=$port expected=${expected_port:-unknown}"
  else
    fail "$profile API_SERVER_PORT" "missing"
  fi
  [ -n "$key" ] && pass "$profile API_SERVER_KEY" "$(fingerprint_secret "$key")" || fail "$profile API_SERVER_KEY" "missing"
  [ -n "$model_name" ] && info "$profile API_SERVER_MODEL_NAME" "$model_name" || info "$profile API_SERVER_MODEL_NAME" "unset; api_server may advertise active profile name"
  [ -n "$cors" ] && info "$profile API_SERVER_CORS" "$cors" || info "$profile API_SERVER_CORS" "unset"

  listener="$(listener_line_for_port "$port")"
  [ -n "$listener" ] && pass "$profile listener" "$listener" || warn "$profile listener" "none on port ${port:-unknown}"

  if [ -n "$port" ]; then
    health="$(http_code "http://127.0.0.1:${port}/health")"
    [ "$health" = "200" ] && pass "$profile local /health" "$health" || warn "$profile local /health" "$health"
    http_body_head
    models="$(http_code "http://127.0.0.1:${port}/v1/models")"
    [ "$models" = "200" ] && pass "$profile local /v1/models" "$models" || warn "$profile local /v1/models" "$models"
    http_body_head
    if [ -n "$PUBLIC_HOST" ]; then
      pub="$(http_code "http://${PUBLIC_HOST}:${port}/health")"
      [ "$pub" = "200" ] && pass "$profile public /health" "$pub" || warn "$profile public /health" "$pub"
      http_body_head
    fi
  fi

  gateway="$(gateway_status_for_profile "$profile")"
  [ "$gateway" = "running" ] && pass "$profile gateway status" "$gateway" || warn "$profile gateway status" "$gateway"

  dash_api="$(container_env_value "hermes-dashboard-$profile" API_SERVER_ENABLED)"
  if [ "$dash_api" = "false" ]; then
    pass "$profile dashboard embedded api_server" "disabled"
  else
    warn "$profile dashboard embedded api_server" "actual=${dash_api:-missing}; should be false for isolated dashboards"
  fi

  dash_single="$(container_env_value "hermes-dashboard-$profile" HERMES_DASHBOARD_SINGLE_PROFILE)"
  [ "$dash_single" = "$profile" ] && pass "$profile dashboard single profile" "$dash_single" || warn "$profile dashboard single profile" "actual=${dash_single:-missing}"
  [ -n "$dash_port" ] && info "$profile dashboard port" "$dash_port"
done

section "API Key Uniqueness"
if [ "${#key_profiles[@]}" -eq 0 ]; then
  warn "api keys" "none found"
else
  for fp in "${!key_profiles[@]}"; do
    profiles_for_key="${key_profiles[$fp]}"
    count="$(printf '%s\n' "$profiles_for_key" | wc -w | tr -d ' ')"
    if [ "$count" -eq 1 ]; then
      pass "unique key $fp" "$profiles_for_key"
    else
      fail "shared key $fp" "$profiles_for_key"
    fi
  done
fi

section "Interpretation"
cat <<EOF
Expected secure desktop/API layout:
- each profile has API_SERVER_ENABLED=true in its own profile .env
- each profile has a unique API_SERVER_KEY
- each profile listens on its own API port
- each profile gateway reports running
- each isolated dashboard container keeps API_SERVER_ENABLED=false

Dashboard API_SERVER_ENABLED=false is correct for isolated dashboards.
Desktop/API access should come from the per-profile gateway/API process,
not from the dashboard container.
EOF
