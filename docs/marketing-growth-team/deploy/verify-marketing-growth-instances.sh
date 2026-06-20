#!/usr/bin/env bash
set -u

DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
DOMAIN="${DOMAIN:-activi-apps.io}"
PROFILES=()

usage() {
  cat <<EOF
Usage:
  $0 [--domain DOMAIN] [profile...]

Read-only verification against the live deployed stack, not the blueprint docs.
It checks real profile directories, real profile workspaces, real dashboard
containers, and real local dashboard API responses.

Defaults:
  profiles: arnela denis arman testing

Examples:
  $0
  $0 --domain activi-apps.io
  $0 denis
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --domain)
      DOMAIN="${2:-}"
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

required_agent_files=(ROLE.md SYSTEM.md SKILLS.md TOOLS.md MEMORY.md WORKFLOWS.md SUBAGENTS.md)
required_agents=(
  orchestrator
  content-writer
  social-media-specialist
  seo-web
  creative-design
  campaign-analyst
  deep-research
  memory-review-reflector
)
required_memory_files=(
  memory/shared/BRAND.md
  memory/shared/AUDIENCES.md
  memory/shared/OFFERS.md
  memory/shared/COMPLIANCE.md
  memory/shared/CAMPAIGNS.md
  memory/shared/SOURCES.md
  memory/orchestrator/DECISIONS.md
  memory/orchestrator/TEAM_LEARNINGS.md
  memory/orchestrator/SKILL_BACKLOG.md
  memory/orchestrator/REVIEW_QUEUE.md
  memory/agents/content-writer.md
  memory/agents/social-media-specialist.md
  memory/agents/seo-web.md
  memory/agents/creative-design.md
  memory/agents/campaign-analyst.md
  memory/agents/deep-research.md
  memory/agents/memory-review-reflector.md
  memory/protocols/MEMORY_POLICY.md
  memory/protocols/SELF_LEARNING_LOOP.md
  memory/protocols/MEMORY_REVIEW_CHECKLIST.md
  memory/protocols/SKILL_BUILDER_WORKFLOW.md
)

section() { printf '\n== %s ==\n' "$1"; }
value() { printf '%-38s %s\n' "$1:" "$2"; }
pass() { printf 'PASS %-36s %s\n' "$1" "$2"; }
warn() { printf 'WARN %-36s %s\n' "$1" "$2"; }
fail() { printf 'FAIL %-36s %s\n' "$1" "$2"; }
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

dashboard_token() {
  local port="$1"
  command_exists curl || return
  curl -sS --max-time 6 "http://127.0.0.1:${port}/" 2>/dev/null \
    | sed -n 's/.*window.__HERMES_SESSION_TOKEN__="\([^"]*\)".*/\1/p' \
    | head -1
}

dashboard_json() {
  local port="$1"
  local path="$2"
  local token
  token="$(dashboard_token "$port")"
  [ -n "$token" ] || return 1
  curl -sS --max-time 6 -H "X-Hermes-Session-Token: $token" \
    "http://127.0.0.1:${port}${path}" 2>/dev/null
}

json_profile_names() {
  python3 -c 'import json,sys
try:
    data=json.load(sys.stdin)
    print(",".join(p.get("name","?") for p in data.get("profiles", [])) or "none")
except Exception:
    print("parse-failed")
' 2>/dev/null
}

json_field() {
  local field="$1"
  python3 -c 'import json,sys
field=sys.argv[1]
try:
    data=json.load(sys.stdin)
    value=data
    for part in field.split("."):
        value=value[part]
    if isinstance(value, bool):
        print("true" if value else "false")
    else:
        print(value)
except Exception:
    print("")
' "$field" 2>/dev/null
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

count_complete_agents() {
  local workspace="$1"
  local count=0
  local agent file ok
  for agent in "${required_agents[@]}"; do
    ok=true
    for file in "${required_agent_files[@]}"; do
      [ -f "$workspace/agents/$agent/$file" ] || ok=false
    done
    [ "$ok" = true ] && count=$((count + 1))
  done
  printf '%s' "$count"
}

count_memory_files() {
  local workspace="$1"
  local count=0
  local file
  for file in "${required_memory_files[@]}"; do
    [ -f "$workspace/$file" ] && count=$((count + 1))
  done
  printf '%s' "$count"
}

count_skills() {
  local profile_dir="$1"
  if [ -d "$profile_dir/skills" ]; then
    find "$profile_dir/skills" -name SKILL.md -type f 2>/dev/null | wc -l | tr -d ' '
  else
    printf '0'
  fi
}

section "Marketing Growth Live Instance Verification"
value "date utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
value "data root" "$DATA_ROOT"
value "domain" "$DOMAIN"
value "profiles" "${PROFILES[*]}"

section "Summary"
printf '%-8s %-7s %-8s %-9s %-8s %-9s %-11s %-10s %-10s\n' \
  "PROFILE" "PROF" "WORKSP" "AGENTS" "MEMORY" "SKILLS" "SOUL" "DASH" "VISIBLE"
for profile in "${PROFILES[@]}"; do
  profile_dir="$DATA_ROOT/profiles/$profile"
  workspace="$DATA_ROOT/profile-workspaces/$profile"
  port="$(dashboard_port "$profile")"
  dash_code="$(http_code "http://127.0.0.1:${port}/")"
  visible="$(dashboard_json "$port" "/api/profiles" | json_profile_names)"
  [ -n "$visible" ] || visible="unknown"
  prof_state="$([ -d "$profile_dir" ] && printf ok || printf missing)"
  work_state="$([ -d "$workspace" ] && printf ok || printf missing)"
  agents_count="$(count_complete_agents "$workspace")/${#required_agents[@]}"
  memory_count="$(count_memory_files "$workspace")/${#required_memory_files[@]}"
  skills_count="$(count_skills "$profile_dir")"
  soul_state="missing"
  if [ -f "$profile_dir/SOUL.md" ] && grep -q 'marketing-growth-orchestrator-persona:managed' "$profile_dir/SOUL.md"; then
    soul_state="bound"
  elif [ -f "$profile_dir/SOUL.md" ]; then
    soul_state="generic"
  fi
  printf '%-8s %-7s %-8s %-9s %-8s %-9s %-11s %-10s %-10s\n' \
    "$profile" "$prof_state" "$work_state" "$agents_count" "$memory_count" \
    "$skills_count" "$soul_state" "local:$dash_code" "$visible"
done

section "Per-Profile Assertions"
for profile in "${PROFILES[@]}"; do
  profile_dir="$DATA_ROOT/profiles/$profile"
  workspace="$DATA_ROOT/profile-workspaces/$profile"
  container="hermes-dashboard-$profile"
  dash_port="$(dashboard_port "$profile")"
  api_port="$(api_port "$profile")"
  expected_url="https://${profile}.${DOMAIN}"
  printf '\n-- %s --\n' "$profile"

  [ -d "$profile_dir" ] && pass "$profile profile dir" "$profile_dir" || fail "$profile profile dir" "$profile_dir missing"
  [ -d "$workspace" ] && pass "$profile workspace dir" "$workspace" || fail "$profile workspace dir" "$workspace missing"

  agents_count="$(count_complete_agents "$workspace")"
  if [ "$agents_count" -eq "${#required_agents[@]}" ]; then
    pass "$profile agents complete" "$agents_count/${#required_agents[@]}"
  else
    fail "$profile agents complete" "$agents_count/${#required_agents[@]}"
  fi

  for agent in "${required_agents[@]}"; do
    if [ -d "$workspace/agents/$agent" ]; then
      missing=()
      for file in "${required_agent_files[@]}"; do
        [ -f "$workspace/agents/$agent/$file" ] || missing+=("$file")
      done
      if [ "${#missing[@]}" -eq 0 ]; then
        pass "$profile agent $agent" "all files"
      else
        fail "$profile agent $agent" "missing: ${missing[*]}"
      fi
    else
      fail "$profile agent $agent" "directory missing"
    fi
  done

  memory_count="$(count_memory_files "$workspace")"
  if [ "$memory_count" -eq "${#required_memory_files[@]}" ]; then
    pass "$profile memory complete" "$memory_count/${#required_memory_files[@]}"
  else
    fail "$profile memory complete" "$memory_count/${#required_memory_files[@]}"
  fi

  skills_count="$(count_skills "$profile_dir")"
  if [ "$skills_count" -gt 0 ]; then
    pass "$profile skills present" "$skills_count SKILL.md"
  else
    fail "$profile skills present" "none"
  fi

  if [ -f "$profile_dir/SOUL.md" ] && grep -q 'marketing-growth-orchestrator-persona:managed' "$profile_dir/SOUL.md"; then
    pass "$profile SOUL binding" "orchestrator persona"
  else
    fail "$profile SOUL binding" "run bind-orchestrator-persona.sh $profile"
  fi

  dash_code="$(http_code "http://127.0.0.1:${dash_port}/")"
  [ "$dash_code" = "200" ] && pass "$profile dashboard local" "port $dash_port" || fail "$profile dashboard local" "port $dash_port http=$dash_code"

  api_code="$(http_code "http://127.0.0.1:${api_port}/health")"
  [ "$api_code" = "200" ] && pass "$profile api local" "port $api_port" || warn "$profile api local" "port $api_port http=$api_code"

  profiles_json="$(dashboard_json "$dash_port" "/api/profiles")"
  visible="$(printf '%s' "$profiles_json" | json_profile_names)"
  if [ "$visible" = "$profile" ]; then
    pass "$profile dashboard visible" "$visible"
  else
    fail "$profile dashboard visible" "expected only $profile, got ${visible:-unknown}"
  fi

  active_json="$(dashboard_json "$dash_port" "/api/profiles/active")"
  active="$(printf '%s' "$active_json" | json_field active)"
  current="$(printf '%s' "$active_json" | json_field current)"
  if [ "$active" = "$profile" ] && [ "$current" = "$profile" ]; then
    pass "$profile active/current" "active=$active current=$current"
  else
    fail "$profile active/current" "active=${active:-?} current=${current:-?}"
  fi

  single="$(container_env_value "$container" HERMES_DASHBOARD_SINGLE_PROFILE)"
  public_url="$(container_env_value "$container" HERMES_DASHBOARD_PUBLIC_URL)"
  dash_api_enabled="$(container_env_value "$container" API_SERVER_ENABLED)"
  [ "$single" = "$profile" ] && pass "$profile container single" "$single" || fail "$profile container single" "actual=${single:-missing}"
  [ "$public_url" = "$expected_url" ] && pass "$profile container public URL" "$public_url" || fail "$profile container public URL" "actual=${public_url:-missing}"
  [ "$dash_api_enabled" = "false" ] && pass "$profile dashboard API disabled" "API_SERVER_ENABLED=false" || warn "$profile dashboard API disabled" "actual=${dash_api_enabled:-missing}"

  if container_mounts "$container" | grep -q "^${DATA_ROOT} -> /opt/data$"; then
    fail "$profile broad mount" "${DATA_ROOT} -> /opt/data"
  else
    pass "$profile no broad mount" "ok"
  fi
  has_mount_destination "$container" "/opt/data/profiles/${profile}" \
    && pass "$profile profile mount" "/opt/data/profiles/${profile}" \
    || fail "$profile profile mount" "missing"
  has_mount_destination "$container" "/opt/data/profile-workspaces/${profile}" \
    && pass "$profile workspace mount" "/opt/data/profile-workspaces/${profile}" \
    || fail "$profile workspace mount" "missing"
done

section "Recommended Fix Commands"
cat <<EOF
# Bind all profiles to their orchestrator persona:
bash docs/marketing-growth-team/deploy/bind-orchestrator-persona.sh

# Recreate hardened dashboard containers after image/env changes:
bash docs/marketing-growth-team/deploy/harden-dashboard-containers.sh --apply --domain ${DOMAIN}

# Full stack health:
bash docs/marketing-growth-team/deploy/marketing-growth-all-checkup.sh --domain ${DOMAIN}
EOF
