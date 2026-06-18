#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="${TEMPLATE_DIR:-docs/marketing-growth-team}"
DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
PROFILES=()

usage() {
  cat <<EOF
Usage:
  $0 [profile...]

Adds the Deep Research agent to one or more profile workspaces and updates
the profile's orchestrator documentation.

Defaults:
  profiles: arnela denis arman testing

Examples:
  $0
  $0 arnela testing
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
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

SOURCE_AGENT_DIR="$TEMPLATE_DIR/agents/deep-research"
if [ ! -d "$SOURCE_AGENT_DIR" ]; then
  echo "Deep Research template not found: $SOURCE_AGENT_DIR" >&2
  exit 1
fi

required_files=(ROLE.md SYSTEM.md SKILLS.md TOOLS.md MEMORY.md WORKFLOWS.md SUBAGENTS.md)
for file in "${required_files[@]}"; do
  if [ ! -f "$SOURCE_AGENT_DIR/$file" ]; then
    echo "Missing Deep Research template file: $SOURCE_AGENT_DIR/$file" >&2
    exit 1
  fi
done

append_block_once() {
  local file="$1"
  local begin="$2"
  local end="$3"
  local content="$4"

  touch "$file"
  if grep -Fq "$begin" "$file"; then
    return 0
  fi

  {
    printf '\n%s\n' "$begin"
    printf '%s\n' "$content"
    printf '%s\n' "$end"
  } >> "$file"
}

update_orchestrator() {
  local workspace="$1"
  local subagents="$workspace/agents/orchestrator/SUBAGENTS.md"
  local workflows="$workspace/agents/orchestrator/WORKFLOWS.md"
  local skills="$workspace/agents/orchestrator/SKILLS.md"

  append_block_once \
    "$subagents" \
    "<!-- deep-research-agent:start -->" \
    "<!-- deep-research-agent:end -->" \
    "## Deep Research Agent

- Deep Research: Markt-, Wettbewerbs-, Persona-, Trend-, Quellen- und Evidence-Research.

Setze Deep Research ein, wenn eine Aufgabe belastbare Quellen, aktuelle Marktdaten, Wettbewerbsvergleiche, Persona-Evidenz, Trendbewertung oder Claim-Validierung braucht. Deep Research arbeitet Skill-/MCP-first, bewertet Quellenqualitaet und liefert entscheidungsorientierte Briefs an den Orchestrator und die Spezialagents."

  append_block_once \
    "$workflows" \
    "<!-- deep-research-agent:start -->" \
    "<!-- deep-research-agent:end -->" \
    "## Deep Research Workflow

1. Orchestrator klaert Research-Frage, Entscheidungskontext, Zielgruppe, Region und Zeitraum.
2. Deep Research prueft vorhandene Skills, Memory und passende MCP-Server.
3. Deep Research erstellt Quellenplan, sammelt Evidenz und bewertet Quellenqualitaet.
4. Deep Research liefert Evidence-Brief mit Erkenntnissen, Unsicherheiten und Empfehlungen.
5. Orchestrator uebersetzt Research-Ergebnisse in Aufgaben fuer Content, Social, SEO, Creative und Analytics.
6. Wiederkehrende Research-Muster werden als Skills erstellt oder verbessert."

  append_block_once \
    "$skills" \
    "<!-- deep-research-agent:start -->" \
    "<!-- deep-research-agent:end -->" \
    "## Deep Research Skill-Kandidaten

- \`marketing-growth/deep-research-brief\`
- \`marketing-growth/source-quality-rubric\`
- \`marketing-growth/competitor-intel\`
- \`marketing-growth/persona-research\`
- \`marketing-growth/trend-scan\`
- \`marketing-growth/evidence-brief\`
- \`marketing-growth/research-to-content-brief\`"
}

echo "Adding Deep Research agent to profiles: ${PROFILES[*]}"

for profile in "${PROFILES[@]}"; do
  workspace="$DATA_ROOT/profile-workspaces/$profile"
  profile_dir="$DATA_ROOT/profiles/$profile"

  echo "== $profile =="
  if [ ! -d "$profile_dir" ]; then
    echo "Profile directory not found: $profile_dir" >&2
    exit 1
  fi

  if [ ! -d "$workspace" ]; then
    echo "Workspace not found, creating from template: $workspace"
    mkdir -p "$workspace"
    cp -a "$TEMPLATE_DIR/." "$workspace/"
  fi

  mkdir -p "$workspace/agents"
  rm -rf "$workspace/agents/deep-research"
  cp -a "$SOURCE_AGENT_DIR" "$workspace/agents/deep-research"
  update_orchestrator "$workspace"

  chown -R "${HERMES_UID:-10000}:${HERMES_GID:-10000}" "$workspace" 2>/dev/null || true
  echo "Deep Research installed at: $workspace/agents/deep-research"
done

cat <<EOF

Done.

Test prompt:
  Nutze den Deep Research Agent unter /opt/data/profile-workspaces/<profile>/agents/deep-research und erstelle einen Evidence-Brief fuer eine LinkedIn-Kampagne.
EOF

