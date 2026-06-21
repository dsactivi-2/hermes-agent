#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="${TEMPLATE_DIR:-docs/marketing-growth-team}"
DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"
PROFILES=()

usage() {
  cat <<EOF
Usage:
  $0 [profile...]

Sync the current Marketing & Growth role documents into existing isolated
profile workspace copies. This updates agent ROLE/SYSTEM/SKILLS/TOOLS/MEMORY/
WORKFLOWS/SUBAGENTS markdown, ROLE_CAPABILITY_MATRIX.md, and profile config.
It does not overwrite profile .env files or chat/session data.

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

if [ ! -d "$TEMPLATE_DIR/agents" ]; then
  echo "Template agents not found: $TEMPLATE_DIR/agents" >&2
  exit 1
fi

for profile in "${PROFILES[@]}"; do
  profile_dir="$DATA_ROOT/profiles/$profile"
  workspace="$DATA_ROOT/profile-workspaces/$profile"
  container_workspace="/opt/data/profile-workspaces/$profile"

  echo "== $profile =="
  if [ ! -d "$profile_dir" ]; then
    echo "FAIL profile missing: $profile_dir"
    continue
  fi
  if [ ! -d "$workspace" ]; then
    echo "FAIL workspace missing: $workspace"
    continue
  fi

  mkdir -p "$workspace/agents" "$workspace/config"
  cp -a "$TEMPLATE_DIR/agents/." "$workspace/agents/"
  cp -a "$TEMPLATE_DIR/memory/." "$workspace/memory/"
  cp "$TEMPLATE_DIR/ROLE_CAPABILITY_MATRIX.md" "$workspace/ROLE_CAPABILITY_MATRIX.md"
  cp "$TEMPLATE_DIR/config/.env.example" "$workspace/config/.env.example"

  sed \
    -e "s#docs/marketing-growth-team#$container_workspace#g" \
    -e "s#/opt/data/marketing-growth-team#$container_workspace#g" \
    -e "s#marketing-growth#$profile#g" \
    "$TEMPLATE_DIR/config/config.yaml" > "$profile_dir/config.yaml"

  chown -R "${HERMES_UID:-10000}:${HERMES_GID:-10000}" "$workspace" "$profile_dir/config.yaml" 2>/dev/null || true
  echo "PASS synced role docs, matrix, memory templates, and profile config"
done

