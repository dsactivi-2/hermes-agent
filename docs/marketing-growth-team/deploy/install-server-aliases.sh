#!/usr/bin/env bash
set -euo pipefail

SHELL_RC="${1:-$HOME/.bashrc}"
MARKER_BEGIN="# >>> hermes isolated profile helpers >>>"
MARKER_END="# <<< hermes isolated profile helpers <<<"

tmp="$(mktemp)"
if [ -f "$SHELL_RC" ]; then
  awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
    $0 == begin { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$SHELL_RC" > "$tmp"
else
  : > "$tmp"
fi

cat >> "$tmp" <<'EOF'
# >>> hermes isolated profile helpers >>>
_hermes_profile_slug() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

Hermes() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: Hermes <profile-name> [chat|doctor|model|dashboard|status|...]" >&2
    docker exec -it hermes hermes profile list 2>/dev/null || true
    return 2
  fi

  local profile
  profile="$(_hermes_profile_slug "$1")"
  shift

  if [ "$#" -eq 0 ]; then
    docker exec -it hermes hermes -p "$profile" chat
    return
  fi

  case "$1" in
    dashboard|dash)
      local port_file="$HOME/.hermes/profiles/$profile/.dashboard-port"
      local port="9119"
      [ -f "$port_file" ] && port="$(cat "$port_file")"
      echo "Open via local SSH tunnel:"
      echo "  http://127.0.0.1:${port}/?profile=${profile}"
      echo
      echo "Termius Local Forwarding:"
      echo "  Local port:       ${port}"
      echo "  Destination host: 127.0.0.1"
      echo "  Destination port: ${port}"
      ;;
    status)
      docker exec -it hermes hermes profile show "$profile"
      ;;
    *)
      docker exec -it hermes hermes -p "$profile" "$@"
      ;;
  esac
}
# <<< hermes isolated profile helpers <<<
EOF

mv "$tmp" "$SHELL_RC"

cat <<EOF
Installed Hermes profile helper into:
  $SHELL_RC

Reload your shell:
  source "$SHELL_RC"

Examples:
  Hermes Arnela
  Hermes Denis model
  Hermes Arman doctor
  Hermes Testing dashboard
EOF

