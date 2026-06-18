#!/usr/bin/env bash
set -u

PROFILE="${1:-marketing-growth}"
DASHBOARD_PORT="${DASHBOARD_PORT:-9119}"
DATA_ROOT="${HERMES_DATA_ROOT:-$HOME/.hermes}"

section() {
  printf '\n== %s ==\n' "$1"
}

value() {
  printf '%-28s %s\n' "$1:" "$2"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

section "Host"
value "hostname" "$(hostname 2>/dev/null || printf unknown)"
value "user" "$(id -un 2>/dev/null || printf unknown)"
value "cwd" "$(pwd)"
if command_exists hostname; then
  value "detected host ips" "$(hostname -I 2>/dev/null | xargs || printf unknown)"
fi

section "SSH hints"
if [ -n "${SSH_CONNECTION:-}" ]; then
  value "ssh client ip" "$(printf '%s' "$SSH_CONNECTION" | awk '{print $1}')"
  value "ssh server ip" "$(printf '%s' "$SSH_CONNECTION" | awk '{print $3}')"
  value "ssh server port" "$(printf '%s' "$SSH_CONNECTION" | awk '{print $4}')"
else
  value "ssh connection" "not detected in environment"
fi
value "suggested local tunnel" "ssh -L ${DASHBOARD_PORT}:localhost:${DASHBOARD_PORT} $(id -un 2>/dev/null || printf root)@<SERVER_HOST>"

section "Docker"
if command_exists docker; then
  docker --version 2>/dev/null || true
  docker compose version 2>/dev/null || true
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
else
  value "docker" "not installed or not on PATH"
fi

section "Hermes containers"
if command_exists docker; then
  for container in hermes hermes-dashboard; do
    if docker inspect "$container" >/dev/null 2>&1; then
      value "$container status" "$(docker inspect -f '{{.State.Status}} started={{.State.StartedAt}} restart={{.HostConfig.RestartPolicy.Name}}' "$container" 2>/dev/null)"
    else
      value "$container status" "not found"
    fi
  done
fi

section "Dashboard port"
if command_exists ss; then
  ss -ltnp 2>/dev/null | awk -v port=":${DASHBOARD_PORT}" '$4 ~ port {print}' || true
elif command_exists netstat; then
  netstat -ltnp 2>/dev/null | awk -v port=":${DASHBOARD_PORT}" '$4 ~ port {print}' || true
else
  value "listener check" "ss/netstat not available"
fi

if command_exists curl; then
  status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:${DASHBOARD_PORT}/" 2>/dev/null || printf fail)"
  value "dashboard local http" "$status"
else
  value "curl" "not installed"
fi

section "Hermes profile"
if command_exists docker && docker inspect hermes >/dev/null 2>&1; then
  docker exec hermes hermes profile show "$PROFILE" 2>/dev/null || value "profile $PROFILE" "not found or hermes CLI unavailable"
  printf '\n'
  docker exec hermes hermes -p "$PROFILE" auth status nous 2>/dev/null || true
else
  value "profile check" "container hermes not available"
fi

section "Profile files"
for root in "$DATA_ROOT" /opt/data; do
  if [ -d "$root" ]; then
    value "data root" "$root"
    [ -f "$root/profiles/$PROFILE/config.yaml" ] && value "profile config" "$root/profiles/$PROFILE/config.yaml"
    [ -f "$root/profiles/$PROFILE/.env" ] && value "profile env" "$root/profiles/$PROFILE/.env"
  fi
done

section "Next data needed"
cat <<EOF
To create the exact local tunnel alias, you need these values on your local machine:
- SSH host name or IP you use in Termius
- SSH username, usually: $(id -un 2>/dev/null || printf root)
- SSH port, usually: 22
- Local dashboard port: ${DASHBOARD_PORT}

The tunnel must be created on your local computer or in Termius Port Forwarding.
A script running only on this server cannot open a local browser tunnel for you.
EOF

