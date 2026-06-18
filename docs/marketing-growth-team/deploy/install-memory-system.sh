#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="${TEMPLATE_DIR:-docs/marketing-growth-team}"
DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
PROFILES=()

usage() {
  cat <<EOF
Usage:
  $0 [profile...]

Installs the curated Marketing & Growth memory system into one or more
isolated profile workspaces.

Defaults:
  profiles: arnela denis arman testing

Examples:
  $0
  $0 arnela testing

Environment:
  TEMPLATE_DIR       Template root. Default: docs/marketing-growth-team
  HERMES_DATA_ROOT   Hermes data root. Default: \$HOME/.hermes
  HERMES_UID         Owner uid for deployed files. Default: 10000
  HERMES_GID         Owner gid for deployed files. Default: 10000
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

SOURCE_MEMORY_DIR="$TEMPLATE_DIR/memory"
if [ ! -d "$SOURCE_MEMORY_DIR" ]; then
  echo "Memory template not found: $SOURCE_MEMORY_DIR" >&2
  exit 1
fi

required_files=(
  shared/BRAND.md
  shared/AUDIENCES.md
  shared/OFFERS.md
  shared/COMPLIANCE.md
  shared/CAMPAIGNS.md
  shared/SOURCES.md
  orchestrator/DECISIONS.md
  orchestrator/TEAM_LEARNINGS.md
  orchestrator/SKILL_BACKLOG.md
  orchestrator/REVIEW_QUEUE.md
  agents/content-writer.md
  agents/social-media-specialist.md
  agents/seo-web.md
  agents/creative-design.md
  agents/campaign-analyst.md
  agents/deep-research.md
  agents/memory-review-reflector.md
  protocols/MEMORY_POLICY.md
  protocols/SELF_LEARNING_LOOP.md
  protocols/MEMORY_REVIEW_CHECKLIST.md
  protocols/SKILL_BUILDER_WORKFLOW.md
)

for file in "${required_files[@]}"; do
  if [ ! -f "$SOURCE_MEMORY_DIR/$file" ]; then
    echo "Missing memory template file: $SOURCE_MEMORY_DIR/$file" >&2
    exit 1
  fi
done

copy_missing_memory_files() {
  local workspace="$1"
  local target="$workspace/memory"

  mkdir -p "$target/shared" "$target/orchestrator" "$target/agents" "$target/protocols"

  for file in "${required_files[@]}"; do
    if [ ! -f "$target/$file" ]; then
      cp "$SOURCE_MEMORY_DIR/$file" "$target/$file"
      echo "  + memory/$file"
    else
      echo "  = memory/$file exists"
    fi
  done
}

append_block_once() {
  local file="$1"
  local begin="$2"
  local end="$3"
  local content="$4"

  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -Fq "$begin" "$file" || grep -Fq "## Curated Memory System" "$file"; then
    return 0
  fi

  {
    printf '\n%s\n' "$begin"
    printf '%s\n' "$content"
    printf '%s\n' "$end"
  } >> "$file"
}

agent_memory_file_for() {
  case "$1" in
    content-writer) printf '%s\n' "memory/agents/content-writer.md" ;;
    social-media-specialist) printf '%s\n' "memory/agents/social-media-specialist.md" ;;
    seo-web) printf '%s\n' "memory/agents/seo-web.md" ;;
    creative-design) printf '%s\n' "memory/agents/creative-design.md" ;;
    campaign-analyst) printf '%s\n' "memory/agents/campaign-analyst.md" ;;
    deep-research) printf '%s\n' "memory/agents/deep-research.md" ;;
    memory-review-reflector) printf '%s\n' "memory/agents/memory-review-reflector.md" ;;
    *) printf '%s\n' "" ;;
  esac
}

update_agent_memory_instructions() {
  local workspace="$1"
  local agent="$2"
  local agent_file="$workspace/agents/$agent/MEMORY.md"
  local role_memory

  role_memory="$(agent_memory_file_for "$agent")"
  if [ -z "$role_memory" ]; then
    return 0
  fi

  if [ ! -d "$workspace/agents/$agent" ]; then
    echo "  ! agent missing, skipped memory binding: $agent"
    return 0
  fi

  append_block_once \
    "$agent_file" \
    "<!-- curated-memory-system:start -->" \
    "<!-- curated-memory-system:end -->" \
    "## Curated Memory System

Nutze Memory kuratiert, nicht als Rohdatenablage.

Vor komplexen Aufgaben pruefst du:

- \`memory/shared/BRAND.md\`
- \`memory/shared/AUDIENCES.md\`
- \`memory/shared/OFFERS.md\`
- \`memory/shared/COMPLIANCE.md\`
- \`memory/shared/CAMPAIGNS.md\`
- \`memory/shared/SOURCES.md\`
- \`$role_memory\`
- \`memory/protocols/MEMORY_POLICY.md\`
- \`memory/protocols/SELF_LEARNING_LOOP.md\`
- \`memory/protocols/SKILL_BUILDER_WORKFLOW.md\`

Nach komplexen oder wiederkehrenden Aufgaben:

1. Aufgabe abschliessen.
2. Learning auf Stabilitaet, Allgemeingueltigkeit, Faktenbasis, Sensibilitaet und Konflikte pruefen.
3. Stabile teamweite Learnings nach \`memory/shared\` einsortieren.
4. Rollenspezifische Learnings in \`$role_memory\` schreiben.
5. Cross-Agent-Entscheidungen oder Operating Rules nach \`memory/orchestrator\` schreiben.
6. Wiederholbare Ablaeufe in \`memory/orchestrator/SKILL_BACKLOG.md\` vorschlagen.
7. Unsichere, sensible, widerspruechliche oder freigabepflichtige Items in \`memory/orchestrator/REVIEW_QUEUE.md\` vorschlagen.
8. Alte widerspruechliche Memory markieren statt still zu ueberschreiben.

Speichere keine Secrets, privaten Daten, Rohtranskripte oder ungeprueften Claims."
}

update_orchestrator_memory_instructions() {
  local workspace="$1"
  local orchestrator_file="$workspace/agents/orchestrator/MEMORY.md"

  if [ ! -d "$workspace/agents/orchestrator" ]; then
    echo "  ! orchestrator missing, skipped memory binding"
    return 0
  fi

  append_block_once \
    "$orchestrator_file" \
    "<!-- curated-memory-system:start -->" \
    "<!-- curated-memory-system:end -->" \
    "## Curated Memory System

Der Orchestrator ist Owner der gemeinsamen Memory-Qualitaet.

Vor Planung und Delegation pruefst du:

- \`memory/shared/BRAND.md\`
- \`memory/shared/AUDIENCES.md\`
- \`memory/shared/OFFERS.md\`
- \`memory/shared/COMPLIANCE.md\`
- \`memory/shared/CAMPAIGNS.md\`
- \`memory/shared/SOURCES.md\`
- \`memory/orchestrator/DECISIONS.md\`
- \`memory/orchestrator/TEAM_LEARNINGS.md\`
- \`memory/orchestrator/SKILL_BACKLOG.md\`
- \`memory/protocols/MEMORY_POLICY.md\`
- \`memory/protocols/SELF_LEARNING_LOOP.md\`

Nach komplexen Aufgaben:

1. Aufgabe abschliessen.
2. Learning auf Stabilitaet, Allgemeingueltigkeit, Faktenbasis, Sensibilitaet und Konflikte pruefen.
3. Freigegebene teamweite Learnings nach \`memory/shared\` promoten.
4. Rollenspezifische Learnings nach \`memory/agents\` einsortieren.
5. Cross-Agent-Entscheidungen und Operating Rules nach \`memory/orchestrator\` schreiben.
6. Wiederholbare Ablaeufe in \`memory/orchestrator/SKILL_BACKLOG.md\` aufnehmen.
7. Unsichere, sensible, widerspruechliche oder freigabepflichtige Items in \`memory/orchestrator/REVIEW_QUEUE.md\` belassen.
8. Alte widerspruechliche Memory markieren statt still zu ueberschreiben.

Regel: Shared Memory ist kuratiert und gilt fuer alle Agents. Agent Memory bleibt rollenspezifisch. Rohdaten, Secrets und private Daten gehoeren nie ins Langzeit-Memory."
}

echo "Installing curated memory system for profiles: ${PROFILES[*]}"

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

  copy_missing_memory_files "$workspace"
  update_orchestrator_memory_instructions "$workspace"

  for agent in \
    content-writer \
    social-media-specialist \
    seo-web \
    creative-design \
    campaign-analyst \
    deep-research \
    memory-review-reflector
  do
    update_agent_memory_instructions "$workspace" "$agent"
  done

  chown -R "${HERMES_UID:-10000}:${HERMES_GID:-10000}" "$workspace" 2>/dev/null || true
  echo "Memory system installed at: $workspace/memory"
done

cat <<EOF

Done.

Verify one profile:
  find ~/.hermes/profile-workspaces/arnela/memory -maxdepth 2 -type f | sort
  grep -n "Curated Memory System" ~/.hermes/profile-workspaces/arnela/agents/orchestrator/MEMORY.md
EOF
