#!/usr/bin/env bash
set -u

HOST=""
PROFILE=""
API_KEY=""
RUN_CHAT=0

usage() {
  cat <<EOF
Usage:
  $0 --host HOST --profile PROFILE --api-key KEY [--chat]

Client-side read-only check for one user's Hermes Desktop/API access.
Run this from the user's local machine, not necessarily on the server.

It verifies:
  - public /health is reachable
  - the user's key can access /v1/models
  - a wrong key is rejected
  - optional: a minimal /v1/chat/completions call works

Examples:
  $0 --host 46.225.222.164 --profile denis --api-key '...'
  $0 --host 46.225.222.164 --profile denis --api-key '...' --chat
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --api-key)
      API_KEY="${2:-}"
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
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$HOST" ] || [ -z "$PROFILE" ] || [ -z "$API_KEY" ]; then
  usage >&2
  exit 2
fi

api_port() {
  case "$1" in
    arnela) printf '8643' ;;
    denis) printf '8644' ;;
    arman) printf '8645' ;;
    testing) printf '8646' ;;
    *)
      echo "Unknown profile: $1" >&2
      return 1
      ;;
  esac
}

command_exists() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n== %s ==\n' "$1"; }
value() { printf '%-28s %s\n' "$1:" "$2"; }
pass() { printf 'PASS %-34s %s\n' "$1" "$2"; }
warn() { printf 'WARN %-34s %s\n' "$1" "$2"; }
fail() { printf 'FAIL %-34s %s\n' "$1" "$2"; }

fingerprint_secret() {
  local value="$1"
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
  local key="${2:-}"
  local method="${3:-GET}"
  local body="${4:-}"
  local code
  if ! command_exists curl; then
    printf 'curl-missing'
    return
  fi
  if [ "$method" = "POST" ]; then
    code="$(curl -sS -o /tmp/hermes-desktop-api-body.$$ -w '%{http_code}' --max-time 45 \
      -H "Authorization: Bearer ${key}" \
      -H "Content-Type: application/json" \
      -d "$body" \
      "$url" 2>/tmp/hermes-desktop-api-curl.$$ || true)"
  elif [ -n "$key" ]; then
    code="$(curl -sS -o /tmp/hermes-desktop-api-body.$$ -w '%{http_code}' --max-time 10 \
      -H "Authorization: Bearer ${key}" \
      "$url" 2>/tmp/hermes-desktop-api-curl.$$ || true)"
  else
    code="$(curl -sS -o /tmp/hermes-desktop-api-body.$$ -w '%{http_code}' --max-time 10 \
      "$url" 2>/tmp/hermes-desktop-api-curl.$$ || true)"
  fi
  if [ "$code" = "000" ] || [ -z "$code" ]; then
    printf 'fail'
  else
    printf '%s' "$code"
  fi
}

body_head() {
  if [ -s /tmp/hermes-desktop-api-body.$$ ]; then
    sed -n '1,2p' /tmp/hermes-desktop-api-body.$$
  fi
  rm -f /tmp/hermes-desktop-api-body.$$ /tmp/hermes-desktop-api-curl.$$
}

PORT="$(api_port "$PROFILE")" || exit 2
BASE_URL="http://${HOST}:${PORT}"

section "Hermes Desktop/API Client Check"
value "host" "$HOST"
value "profile" "$PROFILE"
value "port" "$PORT"
value "base url" "${BASE_URL}/v1"
value "api key fingerprint" "$(fingerprint_secret "$API_KEY")"
value "chat test" "$([ "$RUN_CHAT" -eq 1 ] && printf enabled || printf disabled)"

section "Reachability"
code="$(http_code "${BASE_URL}/health")"
if [ "$code" = "200" ]; then
  pass "public /health" "200"
else
  fail "public /health" "$code"
fi
body_head

section "Auth"
code="$(http_code "${BASE_URL}/v1/models" "$API_KEY")"
if [ "$code" = "200" ]; then
  pass "own key /v1/models" "200"
else
  fail "own key /v1/models" "$code"
  body_head
fi

wrong_key="wrong-${PROFILE}-$(date +%s)-not-a-real-key"
code="$(http_code "${BASE_URL}/v1/models" "$wrong_key")"
if [ "$code" = "401" ] || [ "$code" = "403" ]; then
  pass "wrong key rejected" "$code"
else
  fail "wrong key rejected" "expected 401/403 got $code"
  body_head
fi

if [ "$RUN_CHAT" -eq 1 ]; then
  section "Chat"
  body="$(printf '{"model":"%s","messages":[{"role":"user","content":"Reply with exactly: %s-desktop-api-ok"}],"max_tokens":20}' "$PROFILE" "$PROFILE")"
  code="$(http_code "${BASE_URL}/v1/chat/completions" "$API_KEY" POST "$body")"
  if [ "$code" = "200" ]; then
    pass "chat completion" "200"
  else
    fail "chat completion" "$code"
    body_head
  fi
else
  section "Chat"
  warn "chat completion" "skipped; rerun with --chat for real model call"
fi

section "Desktop Settings"
cat <<EOF
Use these values in Hermes Desktop / OpenAI-compatible clients:
Base URL: ${BASE_URL}/v1
API Key:  the key you passed to this script
Model:    ${PROFILE}
EOF

