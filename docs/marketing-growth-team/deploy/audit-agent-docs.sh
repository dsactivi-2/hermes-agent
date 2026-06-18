#!/usr/bin/env bash
set -euo pipefail

ROOT="docs/marketing-growth-team"
REPORT_FILE=""
WARN_ONLY=false

usage() {
  cat <<EOF
Usage:
  $0 [--root PATH] [--profile PROFILE] [--report FILE] [--warn-only]

Audits Marketing & Growth agent markdown files, system prompts, skill/tool
strategy, role-specific MCP/tool coverage, and memory-system bindings.

Examples:
  $0
  $0 --profile arnela
  $0 --root ~/.hermes/profile-workspaces/arnela
  $0 --report /tmp/marketing-growth-audit.md

Options:
  --root PATH       Blueprint or profile workspace root. Default: docs/marketing-growth-team
  --profile NAME    Audit ~/.hermes/profile-workspaces/NAME
  --report FILE     Also write the report to FILE
  --warn-only       Always exit 0, even when failures are found
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT="${2:-}"
      shift 2
      ;;
    --profile)
      ROOT="$HOME/.hermes/profile-workspaces/${2:-}"
      shift 2
      ;;
    --report)
      REPORT_FILE="${2:-}"
      shift 2
      ;;
    --warn-only)
      WARN_ONLY=true
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

if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then
  echo "Root not found: $ROOT" >&2
  exit 1
fi

TMP_REPORT="$(mktemp)"
FAILS=0
WARNS=0
PASSES=0

cleanup() {
  rm -f "$TMP_REPORT"
}
trap cleanup EXIT

emit() {
  printf '%s\n' "$*" | tee -a "$TMP_REPORT"
}

pass() {
  PASSES=$((PASSES + 1))
  emit "PASS: $*"
}

warn() {
  WARNS=$((WARNS + 1))
  emit "WARN: $*"
}

fail() {
  FAILS=$((FAILS + 1))
  emit "FAIL: $*"
}

contains() {
  local file="$1"
  local pattern="$2"
  grep -Eiq "$pattern" "$file"
}

line_count() {
  wc -l < "$1" | tr -d ' '
}

required_agent_files=(ROLE.md SYSTEM.md SKILLS.md TOOLS.md MEMORY.md WORKFLOWS.md SUBAGENTS.md)
expected_agents=(
  orchestrator
  content-writer
  social-media-specialist
  seo-web
  creative-design
  campaign-analyst
  deep-research
  memory-review-reflector
)

declare -A expected_mcp
expected_mcp[orchestrator]="marketing_fs notion analytics social_posting github"
expected_mcp[content-writer]="notion marketing_fs browser analytics"
expected_mcp[social-media-specialist]="social_posting notion analytics browser"
expected_mcp[seo-web]="browser analytics github marketing_fs notion"
expected_mcp[creative-design]="marketing_fs notion browser"
expected_mcp[campaign-analyst]="analytics social_posting notion marketing_fs"
expected_mcp[deep-research]="marketing_fs browser notion analytics"
expected_mcp[memory-review-reflector]="marketing_fs notion analytics github"

declare -A expected_skill_terms
expected_skill_terms[orchestrator]="campaign delegation brand postmortem"
expected_skill_terms[content-writer]="brand linkedin landing email case"
expected_skill_terms[social-media-specialist]="linkedin calendar scheduling hashtag"
expected_skill_terms[seo-web]="seo landing tracking serp"
expected_skill_terms[creative-design]="creative image carousel presentation"
expected_skill_terms[campaign-analyst]="kpi utm dashboard experiment"
expected_skill_terms[deep-research]="research source competitor persona trend evidence"
expected_skill_terms[memory-review-reflector]="memory review skill backlog conflict"

emit "# Marketing & Growth Agent Audit"
emit ""
emit "Root: $ROOT"
emit "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
emit ""

if [ ! -d "$ROOT/agents" ]; then
  fail "agents directory missing: $ROOT/agents"
else
  pass "agents directory exists"
fi

for agent in "${expected_agents[@]}"; do
  agent_dir="$ROOT/agents/$agent"
  emit ""
  emit "## Agent: $agent"

  if [ ! -d "$agent_dir" ]; then
    fail "$agent directory missing"
    continue
  fi
  pass "$agent directory exists"

  for file in "${required_agent_files[@]}"; do
    path="$agent_dir/$file"
    if [ ! -f "$path" ]; then
      fail "$agent/$file missing"
      continue
    fi

    lines="$(line_count "$path")"
    if [ "$lines" -lt 5 ]; then
      warn "$agent/$file is very short ($lines lines)"
    else
      pass "$agent/$file exists ($lines lines)"
    fi
  done

  system_file="$agent_dir/SYSTEM.md"
  skills_file="$agent_dir/SKILLS.md"
  tools_file="$agent_dir/TOOLS.md"
  memory_file="$agent_dir/MEMORY.md"

  if [ -f "$system_file" ]; then
    contains "$system_file" 'Bevor.*direkt.*Tool|zuerst.*Hermes Skill|Hermes Skill.*erstellt' \
      && pass "$agent SYSTEM.md enforces Skill-first before direct tools" \
      || fail "$agent SYSTEM.md missing explicit Skill-first-before-direct-tool rule"

    contains "$system_file" 'MCP Server|MCP-Server|MCP' \
      && pass "$agent SYSTEM.md references MCP usage" \
      || fail "$agent SYSTEM.md missing MCP usage rule"

    contains "$system_file" 'Nur wenn weder Skill noch MCP|weder Skill noch MCP|klassische Tools|direkte Tools' \
      && pass "$agent SYSTEM.md restricts direct/classic tools" \
      || fail "$agent SYSTEM.md missing direct-tool fallback rule"

    contains "$system_file" 'Skill.*erstell|Skill.*verbesser|erstell.*Skill|verbesser.*Skill|create.*Skill|improve.*Skill' \
      && pass "$agent SYSTEM.md includes post-task Skill creation/improvement" \
      || fail "$agent SYSTEM.md missing post-task Skill improvement rule"
  fi

  if [ -f "$skills_file" ]; then
    contains "$skills_file" 'marketing-growth/' \
      && pass "$agent SKILLS.md defines marketing-growth Skill candidates" \
      || warn "$agent SKILLS.md has no marketing-growth Skill candidate"

    for term in ${expected_skill_terms[$agent]}; do
      contains "$skills_file" "$term" \
        && pass "$agent SKILLS.md contains expected skill term: $term" \
        || warn "$agent SKILLS.md may miss expected skill term: $term"
    done

    if contains "$skills_file" 'alle Skills|all skills|every skill|alle verfuegbaren Skills|alle verfügbaren Skills'; then
      fail "$agent SKILLS.md suggests broad all-skills access"
    else
      pass "$agent SKILLS.md does not grant all skills broadly"
    fi
  fi

  if [ -f "$tools_file" ]; then
    contains "$tools_file" 'Entscheidungsregel|Skill zuerst|Skill suchen' \
      && pass "$agent TOOLS.md has tool decision rule" \
      || fail "$agent TOOLS.md missing tool decision rule"

    contains "$tools_file" 'Bevorzugte MCP-Server|MCP-Server' \
      && pass "$agent TOOLS.md has preferred MCP section" \
      || fail "$agent TOOLS.md missing preferred MCP section"

    contains "$tools_file" 'Direkte Tools' \
      && pass "$agent TOOLS.md has direct tools boundary" \
      || fail "$agent TOOLS.md missing direct tools boundary"

    for mcp in ${expected_mcp[$agent]}; do
      contains "$tools_file" "$mcp" \
        && pass "$agent TOOLS.md includes expected MCP/tool: $mcp" \
        || warn "$agent TOOLS.md may miss expected MCP/tool: $mcp"
    done

    if contains "$tools_file" 'alle Tools|all tools|every tool|alle Werkzeuge|alle verfügbaren Tools|alle verfuegbaren Tools'; then
      fail "$agent TOOLS.md suggests broad all-tools access"
    else
      pass "$agent TOOLS.md does not grant all tools broadly"
    fi
  fi

  if [ -f "$memory_file" ]; then
    contains "$memory_file" 'Kurzfristiges Memory|Long-term|Langfristiges Memory|Curated Memory System|Memory' \
      && pass "$agent MEMORY.md defines memory usage" \
      || warn "$agent MEMORY.md has weak memory guidance"

    if [ -d "$ROOT/memory" ]; then
      contains "$memory_file" 'Curated Memory System|memory/shared|REVIEW_QUEUE|SKILL_BACKLOG' \
        && pass "$agent MEMORY.md is bound to curated memory system" \
        || warn "$agent MEMORY.md is not yet bound to curated memory system; run install-memory-system.sh for deployed profiles"

      contains "$memory_file" 'Post-Task Memory Routing|Stabilitaet|Allgemeingueltigkeit|Faktenbasis|Sensibilitaet|Konflikte' \
        && pass "$agent MEMORY.md includes post-task memory routing checks" \
        || fail "$agent MEMORY.md missing post-task memory routing checks"

      contains "$memory_file" 'memory/shared' \
        && contains "$memory_file" 'memory/agents|memory/agents/' \
        && contains "$memory_file" 'memory/orchestrator' \
        && contains "$memory_file" 'SKILL_BACKLOG' \
        && contains "$memory_file" 'REVIEW_QUEUE' \
        && pass "$agent MEMORY.md routes learnings to all required memory destinations" \
        || fail "$agent MEMORY.md missing one or more memory routing destinations"
    fi
  fi
done

emit ""
emit "## Cross-Agent Checks"

if [ -d "$ROOT/agents" ]; then
  tools_count="$(find "$ROOT/agents" -mindepth 2 -maxdepth 2 -name TOOLS.md -print | wc -l | tr -d ' ')"
  skills_count="$(find "$ROOT/agents" -mindepth 2 -maxdepth 2 -name SKILLS.md -print | wc -l | tr -d ' ')"

  if [ "$tools_count" -gt 1 ]; then
    unique_tools="$(find "$ROOT/agents" -mindepth 2 -maxdepth 2 -name TOOLS.md -print0 | xargs -0 sha256sum | awk '{print $1}' | sort -u | wc -l | tr -d ' ')"
    if [ "$unique_tools" -lt "$tools_count" ]; then
      warn "Some TOOLS.md files are identical ($unique_tools unique / $tools_count files)"
    else
      pass "TOOLS.md files are role-specific ($unique_tools unique / $tools_count files)"
    fi
  fi

  if [ "$skills_count" -gt 1 ]; then
    unique_skills="$(find "$ROOT/agents" -mindepth 2 -maxdepth 2 -name SKILLS.md -print0 | xargs -0 sha256sum | awk '{print $1}' | sort -u | wc -l | tr -d ' ')"
    if [ "$unique_skills" -lt "$skills_count" ]; then
      warn "Some SKILLS.md files are identical ($unique_skills unique / $skills_count files)"
    else
      pass "SKILLS.md files are role-specific ($unique_skills unique / $skills_count files)"
    fi
  fi
fi

emit ""
emit "## Shared Memory Checks"

if [ -d "$ROOT/memory" ]; then
  memory_files=(
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
    memory/protocols/MEMORY_POLICY.md
    memory/protocols/SELF_LEARNING_LOOP.md
    memory/protocols/MEMORY_REVIEW_CHECKLIST.md
    memory/protocols/SKILL_BUILDER_WORKFLOW.md
  )
  for file in "${memory_files[@]}"; do
    [ -f "$ROOT/$file" ] && pass "$file exists" || fail "$file missing"
  done

  if [ -f "$ROOT/memory/protocols/SELF_LEARNING_LOOP.md" ]; then
    contains "$ROOT/memory/protocols/SELF_LEARNING_LOOP.md" 'Post-Task Memory Routing' \
      && pass "SELF_LEARNING_LOOP.md defines Post-Task Memory Routing" \
      || fail "SELF_LEARNING_LOOP.md missing Post-Task Memory Routing"
  fi

  if [ -f "$ROOT/memory/protocols/MEMORY_POLICY.md" ]; then
    contains "$ROOT/memory/protocols/MEMORY_POLICY.md" 'Post-Task Routing Rule' \
      && pass "MEMORY_POLICY.md defines Post-Task Routing Rule" \
      || fail "MEMORY_POLICY.md missing Post-Task Routing Rule"
  fi

  if [ -f "$ROOT/memory/protocols/SKILL_BUILDER_WORKFLOW.md" ]; then
    contains "$ROOT/memory/protocols/SKILL_BUILDER_WORKFLOW.md" 'Skill Builder Workflow' \
      && pass "SKILL_BUILDER_WORKFLOW.md defines Skill Builder Workflow" \
      || fail "SKILL_BUILDER_WORKFLOW.md missing Skill Builder Workflow"
  fi
else
  warn "memory directory missing; install-memory-system.sh has not been applied to this root"
fi

emit ""
emit "## Config Checks"

if [ -f "$ROOT/config/config.yaml" ]; then
  contains "$ROOT/config/config.yaml" 'skills:' && pass "config.yaml contains skills section" || warn "config.yaml missing skills section"
  contains "$ROOT/config/config.yaml" 'mcp_servers:' && pass "config.yaml contains mcp_servers section" || warn "config.yaml missing mcp_servers section"
  contains "$ROOT/config/config.yaml" 'memory:' && pass "config.yaml contains memory section" || warn "config.yaml missing memory section"
else
  warn "config/config.yaml missing in this root; normal for deployed profile workspaces"
fi

emit ""
emit "## Summary"
emit ""
emit "- Passes: $PASSES"
emit "- Warnings: $WARNS"
emit "- Failures: $FAILS"

if [ -n "$REPORT_FILE" ]; then
  mkdir -p "$(dirname "$REPORT_FILE")"
  cp "$TMP_REPORT" "$REPORT_FILE"
  emit "- Report written to: $REPORT_FILE"
fi

if [ "$FAILS" -gt 0 ] && [ "$WARN_ONLY" = false ]; then
  exit 1
fi

exit 0
