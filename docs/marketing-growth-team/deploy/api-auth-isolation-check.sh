#!/usr/bin/env bash
set -u

DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
HOST="${HOST:-127.0.0.1}"
RUN_CHAT=0
PROFILES=()

usage() {
  cat <<EOF
Usage:
  $0 [--host HOST] [--chat] [profile...]

Read-only authenticated API isolation check for Marketing & Growth profiles.

It reads each profile's API_SERVER_KEY from its own .env file, but never prints
keys. It verifies:
  - own key can access own /v1/models
  - another profile's key is rejected by this profile's /v1/models
  - optional: own key can make a minimal /v1/chat/completions call

Defaults:
  host:     127.0.0.1
  profiles: arnela denis arman testing

Examples:
  $0
  $0 --host 46.225.222.164
  $0 --chat denis
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --chat)
      RUN_CHAT=1
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

if [ "${#PROFILES[@]}" -eq 0 ]; then
  PROFILES=(arnela denis arman testing)
fi

section() { printf '\n== %s ==\n' "$1"; }
value() { printf '%-34s %s\n' "$1:" "$2"; }
pass() { printf 'PASS %-38s %s\n' "$1" "$2"; }
warn() { printf 'WARN %-38s %s\n' "$1" "$2"; }
fail() { printf 'FAIL %-38s %s\n' "$1" "$2"; }
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

http_code_auth() {
  local url="$1"
  local key="$2"
  local method="${3:-GET}"
  local body="${4:-}"
  local code
  if ! command_exists curl; then
    printf 'curl-missing'
    return
  fi
  if [ "$method" = "POST" ]; then
    code="$(curl -sS -o /tmp/hermes-api-auth-body.$$ -w '%{http_code}' --max-time 45 \
      -H "Authorization: Bearer ${key}" \
      -H "Content-Type: application/json" \
      -d "$body" \
      "$url" 2>/tmp/hermes-api-auth-curl.$$ || true)"
  else
    code="$(curl -sS -o /tmp/hermes-api-auth-body.$$ -w '%{http_code}' --max-time 10 \
      -H "Authorization: Bearer ${key}" \
      "$url" 2>/tmp/hermes-api-auth-curl.$$ || true)"
  fi
  if [ "$code" = "000" ] || [ -z "$code" ]; then
    printf 'fail'
  else
    printf '%s' "$code"
  fi
}

body_head() {
  if [ -s /tmp/hermes-api-auth-body.$$ ]; then
    sed -n '1,2p' /tmp/hermes-api-auth-body.$$
  fi
  rm -f /tmp/hermes-api-auth-body.$$ /tmp/hermes-api-auth-curl.$$
}

declare -A keys
declare -A ports
declare -A fps

section "Hermes API Auth Isolation Check"
value "date utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
value "host" "$HOST"
value "data root" "$DATA_ROOT"
value "profiles" "${PROFILES[*]}"
value "chat test" "$([ "$RUN_CHAT" -eq 1 ] && printf enabled || printf disabled)"

section "Loaded Keys"
for profile in "${PROFILES[@]}"; do
  env_file="$DATA_ROOT/profiles/$profile/.env"
  key="$(env_value "$env_file" API_SERVER_KEY)"
  port="$(env_value "$env_file" API_SERVER_PORT)"
  [ -z "$port" ] && port="$(api_port "$profile")"
  keys[$profile]="$key"
  ports[$profile]="$port"
  fps[$profile]="$(fingerprint_secret "$key")"
  if [ -n "$key" ]; then
    pass "$profile key loaded" "${fps[$profile]}"
  else
    fail "$profile key loaded" "missing in $env_file"
  fi
done

section "Own-Key Access"
for profile in "${PROFILES[@]}"; do
  key="${keys[$profile]}"
  port="${ports[$profile]}"
  if [ -z "$key" ] || [ -z "$port" ]; then
    fail "$profile own /v1/models" "missing key or port"
    continue
  fi
  code="$(http_code_auth "http://${HOST}:${port}/v1/models" "$key")"
  if [ "$code" = "200" ]; then
    pass "$profile own /v1/models" "200"
  else
    fail "$profile own /v1/models" "$code"
    body_head
  fi
done

section "Cross-Key Rejection"
for profile in "${PROFILES[@]}"; do
  port="${ports[$profile]}"
  own_key="${keys[$profile]}"
  if [ -z "$port" ] || [ -z "$own_key" ]; then
    fail "$profile cross-key rejection" "missing own key or port"
    continue
  fi
  checked=0
  rejected=0
  for other in "${PROFILES[@]}"; do
    [ "$other" = "$profile" ] && continue
    other_key="${keys[$other]}"
    [ -z "$other_key" ] && continue
    checked=$((checked + 1))
    code="$(http_code_auth "http://${HOST}:${port}/v1/models" "$other_key")"
    if [ "$code" = "401" ] || [ "$code" = "403" ]; then
      rejected=$((rejected + 1))
    else
      fail "$profile rejects $other key" "expected 401/403 got $code"
      body_head
    fi
  done
  if [ "$checked" -gt 0 ] && [ "$checked" -eq "$rejected" ]; then
    pass "$profile cross-key rejection" "$rejected/$checked rejected"
  elif [ "$checked" -eq 0 ]; then
    warn "$profile cross-key rejection" "no other keys available"
  fi
done

if [ "$RUN_CHAT" -eq 1 ]; then
  section "Minimal Chat Completion"
  for profile in "${PROFILES[@]}"; do
    key="${keys[$profile]}"
    port="${ports[$profile]}"
    if [ -z "$key" ] || [ -z "$port" ]; then
      fail "$profile chat" "missing key or port"
      continue
    fi
    body="$(printf '{"model":"%s","messages":[{"role":"user","content":"Reply with exactly: %s-api-ok"}],"max_tokens":20}' "$profile" "$profile")"
    code="$(http_code_auth "http://${HOST}:${port}/v1/chat/completions" "$key" POST "$body")"
    if [ "$code" = "200" ]; then
      pass "$profile chat" "200"
    else
      fail "$profile chat" "$code"
      body_head
    fi
  done
else
  section "Minimal Chat Completion"
  warn "chat test" "skipped; rerun with --chat for real model calls"
fi

section "Interpretation"
cat <<EOF
Complete API isolation requires:
- every own-key /v1/models check returns 200
- every cross-key check returns 401 or 403
- optional --chat checks return 200 for each profile

This script never prints API keys. It only prints fingerprints.
EOF

