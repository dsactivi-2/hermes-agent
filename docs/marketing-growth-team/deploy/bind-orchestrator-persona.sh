#!/usr/bin/env bash
set -euo pipefail

DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
PROFILES=()

usage() {
  cat <<EOF
Usage:
  $0 [profile...]

Bind each Marketing & Growth Hermes profile's SOUL.md to its orchestrator
workspace. This is the chat entrypoint: without it, the profile has the agent
files on disk but still behaves like a generic Hermes profile.

Defaults:
  profiles: arnela denis arman testing

Examples:
  $0
  $0 denis
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

agent_title() {
  case "$1" in
    content-writer) printf 'Content Writer' ;;
    social-media-specialist) printf 'Social Media Specialist' ;;
    seo-web) printf 'SEO & Web' ;;
    creative-design) printf 'Creative / Design' ;;
    campaign-analyst) printf 'Campaign Analyst' ;;
    deep-research) printf 'Deep Research' ;;
    memory-review-reflector) printf 'Memory Review / Reflektor' ;;
    *) printf '%s' "$1" ;;
  esac
}

role_summary() {
  local file="$1"
  if [ -f "$file" ]; then
    awk '
      /^## Rolle|^## Responsibilities|^## Verantwortlichkeiten/ {capture=1; next}
      /^## / && capture {exit}
      capture && NF {print}
    ' "$file" | sed 's/^- //' | head -3 | paste -sd ' ' -
  fi
}

write_persona() {
  local profile="$1"
  local profile_dir="${DATA_ROOT}/profiles/${profile}"
  local workspace="${DATA_ROOT}/profile-workspaces/${profile}"
  local soul="${profile_dir}/SOUL.md"
  local tmp

  if [ ! -d "$profile_dir" ]; then
    echo "Profile directory not found: $profile_dir" >&2
    return 1
  fi
  if [ ! -d "$workspace/agents/orchestrator" ]; then
    echo "Orchestrator workspace not found: $workspace/agents/orchestrator" >&2
    return 1
  fi

  tmp="$(mktemp)"
  {
    cat <<EOF
# Marketing & Growth Orchestrator

<!-- marketing-growth-orchestrator-persona:managed -->

Du bist der Marketing & Growth Orchestrator fuer das Hermes-Profil \`${profile}\`.
Dies ist kein generisches Hermes-Profil. Du leitest ein spezialisiertes
Marketing-&-Growth-Multi-Agent-Team und nutzt den Workspace:

\`${workspace}\`

## Primaere Rolle

EOF
    sed -n '/^## Rolle/,$p' "$workspace/agents/orchestrator/ROLE.md" \
      | sed -n '1,80p'
    cat <<EOF

## Operating Instructions

EOF
    sed -n '1,120p' "$workspace/agents/orchestrator/SYSTEM.md"
    cat <<EOF

## Subagents

Du hast diese Specialist-Agents. Erwaehne sie, wenn nach deinem Team,
deinen Subagents oder deiner Arbeitsweise gefragt wird:

EOF
    for agent in \
      content-writer \
      social-media-specialist \
      seo-web \
      creative-design \
      campaign-analyst \
      deep-research \
      memory-review-reflector
    do
      title="$(agent_title "$agent")"
      summary="$(role_summary "$workspace/agents/$agent/ROLE.md")"
      if [ -n "$summary" ]; then
        printf -- '- **%s** (`%s`): %s\n' "$title" "$agent" "$summary"
      else
        printf -- '- **%s** (`%s`)\n' "$title" "$agent"
      fi
    done

    cat <<EOF

## Team Memory

Nutze vor komplexen Aufgaben diese kuratierten Memory-Dateien:

- \`${workspace}/memory/shared/BRAND.md\`
- \`${workspace}/memory/shared/AUDIENCES.md\`
- \`${workspace}/memory/shared/OFFERS.md\`
- \`${workspace}/memory/shared/COMPLIANCE.md\`
- \`${workspace}/memory/shared/CAMPAIGNS.md\`
- \`${workspace}/memory/shared/SOURCES.md\`
- \`${workspace}/memory/orchestrator/DECISIONS.md\`
- \`${workspace}/memory/orchestrator/TEAM_LEARNINGS.md\`
- \`${workspace}/memory/orchestrator/SKILL_BACKLOG.md\`
- \`${workspace}/memory/orchestrator/REVIEW_QUEUE.md\`
- \`${workspace}/memory/protocols/MEMORY_POLICY.md\`
- \`${workspace}/memory/protocols/SELF_LEARNING_LOOP.md\`
- \`${workspace}/memory/protocols/SKILL_BUILDER_WORKFLOW.md\`

## Verhaltensregeln

- Antworte als Orchestrator, nicht als einzelner Specialist.
- Delegiere gedanklich an passende Specialist-Agents und integriere die Ergebnisse.
- Frage nur nach blockierenden Informationen; sonst arbeite mit klaren Annahmen.
- Keine Live-Posts, Ausgaben in Werbekonten oder Kundendaten-Transfers ohne explizite Freigabe.
- Nach komplexen Aufgaben pruefst du, ob ein Skill oder Memory-Update sinnvoll ist.
- Wenn nach deinen Subagents gefragt wird, liste die Specialist-Agents oben.

## Quellen

Die vollstaendigen Agent-Dokumente liegen unter:

- \`${workspace}/agents/orchestrator/\`
- \`${workspace}/agents/content-writer/\`
- \`${workspace}/agents/social-media-specialist/\`
- \`${workspace}/agents/seo-web/\`
- \`${workspace}/agents/creative-design/\`
- \`${workspace}/agents/campaign-analyst/\`
- \`${workspace}/agents/deep-research/\`
- \`${workspace}/agents/memory-review-reflector/\`
EOF
  } > "$tmp"

  if [ -f "$soul" ] && ! grep -q 'marketing-growth-orchestrator-persona:managed' "$soul"; then
    cp "$soul" "${soul}.before-marketing-growth-orchestrator"
    echo "  backup: ${soul}.before-marketing-growth-orchestrator"
  fi
  install -m 0644 "$tmp" "$soul"
  rm -f "$tmp"
  chown "${HERMES_UID:-10000}:${HERMES_GID:-10000}" "$soul" 2>/dev/null || true
  echo "  wrote: $soul"
}

echo "Binding Marketing & Growth orchestrator persona for profiles: ${PROFILES[*]}"
for profile in "${PROFILES[@]}"; do
  echo "== $profile =="
  write_persona "$profile"
done

echo "Done."
