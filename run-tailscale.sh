#!/usr/bin/env bash
# Tailnet access to DocSpring's Render private services (Plausible's
# ClickHouse). Settings are managed by convox_racks_terraform/render.
#
# No subnet routes: Render moves private services between IPs anywhere in
# 10.0.0.0/8. Instead this node forwards TCP ports to Render service *names*
# (TCP_FORWARDS), resolved by Render's DNS on every connection. In userspace
# networking mode, tailnet connections to this node's ports are delivered to
# localhost, where socat listens.
#
# TAILSCALE_AUTHKEY is a Tailscale OAuth client secret
# (convox_racks_terraform/tailscale, OAuth client "render_router"), used only
# when there is no saved login on the persistent disk (/var/lib/tailscale).
set -euo pipefail

: "${TAILSCALE_AUTHKEY:?TAILSCALE_AUTHKEY (Tailscale OAuth client secret) is required}"
: "${TCP_FORWARDS:?TCP_FORWARDS is required, e.g. '8123=plausible-events-db:8123'}"
TAILSCALE_TAGS="${TAILSCALE_TAGS:-tag:render-subnet-router}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-${RENDER_SERVICE_NAME}}"

/render/tailscaled --tun=userspace-networking &

backend_state() {
  /render/tailscale status --json 2>/dev/null | jq -r '.BackendState // "NoState"'
}

# Wait for tailscaled to load its saved state from the persistent disk
state=NoState
for _ in $(seq 1 60); do
  state="$(backend_state)"
  case "$state" in NoState | Starting | "") sleep 1 ;; *) break ;; esac
done

if [ "$state" = Running ]; then
  # Already logged in from saved state: keep the same device and tailnet IP.
  # Tagged devices have no key expiry, so no re-login is needed.
  /render/tailscale set --hostname="${TAILSCALE_HOSTNAME}"
else
  # First boot or lost state: log in with the OAuth client
  echo "Tailscale state is '${state}'; logging in with the OAuth client"
  attempt=0
  until /render/tailscale up \
    --authkey="${TAILSCALE_AUTHKEY}?ephemeral=false&preauthorized=true" \
    --advertise-tags="${TAILSCALE_TAGS}" \
    --hostname="${TAILSCALE_HOSTNAME}" \
    --reset; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 30 ]; then
      echo "tailscale up failed after $attempt attempts; exiting so Render restarts the service" >&2
      exit 1
    fi
    sleep 2
  done
fi
echo "Tailscale is up as ${TAILSCALE_HOSTNAME} ($(/render/tailscale ip -4))"

# Each forward: <listen port>=<render service name>:<port>. socat resolves the
# target name on every accepted connection, so moved services are followed.
for forward in ${TCP_FORWARDS}; do
  port="${forward%%=*}"
  target="${forward#*=}"
  socat "TCP-LISTEN:${port},bind=127.0.0.1,fork,reuseaddr" "TCP:${target}" &
  echo "Forwarding tailnet port ${port} -> ${target}"
done

# If tailscaled or any forwarder exits, exit so Render restarts the service
wait -n
echo "A tailscaled/socat process exited; exiting so Render restarts the service" >&2
exit 1
