#!/usr/bin/env bash
set -u

PROFILES=()
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-180}"
RUNNER="${RUNNER:-auto}"
CASE_FILTER="${CASE_FILTER:-}"
OUTPUT_DIR="${OUTPUT_DIR:-}"

usage() {
  cat <<EOF
Usage:
  $0 [--runner auto|docker|local] [--timeout SECONDS] [--case CASE] [--output-dir DIR] [profile...]

Runtime verification for live Marketing & Growth role routing. This performs
real Hermes chat calls, so it may use model credits and take time.

It asks the Orchestrator which Specialist should own a concrete task and checks
that the answer routes to the expected agent and skill family.

Defaults:
  profiles: arnela denis arman testing
  runner:   auto
  timeout:  180

Examples:
  $0 denis
  $0 --case seo denis
  $0 --output-dir /tmp/marketing-runtime-routing
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --runner)
      RUNNER="${2:-}"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2:-}"
      shift 2
      ;;
    --case)
      CASE_FILTER="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
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

if ! printf '%s' "$TIMEOUT_SECONDS" | grep -Eq '^[0-9]+$'; then
  echo "Timeout must be numeric." >&2
  exit 2
fi

command_exists() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n== %s ==\n' "$1"; }
pass() { printf 'PASS %-38s %s\n' "$1" "$2"; }
warn() { printf 'WARN %-38s %s\n' "$1" "$2"; }
fail() { printf 'FAIL %-38s %s\n' "$1" "$2"; }

pick_runner() {
  case "$RUNNER" in
    docker)
      command_exists docker && docker inspect hermes >/dev/null 2>&1
      ;;
    local)
      command_exists hermes
      ;;
    auto)
      if command_exists docker && docker inspect hermes >/dev/null 2>&1; then
        printf 'docker'
      elif command_exists hermes; then
        printf 'local'
      else
        return 1
      fi
      ;;
    *)
      echo "Unknown runner: $RUNNER" >&2
      return 1
      ;;
  esac
}

runtime_runner="$(pick_runner || true)"
if [ -z "$runtime_runner" ]; then
  echo "No Hermes runtime found. Need docker container 'hermes' or local 'hermes' command." >&2
  exit 1
fi
if [ "$RUNNER" = "docker" ]; then
  runtime_runner="docker"
elif [ "$RUNNER" = "local" ]; then
  runtime_runner="local"
fi

run_chat() {
  local profile="$1"
  local prompt="$2"
  if [ "$runtime_runner" = "docker" ]; then
    docker exec -i hermes hermes -p "$profile" chat -q "$prompt"
  else
    hermes -p "$profile" chat -q "$prompt"
  fi
}

contains_any() {
  local text="$1"
  shift
  local term
  for term in "$@"; do
    printf '%s' "$text" | grep -Eiq -- "$term" && return 0
  done
  return 1
}

contains_group() {
  local text="$1"
  local group="$2"
  IFS='|' read -r -a terms <<< "$group"
  contains_any "$text" "${terms[@]}"
}

case_names=(seo copy social creative analytics research memory)
case_agents=(
  "seo-web|SEO & Web"
  "content-writer|Content Writer"
  "social-media-specialist|Social Media Specialist"
  "creative-design|Creative / Design"
  "campaign-analyst|Campaign Analyst"
  "deep-research|Deep Research"
  "memory-review-reflector|Memory Review"
)
case_skill_groups=(
  "landing-page-audit|search-intent-brief|prelaunch-tracking-check|utm-taxonomy"
  "brand-voice-writer|landing-page-copy|linkedin-post-series|email-nurture-sequence|ad-copy-variants"
  "linkedin-calendar|social-repurposing|social-scheduling-checklist|hashtag-and-topic-map|comment-playbook"
  "visual-campaign-brief|flux-image-prompt|linkedin-carousel-production|brand-asset-qa|presentation-deck-outline"
  "kpi-tree|utm-validator|weekly-campaign-report|dashboard-brief|experiment-design"
  "deep-research-brief|source-quality-rubric|competitor-intel|persona-research|evidence-brief|trend-scan"
  "memory-review-triage|memory-conflict-resolution|skill-backlog-prioritizer|skill-builder-brief|memory-quality-audit"
)
case_prompts=(
  "Ein Nutzer fragt: Pruefe eine Kampagnen-Landingpage auf SEO, Message Match, UTM und Tracking vor Launch. Antworte knapp im Format: OWNER: <agent>; SKILLS: <skill ids>; MCP: <server ids>; WHY: <ein Satz>. Nenne den Specialist, nicht nur dich als Orchestrator."
  "Ein Nutzer fragt: Schreibe Landingpage-Hero, LinkedIn-Post-Serie und E-Mail-Nurture-Copy fuer eine Kampagne. Antworte knapp im Format: OWNER: <agent>; SKILLS: <skill ids>; MCP: <server ids>; WHY: <ein Satz>. Nenne den Specialist, nicht nur dich als Orchestrator."
  "Ein Nutzer fragt: Plane einen 14-Tage-LinkedIn-Kalender inklusive Scheduling-Checkliste, Hashtags und Community-Kommentaren. Antworte knapp im Format: OWNER: <agent>; SKILLS: <skill ids>; MCP: <server ids>; WHY: <ein Satz>. Nenne den Specialist, nicht nur dich als Orchestrator."
  "Ein Nutzer fragt: Erstelle ein Visual-Briefing, Bildprompts und ein LinkedIn-Carousel fuer eine Kampagne. Antworte knapp im Format: OWNER: <agent>; SKILLS: <skill ids>; MCP: <server ids>; WHY: <ein Satz>. Nenne den Specialist, nicht nur dich als Orchestrator."
  "Ein Nutzer fragt: Definiere KPI-Tree, UTM-Regeln, Dashboard-Brief und Experimentdesign fuer eine Kampagne. Antworte knapp im Format: OWNER: <agent>; SKILLS: <skill ids>; MCP: <server ids>; WHY: <ein Satz>. Nenne den Specialist, nicht nur dich als Orchestrator."
  "Ein Nutzer fragt: Recherchiere Wettbewerber, Personas, Trends und Quellenqualitaet fuer eine neue Kampagne. Antworte knapp im Format: OWNER: <agent>; SKILLS: <skill ids>; MCP: <server ids>; WHY: <ein Satz>. Nenne den Specialist, nicht nur dich als Orchestrator."
  "Ein Nutzer fragt: Pruefe Review Queue, Team Learnings, Skill Backlog und widerspruechliche Memory-Eintraege. Antworte knapp im Format: OWNER: <agent>; SKILLS: <skill ids>; MCP: <server ids>; WHY: <ein Satz>. Nenne den Specialist, nicht nur dich als Orchestrator."
)

if [ -n "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
fi

section "Marketing Growth Runtime Role Routing Verification"
printf '%-10s %s\n' "runner:" "$runtime_runner"
printf '%-10s %s\n' "timeout:" "$TIMEOUT_SECONDS"
printf '%-10s %s\n' "profiles:" "${PROFILES[*]}"
[ -n "$CASE_FILTER" ] && printf '%-10s %s\n' "case:" "$CASE_FILTER"

for profile in "${PROFILES[@]}"; do
  section "$profile"
  i=0
  for name in "${case_names[@]}"; do
    agent_pattern="${case_agents[$i]}"
    skill_pattern="${case_skill_groups[$i]}"
    prompt="${case_prompts[$i]}"
    i=$((i + 1))

    if [ -n "$CASE_FILTER" ] && [ "$CASE_FILTER" != "$name" ]; then
      continue
    fi

    label="$profile $name routing"
    if [ "$runtime_runner" = "docker" ]; then
      output="$(timeout "$TIMEOUT_SECONDS" docker exec -i hermes hermes -p "$profile" chat -q "$prompt" 2>&1)"
      status=$?
    else
      output="$(timeout "$TIMEOUT_SECONDS" hermes -p "$profile" chat -q "$prompt" 2>&1)"
      status=$?
    fi
    if [ "$status" -ne 0 ]; then
      fail "$label" "chat failed or timed out"
      [ -n "$OUTPUT_DIR" ] && printf '%s\n' "$output" > "$OUTPUT_DIR/${profile}-${name}.txt"
      continue
    fi

    [ -n "$OUTPUT_DIR" ] && printf '%s\n' "$output" > "$OUTPUT_DIR/${profile}-${name}.txt"

    if ! contains_group "$output" "$agent_pattern"; then
      fail "$label" "expected owner matching: $agent_pattern"
      continue
    fi
    if ! contains_group "$output" "$skill_pattern"; then
      fail "$label" "expected skill family matching: $skill_pattern"
      continue
    fi
    if contains_any "$output" "OWNER:[[:space:]]*orchestrator" "Owner:[[:space:]]*Orchestrator"; then
      warn "$label" "answer names orchestrator as owner; inspect output"
      continue
    fi
    pass "$label" "owner and skill family correct"
  done
done
