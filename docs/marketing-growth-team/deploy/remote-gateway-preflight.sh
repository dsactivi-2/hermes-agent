#!/usr/bin/env bash
set -u

PROFILE="arman"
PUBLIC_HOST=""
DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"

usage() {
  cat <<EOF
Usage:
  $0 [--profile PROFILE] [--public-host HOST_OR_IP]

Checks whether a Hermes profile gateway is ready for remote desktop/API access.
It prints useful diagnostics without exposing API keys.

Examples:
  $0
  $0 --profile arman --public-host 46.225.222.164
  $0 --profile denis --public-host your-domain.example
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --public-host)
      PUBLIC_HOST="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

section() {
  printf '\n== %s ==\n' "$1"
}

value() {
  printf '%-34s %s\n' "$1:" "$2"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

mask_secret() {
  local value="$1"
  local length
  length="${#value}"
  if [ -z "$value" ]; then
    printf 'not set'
    return
  fi
  if [ "$length" -le 10 ]; then
    printf 'set (length=%s)' "$length"
    return
  fi
  printf '%s...%s (length=%s)' "${value:0:6}" "${value: -4}" "$length"
}

read_env_value() {
  local file="$1"
  local key="$2"
  if [ -f "$file" ]; then
    grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1 | cut -d= -f2-
  fi
}

http_status() {
  local url="$1"
  if command_exists curl; then
    curl -sS -o /tmp/hermes-preflight-body.$$ -w '%{http_code}' --max-time 5 "$url" 2>/tmp/hermes-preflight-curl.$$
  else
    printf 'curl-missing'
  fi
}

print_curl_body() {
  if [ -s /tmp/hermes-preflight-body.$$ ]; then
    sed -n '1,4p' /tmp/hermes-preflight-body.$$
  fi
  rm -f /tmp/hermes-preflight-body.$$ /tmp/hermes-preflight-curl.$$
}

PROFILE_ENV=""
PROFILE_CONFIG=""
for root in "$DATA_ROOT" /opt/data; do
  if [ -f "$root/profiles/$PROFILE/.env" ]; then
    PROFILE_ENV="$root/profiles/$PROFILE/.env"
  fi
  if [ -f "$root/profiles/$PROFILE/config.yaml" ]; then
    PROFILE_CONFIG="$root/profiles/$PROFILE/config.yaml"
  fi
done

API_ENABLED=""
API_HOST=""
API_PORT=""
API_KEY=""
API_CORS=""
if [ -n "$PROFILE_ENV" ]; then
  API_ENABLED="$(read_env_value "$PROFILE_ENV" API_SERVER_ENABLED)"
  API_HOST="$(read_env_value "$PROFILE_ENV" API_SERVER_HOST)"
  API_PORT="$(read_env_value "$PROFILE_ENV" API_SERVER_PORT)"
  API_KEY="$(read_env_value "$PROFILE_ENV" API_SERVER_KEY)"
  API_CORS="$(read_env_value "$PROFILE_ENV" API_SERVER_CORS_ORIGINS)"
fi

if [ -z "$API_PORT" ]; then
  case "$PROFILE" in
    arnela) API_PORT=8643 ;;
    denis) API_PORT=8644 ;;
    arman) API_PORT=8645 ;;
    testing) API_PORT=8646 ;;
  esac
fi

section "Host"
value "hostname" "$(hostname 2>/dev/null || printf unknown)"
value "user" "$(id -un 2>/dev/null || printf unknown)"
value "cwd" "$(pwd)"
value "date utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
if command_exists hostname; then
  value "detected host ips" "$(hostname -I 2>/dev/null | xargs || printf unknown)"
fi
if [ -n "$PUBLIC_HOST" ]; then
  value "public host argument" "$PUBLIC_HOST"
fi

section "Profile Files"
value "profile" "$PROFILE"
value "data root" "$DATA_ROOT"
value "profile .env" "${PROFILE_ENV:-not found}"
value "profile config.yaml" "${PROFILE_CONFIG:-not found}"

section "API Server Env"
value "API_SERVER_ENABLED" "${API_ENABLED:-not set}"
value "API_SERVER_HOST" "${API_HOST:-not set}"
value "API_SERVER_PORT" "${API_PORT:-not set}"
value "API_SERVER_KEY" "$(mask_secret "$API_KEY")"
value "API_SERVER_CORS_ORIGINS" "${API_CORS:-not set}"

section "Docker / Hermes"
if command_exists docker; then
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
  if docker inspect hermes >/dev/null 2>&1; then
    printf '\n'
    docker exec hermes hermes profile show "$PROFILE" 2>/dev/null || true
    printf '\n'
    docker exec hermes hermes -p "$PROFILE" gateway status 2>/dev/null || true
  else
    value "container hermes" "not found"
  fi
else
  value "docker" "not installed or not on PATH"
fi

section "Listeners"
if [ -n "$API_PORT" ]; then
  if command_exists ss; then
    ss -ltnp 2>/dev/null | awk -v port=":${API_PORT}" '$4 ~ port {print}' || true
  elif command_exists netstat; then
    netstat -ltnp 2>/dev/null | awk -v port=":${API_PORT}" '$4 ~ port {print}' || true
  else
    value "listener check" "ss/netstat not available"
  fi
else
  value "listener check" "API port unknown"
fi

section "Local HTTP Checks"
if [ -n "$API_PORT" ]; then
  local_health="http://127.0.0.1:${API_PORT}/health"
  status="$(http_status "$local_health")"
  value "$local_health" "$status"
  print_curl_body

  local_models="http://127.0.0.1:${API_PORT}/v1/models"
  status="$(http_status "$local_models")"
  value "$local_models" "$status"
  print_curl_body
else
  value "local checks" "API port unknown"
fi

section "Public HTTP Check From Server"
if [ -n "$PUBLIC_HOST" ] && [ -n "$API_PORT" ]; then
  public_health="http://${PUBLIC_HOST}:${API_PORT}/health"
  status="$(http_status "$public_health")"
  value "$public_health" "$status"
  print_curl_body
else
  value "public check" "skipped; pass --public-host 46.225.222.164"
fi

section "Firewall"
if command_exists ufw; then
  ufw status 2>/dev/null || true
else
  value "ufw" "not installed or not on PATH"
fi

if command_exists iptables; then
  value "iptables input policy" "$(iptables -S INPUT 2>/dev/null | sed -n '1p' || printf unavailable)"
fi

section "Provider / Network Reminder"
cat <<EOF
If local health is OK but public health fails:
- open TCP port ${API_PORT:-<port>} in ufw if ufw is active
- open TCP port ${API_PORT:-<port>} in your server provider firewall/security group
- verify the server public IP/domain points to this machine
- verify Hermes Desktop uses: http://${PUBLIC_HOST:-<SERVER_IP>}:${API_PORT:-<port>}
- verify Hermes Desktop API key matches the API_SERVER_KEY shown above by fingerprint, not by posting the key
EOF

section "Ready-To-Copy Mac Test"
if [ -n "$PUBLIC_HOST" ] && [ -n "$API_PORT" ]; then
  printf 'curl -v http://%s:%s/health\n' "$PUBLIC_HOST" "$API_PORT"
  printf 'curl -v http://%s:%s/v1/models\n' "$PUBLIC_HOST" "$API_PORT"
else
  printf 'bash docs/marketing-growth-team/deploy/remote-gateway-preflight.sh --profile %s --public-host <SERVER_IP>\n' "$PROFILE"
fi

