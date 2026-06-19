#!/usr/bin/env bash
set -u

DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
TEMPLATE_ROOT="${TEMPLATE_ROOT:-docs/marketing-growth-team}"
PUBLIC_HOST=""
RUN_AUDIT=false

usage() {
  cat <<EOF
Usage:
  $0 [--public-host HOST_OR_IP] [--template-root PATH] [--audit]

Read-only status report for the Marketing & Growth Hermes stack.
It does not change files, containers, profiles, gateways, firewall, or configs.

Examples:
  $0
  $0 --public-host 46.225.222.164
  $0 --template-root docs/marketing-growth-team --audit
  $0 --public-host 46.225.222.164 --audit
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --public-host)
      PUBLIC_HOST="${2:-}"
      shift 2
      ;;
    --template-root)
      TEMPLATE_ROOT="${2:-}"
      shift 2
      ;;
    --audit)
      RUN_AUDIT=true
      shift
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
  printf '%-36s %s\n' "$1:" "$2"
}

ok() {
  printf 'OK   %-34s %s\n' "$1" "$2"
}

warn() {
  printf 'WARN %-34s %s\n' "$1" "$2"
}

miss() {
  printf 'MISS %-34s %s\n' "$1" "$2"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

read_env_value() {
  local file="$1"
  local key="$2"
  if [ -f "$file" ]; then
    grep -E "^${key}=" "$file" 2>/dev/null | tail -n 1 | cut -d= -f2-
  fi
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

mask_secret() {
  local value="$1"
  if [ -z "$value" ]; then
    printf 'not set'
    return
  fi
  if [ "${#value}" -le 10 ]; then
    printf 'set length=%s' "${#value}"
    return
  fi
  printf '%s...%s length=%s' "${value:0:6}" "${value: -4}" "${#value}"
}

profile_dashboard_port() {
  case "$1" in
    arnela) printf '9120' ;;
    denis) printf '9121' ;;
    arman) printf '9122' ;;
    testing) printf '9123' ;;
    *) printf '' ;;
  esac
}

profile_api_port_default() {
  case "$1" in
    arnela) printf '8643' ;;
    denis) printf '8644' ;;
    arman) printf '8645' ;;
    testing) printf '8646' ;;
    *) printf '' ;;
  esac
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

contains_listener_any() {
  local port="$1"
  listener_line_for_port "$port" | grep -q .
}

contains_listener_public() {
  local port="$1"
  listener_line_for_port "$port" | grep -Eq "0\.0\.0\.0:${port}|\\[::\\]:${port}|:::${port}"
}

count_files() {
  local dir="$1"
  if [ -d "$dir" ]; then
    find "$dir" -type f | wc -l | tr -d ' '
  else
    printf '0'
  fi
}

complete_agent_count() {
  local root="$1"
  local agent file all_files count=0
  for agent in "${required_agents[@]}"; do
    all_files=true
    for file in "${required_agent_files[@]}"; do
      [ -f "$root/agents/$agent/$file" ] || all_files=false
    done
    [ "$all_files" = true ] && count=$((count + 1))
  done
  printf '%s' "$count"
}

memory_file_count() {
  local root="$1"
  local file count=0
  for file in "${required_memory_files[@]}"; do
    [ -f "$root/$file" ] && count=$((count + 1))
  done
  printf '%s' "$count"
}

config_state_for_root() {
  local root="$1"
  if [ -f "$root/config/config.yaml" ]; then
    printf 'ok'
  else
    printf 'missing'
  fi
}

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

profiles=(arnela denis arman testing)

section "Stack Status Read-Only"
value "date utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
value "cwd" "$(pwd)"
value "data root" "$DATA_ROOT"
value "template root" "$TEMPLATE_ROOT"
if [ -n "$PUBLIC_HOST" ]; then
  value "public host" "$PUBLIC_HOST"
fi
if command_exists git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  value "git branch" "$(git branch --show-current 2>/dev/null || printf unknown)"
  value "git head" "$(git log -1 --oneline 2>/dev/null || printf unknown)"
  value "git dirty docs" "$(git status --short docs/marketing-growth-team 2>/dev/null | wc -l | tr -d ' ') changed/untracked"
fi

section "Blueprint Template Summary"
printf '%-20s %-8s %-8s %-12s %-10s\n' "TEMPLATE" "ROOT" "AGENTS" "MEMORY" "CONFIG"
if [ -d "$TEMPLATE_ROOT" ]; then
  template_agents="$(complete_agent_count "$TEMPLATE_ROOT")/${#required_agents[@]}"
  template_memory="$(memory_file_count "$TEMPLATE_ROOT")/${#required_memory_files[@]}"
  template_config="$(config_state_for_root "$TEMPLATE_ROOT")"
  printf '%-20s %-8s %-8s %-12s %-10s\n' \
    "marketing-growth" "ok" "$template_agents" "$template_memory" "$template_config"
else
  printf '%-20s %-8s %-8s %-12s %-10s\n' \
    "marketing-growth" "missing" "0/${#required_agents[@]}" "0/${#required_memory_files[@]}" "missing"
fi

section "Docker Containers"
if command_exists docker; then
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
else
  warn "docker" "not available"
fi

section "Per-Profile Summary"
printf '%-10s %-8s %-8s %-8s %-12s %-12s %-10s %-10s %-16s\n' \
  "PROFILE" "PROFILE" "WORKSP" "AGENTS" "MEMORY" "DASHBOARD" "API" "GATEWAY" "MODEL"

for profile in "${profiles[@]}"; do
  profile_dir="$DATA_ROOT/profiles/$profile"
  workspace="$DATA_ROOT/profile-workspaces/$profile"
  env_file="$profile_dir/.env"
  config_file="$profile_dir/config.yaml"
  dashboard_port="$(profile_dashboard_port "$profile")"
  api_port="$(read_env_value "$env_file" API_SERVER_PORT)"
  [ -z "$api_port" ] && api_port="$(profile_api_port_default "$profile")"

  profile_state="missing"
  [ -d "$profile_dir" ] && profile_state="ok"

  workspace_state="missing"
  [ -d "$workspace" ] && workspace_state="ok"

  agent_ok="$(complete_agent_count "$workspace")"
  agent_state="${agent_ok}/${#required_agents[@]}"

  memory_ok="$(memory_file_count "$workspace")"
  memory_state="${memory_ok}/${#required_memory_files[@]}"

  dash_code="$(http_code "http://127.0.0.1:${dashboard_port}/")"
  dash_state="local:${dash_code}"

  api_code="$(http_code "http://127.0.0.1:${api_port}/health")"
  api_state="local:${api_code}"

  gateway_state="unknown"
  if command_exists docker && docker inspect hermes >/dev/null 2>&1; then
    if docker exec hermes hermes -p "$profile" gateway status 2>/dev/null | grep -q "Gateway is running"; then
      gateway_state="running"
    else
      gateway_state="stopped"
    fi
  fi

  model_state="unknown"
  if command_exists docker && docker inspect hermes >/dev/null 2>&1; then
    model_state="$(docker exec hermes hermes profile show "$profile" 2>/dev/null | awk -F: '/Model:/ {gsub(/^ +/, "", $2); print $2; exit}')"
    [ -z "$model_state" ] && model_state="unknown"
  elif [ -f "$config_file" ]; then
    model_state="$(grep -E '^  model:' "$config_file" 2>/dev/null | head -1 | sed 's/^ *model: *//' || true)"
    [ -z "$model_state" ] && model_state="config"
  fi

  printf '%-10s %-8s %-8s %-8s %-12s %-12s %-10s %-10s %-16s\n' \
    "$profile" "$profile_state" "$workspace_state" "$agent_state" "$memory_state" "$dash_state" "$api_state" "$gateway_state" "$model_state"
done

section "Profile Details"
for profile in "${profiles[@]}"; do
  profile_dir="$DATA_ROOT/profiles/$profile"
  workspace="$DATA_ROOT/profile-workspaces/$profile"
  env_file="$profile_dir/.env"
  config_file="$profile_dir/config.yaml"
  dashboard_port="$(profile_dashboard_port "$profile")"
  api_port="$(read_env_value "$env_file" API_SERVER_PORT)"
  [ -z "$api_port" ] && api_port="$(profile_api_port_default "$profile")"
  api_key="$(read_env_value "$env_file" API_SERVER_KEY)"
  api_host="$(read_env_value "$env_file" API_SERVER_HOST)"
  api_enabled="$(read_env_value "$env_file" API_SERVER_ENABLED)"

  printf '\n-- %s --\n' "$profile"
  value "profile dir" "$profile_dir"
  value "workspace" "$workspace"
  value "config" "${config_file:-missing}"
  value "env" "${env_file:-missing}"
  value "dashboard port" "$dashboard_port"
  value "api host/port" "${api_host:-not set}:${api_port:-not set}"
  value "api enabled" "${api_enabled:-not set}"
  value "api key" "$(mask_secret "$api_key")"
  value "dashboard local /" "$(http_code "http://127.0.0.1:${dashboard_port}/")"
  value "api local /health" "$(http_code "http://127.0.0.1:${api_port}/health")"
  if [ -n "$PUBLIC_HOST" ]; then
    value "dashboard public /" "$(http_code "http://${PUBLIC_HOST}:${dashboard_port}/")"
    value "api public /health" "$(http_code "http://${PUBLIC_HOST}:${api_port}/health")"
  fi

  dash_listener="$(listener_line_for_port "$dashboard_port" | head -1)"
  api_listener="$(listener_line_for_port "$api_port" | head -1)"
  value "dashboard listener" "${dash_listener:-not listening}"
  value "api listener" "${api_listener:-not listening}"
  if contains_listener_any "$dashboard_port" && ! contains_listener_public "$dashboard_port"; then
    warn "$profile desktop remote" "dashboard listens locally only; use SSH tunnel or reverse proxy"
  fi
done

section "Missing Pieces"
missing_any=false
if [ ! -d "$TEMPLATE_ROOT" ]; then
  miss "template root" "$TEMPLATE_ROOT"
  missing_any=true
else
  for agent in "${required_agents[@]}"; do
    if [ ! -d "$TEMPLATE_ROOT/agents/$agent" ]; then
      miss "template agent" "$agent"
      missing_any=true
      continue
    fi
    for file in "${required_agent_files[@]}"; do
      if [ ! -f "$TEMPLATE_ROOT/agents/$agent/$file" ]; then
        miss "template agent file" "agents/$agent/$file"
        missing_any=true
      fi
    done
  done
  for file in "${required_memory_files[@]}"; do
    if [ ! -f "$TEMPLATE_ROOT/$file" ]; then
      miss "template memory" "$file"
      missing_any=true
    fi
  done
  if [ ! -f "$TEMPLATE_ROOT/config/config.yaml" ]; then
    miss "template config" "config/config.yaml"
    missing_any=true
  fi
fi

for profile in "${profiles[@]}"; do
  workspace="$DATA_ROOT/profile-workspaces/$profile"
  profile_dir="$DATA_ROOT/profiles/$profile"
  if [ ! -d "$profile_dir" ]; then
    miss "$profile profile" "$profile_dir"
    missing_any=true
  fi
  if [ ! -d "$workspace" ]; then
    miss "$profile workspace" "$workspace"
    missing_any=true
    continue
  fi
  for agent in "${required_agents[@]}"; do
    if [ ! -d "$workspace/agents/$agent" ]; then
      miss "$profile agent" "$agent"
      missing_any=true
      continue
    fi
    for file in "${required_agent_files[@]}"; do
      if [ ! -f "$workspace/agents/$agent/$file" ]; then
        miss "$profile agent file" "agents/$agent/$file"
        missing_any=true
      fi
    done
  done
  for file in "${required_memory_files[@]}"; do
    if [ ! -f "$workspace/$file" ]; then
      miss "$profile memory" "$file"
      missing_any=true
    fi
  done
done
[ "$missing_any" = false ] && ok "stack files" "template plus all required profiles, agents, and memory files present"

section "Recommended Next Commands"
cat <<'EOF'
# Pull newest docs/scripts:
cd ~/hermes-agent
git pull origin main

# Install/update missing memory files:
bash docs/marketing-growth-team/deploy/install-memory-system.sh

# Add optional/new agents if missing:
bash docs/marketing-growth-team/deploy/add-deep-research-agent.sh
bash docs/marketing-growth-team/deploy/add-memory-review-reflector-agent.sh

# Upgrade already deployed profile docs to latest routing rules:
bash docs/marketing-growth-team/deploy/upgrade-profile-memory-routing.sh

# Run strict audits:
bash docs/marketing-growth-team/deploy/audit-agent-docs.sh --report /tmp/marketing-growth-template-audit.md

for p in arnela denis arman testing; do
  bash docs/marketing-growth-team/deploy/audit-agent-docs.sh --profile "$p" --report "/tmp/$p-agent-audit.md"
done

# Show audit warnings/failures:
grep -n "WARN:\|FAIL:" /tmp/marketing-growth-template-audit.md /tmp/*-agent-audit.md
EOF

section "Optional Audit"
if [ "$RUN_AUDIT" = true ]; then
  if [ -x docs/marketing-growth-team/deploy/audit-agent-docs.sh ]; then
    template_report="/tmp/marketing-growth-template-audit.md"
    printf '\n-- audit blueprint template --\n'
    if [ -d "$TEMPLATE_ROOT" ]; then
      if bash docs/marketing-growth-team/deploy/audit-agent-docs.sh --root "$TEMPLATE_ROOT" --report "$template_report" >/tmp/stack-status-audit.$$ 2>&1; then
        tail -n 8 /tmp/stack-status-audit.$$
      else
        cat /tmp/stack-status-audit.$$
      fi
      rm -f /tmp/stack-status-audit.$$
    else
      warn "template audit" "template root missing: $TEMPLATE_ROOT"
    fi

    for profile in "${profiles[@]}"; do
      report="/tmp/${profile}-agent-audit.md"
      printf '\n-- audit %s --\n' "$profile"
      if bash docs/marketing-growth-team/deploy/audit-agent-docs.sh --profile "$profile" --report "$report" >/tmp/stack-status-audit.$$ 2>&1; then
        tail -n 8 /tmp/stack-status-audit.$$
      else
        cat /tmp/stack-status-audit.$$
      fi
      rm -f /tmp/stack-status-audit.$$
    done
  else
    warn "audit" "audit-agent-docs.sh not executable/found"
  fi
else
  value "audit" "skipped; pass --audit to run template and profile audits"
fi
