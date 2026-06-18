#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="${TEMPLATE_DIR:-docs/marketing-growth-team}"
DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
PROFILES=()

usage() {
  cat <<EOF
Usage:
  $0 [profile...]

Adds the Memory Review / Reflektor agent to one or more profile workspaces and
updates the profile's orchestrator documentation.

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

SOURCE_AGENT_DIR="$TEMPLATE_DIR/agents/memory-review-reflector"
if [ ! -d "$SOURCE_AGENT_DIR" ]; then
  echo "Memory Review / Reflektor template not found: $SOURCE_AGENT_DIR" >&2
  exit 1
fi

required_files=(ROLE.md SYSTEM.md SKILLS.md TOOLS.md MEMORY.md WORKFLOWS.md SUBAGENTS.md)
for file in "${required_files[@]}"; do
  if [ ! -f "$SOURCE_AGENT_DIR/$file" ]; then
    echo "Missing Memory Review / Reflektor template file: $SOURCE_AGENT_DIR/$file" >&2
    exit 1
  fi
done

append_block_once() {
  local file="$1"
  local begin="$2"
  local end="$3"
  local content="$4"

  mkdir -p "$(dirname "$file")"
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

copy_missing_file() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"
  if [ ! -f "$target" ]; then
    cp "$source" "$target"
    echo "  + ${target##*/}"
  else
    echo "  = ${target##*/} exists"
  fi
}

update_orchestrator() {
  local workspace="$1"
  local subagents="$workspace/agents/orchestrator/SUBAGENTS.md"
  local workflows="$workspace/agents/orchestrator/WORKFLOWS.md"
  local skills="$workspace/agents/orchestrator/SKILLS.md"

  append_block_once \
    "$subagents" \
    "<!-- memory-review-reflector-agent:start -->" \
    "<!-- memory-review-reflector-agent:end -->" \
    "## Memory Review / Reflektor Agent

- Memory Review / Reflektor: Review Queue, Team Learnings, Skill Backlog, Memory-Konflikte, stale Claims und Skill-Builder-Briefs.

Setze Memory Review / Reflektor ein, wenn REVIEW_QUEUE.md, TEAM_LEARNINGS.md oder SKILL_BACKLOG.md kuratiert werden muessen, wenn widerspruechliche Memory auftaucht, wenn Learnings promoted werden sollen oder wenn wiederholte Muster in einen Skill Builder Brief uebersetzt werden sollen."

  append_block_once \
    "$workflows" \
    "<!-- memory-review-reflector-agent:start -->" \
    "<!-- memory-review-reflector-agent:end -->" \
    "## Memory Review / Reflektor Workflow

1. Orchestrator definiert Scope: Profil, Kampagne, Zeitraum oder gesamtes Team.
2. Reflektor prueft Skills, Memory-Protokolle, Review Queue, Team Learnings, Skill Backlog und relevante Agent-Memory.
3. Reflektor bewertet Items nach Stabilitaet, Allgemeingueltigkeit, Faktenbasis, Sensibilitaet und Konflikten.
4. Reflektor liefert Promote-/Reject-/Needs-Source-/Conflict-Entscheidungen.
5. Wiederholte Muster werden als Skill Builder Briefs dokumentiert.
6. Orchestrator entscheidet ueber Promotions, Skill-Erstellung und naechste Reviews."

  append_block_once \
    "$skills" \
    "<!-- memory-review-reflector-agent:start -->" \
    "<!-- memory-review-reflector-agent:end -->" \
    "## Memory Review / Reflektor Skill-Kandidaten

- \`marketing-growth/memory-review-triage\`
- \`marketing-growth/memory-conflict-resolution\`
- \`marketing-growth/skill-backlog-prioritizer\`
- \`marketing-growth/skill-builder-brief\`
- \`marketing-growth/post-task-learning-review\`
- \`marketing-growth/memory-quality-audit\`
- \`marketing-growth/observability-to-learning\`"
}

echo "Adding Memory Review / Reflektor agent to profiles: ${PROFILES[*]}"

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
  rm -rf "$workspace/agents/memory-review-reflector"
  cp -a "$SOURCE_AGENT_DIR" "$workspace/agents/memory-review-reflector"

  copy_missing_file \
    "$TEMPLATE_DIR/memory/agents/memory-review-reflector.md" \
    "$workspace/memory/agents/memory-review-reflector.md"

  copy_missing_file \
    "$TEMPLATE_DIR/memory/protocols/SKILL_BUILDER_WORKFLOW.md" \
    "$workspace/memory/protocols/SKILL_BUILDER_WORKFLOW.md"

  update_orchestrator "$workspace"

  chown -R "${HERMES_UID:-10000}:${HERMES_GID:-10000}" "$workspace" 2>/dev/null || true
  echo "Memory Review / Reflektor installed at: $workspace/agents/memory-review-reflector"
done

cat <<EOF

Done.

Test prompt:
  Nutze den Memory Review / Reflektor Agent unter /opt/data/profile-workspaces/<profile>/agents/memory-review-reflector und pruefe REVIEW_QUEUE.md, TEAM_LEARNINGS.md und SKILL_BACKLOG.md.
EOF
