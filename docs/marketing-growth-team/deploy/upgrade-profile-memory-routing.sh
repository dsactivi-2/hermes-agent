#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="${TEMPLATE_DIR:-docs/marketing-growth-team}"
DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
PROFILES=()

usage() {
  cat <<EOF
Usage:
  $0 [profile...]

Upgrades existing Marketing & Growth profile workspaces to the current
post-task memory routing, Skill Builder, and Memory Review / Reflektor setup.

It is idempotent and only appends missing upgrade blocks or copies missing
new files. It does not delete existing profile notes.

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

required_template_paths=(
  agents/memory-review-reflector
  memory/agents/memory-review-reflector.md
  memory/protocols/SKILL_BUILDER_WORKFLOW.md
)

for path in "${required_template_paths[@]}"; do
  if [ ! -e "$TEMPLATE_DIR/$path" ]; then
    echo "Missing template path: $TEMPLATE_DIR/$path" >&2
    exit 1
  fi
done

append_block_once() {
  local file="$1"
  local marker="$2"
  local content="$3"

  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -Fq "$marker" "$file"; then
    return 0
  fi

  {
    printf '\n<!-- %s:start -->\n' "$marker"
    printf '%s\n' "$content"
    printf '<!-- %s:end -->\n' "$marker"
  } >> "$file"
}

copy_missing_file() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"
  if [ ! -f "$target" ]; then
    cp "$source" "$target"
    echo "  + $target"
  else
    echo "  = $target exists"
  fi
}

agent_role_memory() {
  case "$1" in
    content-writer) printf 'memory/agents/content-writer.md' ;;
    social-media-specialist) printf 'memory/agents/social-media-specialist.md' ;;
    seo-web) printf 'memory/agents/seo-web.md' ;;
    creative-design) printf 'memory/agents/creative-design.md' ;;
    campaign-analyst) printf 'memory/agents/campaign-analyst.md' ;;
    deep-research) printf 'memory/agents/deep-research.md' ;;
    memory-review-reflector) printf 'memory/agents/memory-review-reflector.md' ;;
    orchestrator) printf 'memory/orchestrator' ;;
    *) printf 'memory/agents' ;;
  esac
}

upgrade_agent_memory() {
  local workspace="$1"
  local agent="$2"
  local file="$workspace/agents/$agent/MEMORY.md"
  local role_memory

  if [ ! -f "$file" ]; then
    echo "  ! $agent MEMORY.md missing, skipped"
    return 0
  fi

  if grep -Eq 'Post-Task Memory Routing|Stabilitaet.*Allgemeingueltigkeit.*Faktenbasis.*Sensibilitaet.*Konflikte' "$file"; then
    echo "  = $agent MEMORY.md already has post-task routing"
    return 0
  fi

  role_memory="$(agent_role_memory "$agent")"

  append_block_once \
    "$file" \
    "post-task-memory-routing-upgrade" \
    "## Post-Task Memory Routing

Nach komplexen oder wiederkehrenden Aufgaben fuehrst du diesen Ablauf aus:

1. Aufgabe abgeschlossen.
2. Learning pruefen: Stabilitaet, Allgemeingueltigkeit, Faktenbasis, Sensibilitaet und Konflikte mit bestehendem Memory.
3. Stabile teamweite Learnings nach \`memory/shared\` einsortieren.
4. Rollenspezifische Learnings nach \`$role_memory\` einsortieren.
5. Cross-Agent-Entscheidungen oder Operating Rules nach \`memory/orchestrator\` schreiben.
6. Wiederholbare Ablaeufe in \`memory/orchestrator/SKILL_BACKLOG.md\` vorschlagen.
7. Unsichere, sensible, widerspruechliche oder freigabepflichtige Items in \`memory/orchestrator/REVIEW_QUEUE.md\` vorschlagen.
8. Alte widerspruechliche Memory als conflicting, superseded oder needs-review markieren statt still zu ueberschreiben.

Speichere keine Secrets, privaten Daten, Rohtranskripte oder ungeprueften Claims."
  echo "  + $agent MEMORY.md post-task routing"
}

upgrade_protocols() {
  local workspace="$1"
  local self_learning="$workspace/memory/protocols/SELF_LEARNING_LOOP.md"
  local memory_policy="$workspace/memory/protocols/MEMORY_POLICY.md"
  local skill_builder="$workspace/memory/protocols/SKILL_BUILDER_WORKFLOW.md"

  copy_missing_file \
    "$TEMPLATE_DIR/memory/protocols/SKILL_BUILDER_WORKFLOW.md" \
    "$skill_builder"

  if [ -f "$self_learning" ] && ! grep -Fq "Post-Task Memory Routing" "$self_learning"; then
    append_block_once \
      "$self_learning" \
      "post-task-memory-routing-upgrade" \
      "## Post-Task Memory Routing

After every complex task, each agent must run this routing check:

1. Task completed.
2. Check every candidate learning:
   - Is the learning stable beyond this task?
   - Does it apply only to this task or generally?
   - Is it factually supported by a source, metric, output, or stakeholder decision?
   - Is it personal, sensitive, secret, or compliance-relevant?
   - Does it conflict with existing memory?
3. Route the learning:
   - \`memory/shared\`: approved team-wide brand, audience, offer, compliance, campaign, or source knowledge.
   - \`memory/agents\`: role-specific stable patterns and learnings.
   - \`memory/orchestrator\`: cross-agent decisions, team learnings, and operating rules.
   - \`memory/orchestrator/SKILL_BACKLOG.md\`: repeatable procedures that should become or improve Hermes Skills.
   - \`memory/orchestrator/REVIEW_QUEUE.md\`: uncertain, sensitive, conflicting, low-confidence, or approval-needed items.
4. Mark old contradictory memory instead of silently deleting it.
5. Do not store raw transcripts, secrets, personal data, or unsupported claims as durable memory."
    echo "  + SELF_LEARNING_LOOP.md post-task routing"
  else
    echo "  = SELF_LEARNING_LOOP.md post-task routing present"
  fi

  if [ -f "$memory_policy" ] && ! grep -Fq "Post-Task Routing Rule" "$memory_policy"; then
    append_block_once \
      "$memory_policy" \
      "post-task-routing-rule-upgrade" \
      "## Post-Task Routing Rule

After complex tasks, every agent must classify each candidate learning before writing it:

- Stable, approved, team-wide knowledge goes to \`memory/shared\`.
- Stable role-specific knowledge goes to \`memory/agents/<agent>.md\`.
- Cross-agent decisions and operating rules go to \`memory/orchestrator\`.
- Repeatable procedures go to \`memory/orchestrator/SKILL_BACKLOG.md\`.
- Uncertain, sensitive, conflicting, low-confidence, or approval-needed items go to \`memory/orchestrator/REVIEW_QUEUE.md\`.

If new information contradicts existing memory, mark the older item as conflicting, superseded, or needs-review. Do not silently overwrite it."
    echo "  + MEMORY_POLICY.md post-task routing rule"
  else
    echo "  = MEMORY_POLICY.md post-task routing rule present"
  fi
}

upgrade_campaign_analyst_skills() {
  local workspace="$1"
  local file="$workspace/agents/campaign-analyst/SKILLS.md"

  if [ ! -f "$file" ]; then
    echo "  ! campaign-analyst SKILLS.md missing, skipped"
    return 0
  fi

  if grep -Eiq 'dashboard' "$file"; then
    echo "  = campaign-analyst dashboard skill present"
    return 0
  fi

  append_block_once \
    "$file" \
    "dashboard-skill-upgrade" \
    "## Dashboard Skill-Kandidat

- \`marketing-growth/dashboard-brief\`: Dashboard-Struktur, Metriken, Segmente und Entscheidungsfragen definieren."
  echo "  + campaign-analyst dashboard skill"
}

upgrade_orchestrator_reflector_links() {
  local workspace="$1"
  local subagents="$workspace/agents/orchestrator/SUBAGENTS.md"
  local workflows="$workspace/agents/orchestrator/WORKFLOWS.md"
  local skills="$workspace/agents/orchestrator/SKILLS.md"

  if ! grep -Fq "Memory Review / Reflektor" "$subagents" 2>/dev/null; then
    append_block_once \
      "$subagents" \
      "memory-review-reflector-agent" \
      "## Memory Review / Reflektor Agent

- Memory Review / Reflektor: Review Queue, Team Learnings, Skill Backlog, Memory-Konflikte, stale Claims und Skill-Builder-Briefs.

Setze Memory Review / Reflektor ein, wenn REVIEW_QUEUE.md, TEAM_LEARNINGS.md oder SKILL_BACKLOG.md kuratiert werden muessen, wenn widerspruechliche Memory auftaucht, wenn Learnings promoted werden sollen oder wenn wiederholte Muster in einen Skill Builder Brief uebersetzt werden sollen."
  fi

  if ! grep -Eq "Memory Review / Reflektor Workflow|Memory Review und Skill Builder" "$workflows" 2>/dev/null; then
    append_block_once \
      "$workflows" \
      "memory-review-reflector-agent" \
      "## Memory Review / Reflektor Workflow

1. Orchestrator definiert Scope: Profil, Kampagne, Zeitraum oder gesamtes Team.
2. Reflektor prueft Skills, Memory-Protokolle, Review Queue, Team Learnings, Skill Backlog und relevante Agent-Memory.
3. Reflektor bewertet Items nach Stabilitaet, Allgemeingueltigkeit, Faktenbasis, Sensibilitaet und Konflikten.
4. Reflektor liefert Promote-/Reject-/Needs-Source-/Conflict-Entscheidungen.
5. Wiederholte Muster werden als Skill Builder Briefs dokumentiert.
6. Orchestrator entscheidet ueber Promotions, Skill-Erstellung und naechste Reviews."
  fi

  if ! grep -Fq "marketing-growth/memory-review-triage" "$skills" 2>/dev/null; then
    append_block_once \
      "$skills" \
      "memory-review-reflector-agent" \
      "## Memory Review / Reflektor Skill-Kandidaten

- \`marketing-growth/memory-review-triage\`
- \`marketing-growth/memory-conflict-resolution\`
- \`marketing-growth/skill-backlog-prioritizer\`
- \`marketing-growth/skill-builder-brief\`
- \`marketing-growth/post-task-learning-review\`
- \`marketing-growth/memory-quality-audit\`
- \`marketing-growth/observability-to-learning\`"
  fi

  echo "  + orchestrator reflector links checked"
}

upgrade_memory_review_reflector() {
  local workspace="$1"

  mkdir -p "$workspace/agents"
  rm -rf "$workspace/agents/memory-review-reflector"
  cp -a "$TEMPLATE_DIR/agents/memory-review-reflector" "$workspace/agents/memory-review-reflector"
  echo "  + agents/memory-review-reflector"

  copy_missing_file \
    "$TEMPLATE_DIR/memory/agents/memory-review-reflector.md" \
    "$workspace/memory/agents/memory-review-reflector.md"

  upgrade_orchestrator_reflector_links "$workspace"
}

echo "Upgrading profile memory routing for profiles: ${PROFILES[*]}"

for profile in "${PROFILES[@]}"; do
  workspace="$DATA_ROOT/profile-workspaces/$profile"
  profile_dir="$DATA_ROOT/profiles/$profile"

  echo "== $profile =="
  if [ ! -d "$profile_dir" ]; then
    echo "Profile directory not found: $profile_dir" >&2
    exit 1
  fi
  if [ ! -d "$workspace" ]; then
    echo "Workspace not found: $workspace" >&2
    exit 1
  fi

  upgrade_memory_review_reflector "$workspace"
  upgrade_protocols "$workspace"
  upgrade_campaign_analyst_skills "$workspace"

  for agent in \
    orchestrator \
    content-writer \
    social-media-specialist \
    seo-web \
    creative-design \
    campaign-analyst \
    deep-research \
    memory-review-reflector
  do
    upgrade_agent_memory "$workspace" "$agent"
  done

  chown -R "${HERMES_UID:-10000}:${HERMES_GID:-10000}" "$workspace" 2>/dev/null || true
done

cat <<EOF

Done.

Recommended verification:
  for p in arnela denis arman testing; do
    bash docs/marketing-growth-team/deploy/audit-agent-docs.sh --profile "\$p" --report "/tmp/\$p-agent-audit.md"
  done
  grep -n "WARN:\\|FAIL:" /tmp/*-agent-audit.md
EOF
