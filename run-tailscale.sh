#!/usr/bin/env bash
# Tailscale subnet router for DocSpring's Render private network (Plausible's
# ClickHouse). Settings are managed by convox_racks_terraform/render.
#
# TAILSCALE_AUTHKEY is a Tailscale OAuth client secret
# (convox_racks_terraform/tailscale, OAuth client "render_router"). Each boot
# mints a fresh pre-authorised login for the same device, so nothing expires.
# The route is auto-approved for tag:render-subnet-router in the tailnet ACL.
set -euo pipefail

: "${TAILSCALE_AUTHKEY:?TAILSCALE_AUTHKEY (Tailscale OAuth client secret) is required}"
ADVERTISE_ROUTES="${ADVERTISE_ROUTES:-10.204.0.0/16}"
TAILSCALE_TAGS="${TAILSCALE_TAGS:-tag:render-subnet-router}"

/render/tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &
PID=$!

attempt=0
until /render/tailscale up \
  --authkey="${TAILSCALE_AUTHKEY}?ephemeral=false&preauthorized=true" \
  --advertise-tags="${TAILSCALE_TAGS}" \
  --hostname="${RENDER_SERVICE_NAME}" \
  --advertise-routes="${ADVERTISE_ROUTES}" \
  --force-reauth; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    echo "tailscale up failed after $attempt attempts; exiting so Render restarts the service" >&2
    kill "$PID"
    exit 1
  fi
  sleep 2
done

echo "Tailscale is up at IP $(/render/tailscale ip -4), advertising ${ADVERTISE_ROUTES}"

wait "$PID"
