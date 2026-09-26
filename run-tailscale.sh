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
# (convox_racks_terraform/tailscale, OAuth client "render_router"). Each boot
# mints a fresh pre-authorised login for the same device.
set -euo pipefail

: "${TAILSCALE_AUTHKEY:?TAILSCALE_AUTHKEY (Tailscale OAuth client secret) is required}"
: "${TCP_FORWARDS:?TCP_FORWARDS is required, e.g. '8123=plausible-events-db:8123'}"
TAILSCALE_TAGS="${TAILSCALE_TAGS:-tag:render-subnet-router}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-${RENDER_SERVICE_NAME}}"

/render/tailscaled --tun=userspace-networking &

attempt=0
until /render/tailscale up \
  --authkey="${TAILSCALE_AUTHKEY}?ephemeral=false&preauthorized=true" \
  --advertise-tags="${TAILSCALE_TAGS}" \
  --hostname="${TAILSCALE_HOSTNAME}" \
  --reset \
  --force-reauth; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    echo "tailscale up failed after $attempt attempts; exiting so Render restarts the service" >&2
    exit 1
  fi
  sleep 2
done
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
