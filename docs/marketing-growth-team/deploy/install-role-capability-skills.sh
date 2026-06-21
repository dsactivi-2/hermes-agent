#!/usr/bin/env bash
set -euo pipefail

DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
REPO_ROOT="${REPO_ROOT:-$(pwd)}"
PROFILES=()

usage() {
  cat <<EOF
Usage:
  $0 [profile...]

Install role-relevant built-in and optional skills into isolated Marketing &
Growth profile skill libraries. This does not assign all skills to the
Orchestrator; it makes the shared profile library available, while agent
SKILLS.md files route which role should use which skill.

Defaults:
  profiles: arnela denis arman testing
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

required_skills=(
  autonomous-ai-agents/hermes-agent
  autonomous-ai-agents/codex
  creative/design-md
  creative/popular-web-designs
  creative/excalidraw
  creative/humanizer
  creative/pretext
  creative/baoyu-infographic
  creative/comfyui
  productivity/notion
  productivity/google-workspace
  productivity/powerpoint
  github/codebase-inspection
  github/github-code-review
  github/github-pr-workflow
  research/arxiv
  research/blogwatcher
  research/llm-wiki
  social-media/xurl
  web-development/page-agent
  communication/one-three-one-rule
  research/domain-intel
  research/duckduckgo-search
  research/searxng-search
  research/parallel-cli
  research/osint-investigation
  finance/excel-author
  finance/pptx-author
)

find_skill_source() {
  local skill="$1"
  if [ -f "$REPO_ROOT/skills/$skill/SKILL.md" ]; then
    printf '%s\n' "$REPO_ROOT/skills/$skill"
  elif [ -f "$REPO_ROOT/optional-skills/$skill/SKILL.md" ]; then
    printf '%s\n' "$REPO_ROOT/optional-skills/$skill"
  else
    return 1
  fi
}

install_skill() {
  local profile="$1"
  local skill="$2"
  local src dest
  src="$(find_skill_source "$skill" || true)"
  if [ -z "$src" ]; then
    printf 'WARN %-34s missing source: %s\n' "$profile" "$skill"
    return 0
  fi
  dest="$DATA_ROOT/profiles/$profile/skills/$skill"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  cp -a "$src" "$dest"
  printf 'PASS %-34s installed %s\n' "$profile" "$skill"
}

for profile in "${PROFILES[@]}"; do
  profile_dir="$DATA_ROOT/profiles/$profile"
  if [ ! -d "$profile_dir" ]; then
    printf 'FAIL %-34s profile missing: %s\n' "$profile" "$profile_dir"
    continue
  fi
  mkdir -p "$profile_dir/skills"
  echo "== $profile =="
  for skill in "${required_skills[@]}"; do
    install_skill "$profile" "$skill"
  done
  chown -R "${HERMES_UID:-10000}:${HERMES_GID:-10000}" "$profile_dir/skills" 2>/dev/null || true
done

