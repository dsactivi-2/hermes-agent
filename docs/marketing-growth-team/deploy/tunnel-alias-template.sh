#!/usr/bin/env bash
set -euo pipefail

SERVER_HOST="${1:-}"
SSH_USER="${2:-root}"
SSH_PORT="${3:-22}"
LOCAL_PORT="${4:-9119}"
REMOTE_PORT="${5:-9119}"
ALIAS_NAME="${ALIAS_NAME:-hermesdash}"

if [ -z "$SERVER_HOST" ]; then
  cat >&2 <<EOF
Usage:
  $0 <server-host-or-ip> [ssh-user] [ssh-port] [local-port] [remote-port]

Example:
  $0 203.0.113.10 root 22 9119 9119

This script is for your LOCAL machine, not the server.
It prints an alias/function you can add to ~/.bashrc or ~/.zshrc.
EOF
  exit 2
fi

cat <<EOF
# Add this to your LOCAL shell config, for example ~/.bashrc or ~/.zshrc:

${ALIAS_NAME}() {
  ssh -N -L ${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT} -p ${SSH_PORT} ${SSH_USER}@${SERVER_HOST}
}

# Then reload your shell:
#   source ~/.bashrc
# or:
#   source ~/.zshrc

# Start the tunnel:
#   ${ALIAS_NAME}

# Open:
#   http://127.0.0.1:${LOCAL_PORT}/?profile=marketing-growth
EOF

