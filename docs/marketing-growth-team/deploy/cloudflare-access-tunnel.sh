#!/usr/bin/env bash
set -u

DOMAIN=""
TUNNEL_NAME="${TUNNEL_NAME:-hermes-marketing-growth}"
TUNNEL_ID=""
CREDENTIALS_FILE=""
CONFIG_PATH="${CONFIG_PATH:-/etc/cloudflared/config.yml}"
WRITE_CONFIG=false
ROUTE_DNS=false
INSTALL_SERVICE=false

usage() {
  cat <<EOF
Usage:
  $0 --domain DOMAIN [options]

Prepare Cloudflare Tunnel + Cloudflare Access for the isolated Hermes
Marketing & Growth dashboards.

Default mode is read-only: it prints dashboard checks, hostnames, commands,
and the exact Cloudflare Access setup checklist.

Options:
  --domain DOMAIN              Base domain, e.g. example.com
  --tunnel-name NAME           Cloudflare tunnel name. Default: hermes-marketing-growth
  --tunnel-id UUID             Tunnel UUID for writing config.yml
  --credentials-file PATH      cloudflared tunnel credentials JSON
  --config-path PATH           Config path. Default: /etc/cloudflared/config.yml
  --write-config               Write cloudflared config.yml
  --route-dns                  Run cloudflared tunnel route dns for all profiles
  --install-service            Run cloudflared service install and start service
  -h, --help                   Show help

Examples:
  $0 --domain example.com
  $0 --domain example.com --route-dns
  $0 --domain example.com --tunnel-id UUID --credentials-file /root/.cloudflared/UUID.json --write-config
  $0 --domain example.com --install-service
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --domain)
      DOMAIN="${2:-}"
      shift 2
      ;;
    --tunnel-name)
      TUNNEL_NAME="${2:-}"
      shift 2
      ;;
    --tunnel-id)
      TUNNEL_ID="${2:-}"
      shift 2
      ;;
    --credentials-file)
      CREDENTIALS_FILE="${2:-}"
      shift 2
      ;;
    --config-path)
      CONFIG_PATH="${2:-}"
      shift 2
      ;;
    --write-config)
      WRITE_CONFIG=true
      shift
      ;;
    --route-dns)
      ROUTE_DNS=true
      shift
      ;;
    --install-service)
      INSTALL_SERVICE=true
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

if [ -z "$DOMAIN" ]; then
  echo "Missing required --domain DOMAIN" >&2
  usage >&2
  exit 2
fi

case "$DOMAIN" in
  http://*|https://*|*/*)
    echo "Use only the base domain, not a URL: $DOMAIN" >&2
    exit 2
    ;;
esac

profiles=(arnela denis arman testing)

section() {
  printf '\n== %s ==\n' "$1"
}

value() {
  printf '%-34s %s\n' "$1:" "$2"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

dashboard_port() {
  case "$1" in
    arnela) printf '9120' ;;
    denis) printf '9121' ;;
    arman) printf '9122' ;;
    testing) printf '9123' ;;
    *) printf '' ;;
  esac
}

hostname_for_profile() {
  printf '%s.%s' "$1" "$DOMAIN"
}

http_code() {
  local url="$1"
  local code
  if command_exists curl; then
    if code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 4 "$url" 2>/dev/null)"; then
      printf '%s' "$code"
    else
      printf 'fail'
    fi
  else
    printf 'curl-missing'
  fi
}

listener_line_for_port() {
  local port="$1"
  if command_exists ss; then
    ss -ltnp 2>/dev/null | awk -v port=":${port}" '$4 ~ port {print}'
  elif command_exists netstat; then
    netstat -ltnp 2>/dev/null | awk -v port=":${port}" '$4 ~ port {print}'
  fi
}

write_config() {
  if [ -z "$TUNNEL_ID" ]; then
    echo "Missing --tunnel-id UUID for --write-config" >&2
    exit 2
  fi
  if [ -z "$CREDENTIALS_FILE" ]; then
    CREDENTIALS_FILE="/root/.cloudflared/${TUNNEL_ID}.json"
  fi
  if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "Credentials file not found: $CREDENTIALS_FILE" >&2
    echo "Create it first with: cloudflared tunnel create $TUNNEL_NAME" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$CONFIG_PATH")"
  {
    printf 'tunnel: %s\n' "$TUNNEL_ID"
    printf 'credentials-file: %s\n' "$CREDENTIALS_FILE"
    printf '\n'
    printf 'ingress:\n'
    for profile in "${profiles[@]}"; do
      printf '  - hostname: %s\n' "$(hostname_for_profile "$profile")"
      printf '    service: http://127.0.0.1:%s\n' "$(dashboard_port "$profile")"
    done
    printf '  - service: http_status:404\n'
  } > "$CONFIG_PATH"
  chmod 600 "$CONFIG_PATH" 2>/dev/null || true
  value "wrote config" "$CONFIG_PATH"
}

section "Cloudflare Access Target"
value "base domain" "$DOMAIN"
value "tunnel name" "$TUNNEL_NAME"
value "config path" "$CONFIG_PATH"
value "mode" "Cloudflare Tunnel -> 127.0.0.1 dashboard ports"

section "Public Dashboard Hostnames"
printf '%-10s %-34s %-24s %-10s\n' "PROFILE" "HOSTNAME" "ORIGIN" "LOCAL"
for profile in "${profiles[@]}"; do
  port="$(dashboard_port "$profile")"
  host="$(hostname_for_profile "$profile")"
  printf '%-10s %-34s %-24s %-10s\n' \
    "$profile" "$host" "http://127.0.0.1:${port}" "$(http_code "http://127.0.0.1:${port}/")"
done

section "Local Listeners"
for profile in "${profiles[@]}"; do
  port="$(dashboard_port "$profile")"
  line="$(listener_line_for_port "$port" | head -1)"
  value "$profile :$port" "${line:-not listening}"
done

section "cloudflared"
if command_exists cloudflared; then
  cloudflared --version 2>/dev/null || true
  value "tunnel list" "below, if cloudflared is authenticated"
  cloudflared tunnel list 2>/dev/null || true
else
  value "cloudflared" "not installed"
  cat <<'EOF'
Install cloudflared first. On Debian/Ubuntu amd64, the common quick path is:

  curl -L -o /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  sudo dpkg -i /tmp/cloudflared.deb

For other CPU architectures, use the matching package from Cloudflare's
cloudflared installation docs.
EOF
fi

section "Required Cloudflare Commands"
cat <<EOF
# 1. Authenticate this server with your Cloudflare account:
cloudflared tunnel login

# 2. Create the tunnel once:
cloudflared tunnel create ${TUNNEL_NAME}

# 3. Find the tunnel UUID:
cloudflared tunnel list

# 4. Write /etc/cloudflared/config.yml with this helper:
sudo bash docs/marketing-growth-team/deploy/cloudflare-access-tunnel.sh \\
  --domain ${DOMAIN} \\
  --tunnel-name ${TUNNEL_NAME} \\
  --tunnel-id TUNNEL_UUID \\
  --credentials-file /root/.cloudflared/TUNNEL_UUID.json \\
  --write-config

# 5. Create DNS routes for all dashboard hostnames:
sudo bash docs/marketing-growth-team/deploy/cloudflare-access-tunnel.sh \\
  --domain ${DOMAIN} \\
  --tunnel-name ${TUNNEL_NAME} \\
  --route-dns

# 6. Install/start cloudflared as a service:
sudo bash docs/marketing-growth-team/deploy/cloudflare-access-tunnel.sh \\
  --domain ${DOMAIN} \\
  --install-service
EOF

section "Cloudflare Access Checklist"
cat <<EOF
In Cloudflare Zero Trust:

1. Access -> Applications -> Add an application -> Self-hosted.
2. Create one application per profile, or one shared application if everyone
   should have the same access policy.
3. Public hostnames:
   - https://arnela.${DOMAIN}
   - https://denis.${DOMAIN}
   - https://arman.${DOMAIN}
   - https://testing.${DOMAIN}
4. Policy action: Allow.
5. Include rule: Emails, Email domain, GitHub org, Google group, or another
   identity rule that matches your team.
6. Require 2FA at the identity provider if possible.

Do not enter API_SERVER_KEY here. Cloudflare Access is for the browser login
in front of the dashboard. Hermes API keys remain in the Hermes profile .env.
EOF

section "Desktop Compatibility Note"
cat <<EOF
Cloudflare Access is excellent for browser dashboard access.

Hermes Desktop may not complete Cloudflare's browser login flow reliably. If
Desktop cannot connect through Access, keep using the SSH tunnel for Desktop:

  Remote URL: http://127.0.0.1:9122

and use Cloudflare Access for browser dashboard access:

  https://arman.${DOMAIN}
EOF

if [ "$WRITE_CONFIG" = true ]; then
  section "Writing cloudflared Config"
  write_config
fi

if [ "$ROUTE_DNS" = true ]; then
  section "Routing Cloudflare DNS"
  if ! command_exists cloudflared; then
    echo "cloudflared not installed" >&2
    exit 1
  fi
  for profile in "${profiles[@]}"; do
    host="$(hostname_for_profile "$profile")"
    value "route dns" "$host"
    cloudflared tunnel route dns "$TUNNEL_NAME" "$host"
  done
fi

if [ "$INSTALL_SERVICE" = true ]; then
  section "Installing cloudflared Service"
  if ! command_exists cloudflared; then
    echo "cloudflared not installed" >&2
    exit 1
  fi
  if [ ! -f "$CONFIG_PATH" ]; then
    echo "Config not found: $CONFIG_PATH" >&2
    echo "Run --write-config first." >&2
    exit 1
  fi
  cloudflared service install
  if command_exists systemctl; then
    systemctl enable --now cloudflared
    systemctl --no-pager --full status cloudflared || true
  fi
fi
