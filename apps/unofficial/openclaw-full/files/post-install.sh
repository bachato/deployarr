#!/bin/bash
# OpenClaw Full: Post-install hook
# This script is sourced by f_execute_app_hook after container starts.
# All Deployrr variables (DOCKER_FOLDER, SERVER_LAN_IP, etc.) are available.

local _oc_container="openclaw-full"
local _oc_secret_file="$DOCKER_FOLDER/secrets/openclaw_full_gateway_token"
local _oc_config_dir="$DOCKER_FOLDER/appdata/shared/openclaw-cli"
local _oc_port="${OPENCLAW_FULL_PORT:-3211}"
local _oc_gateway_ready=false

# Step 1: Wait for gateway to become healthy (up to 30s)
# The container does first-run initialization on startup (writes openclaw.json,
# sets up workspace, etc.). We must wait for this to complete before overwriting
# openclaw.json — otherwise the container will overwrite our config.
f_print_substep "Waiting for OpenClaw Full gateway to initialize..."
for _oc_i in $(seq 1 15); do
	if sudo docker exec "$_oc_container" \
		node openclaw.mjs gateway health 2>/dev/null | grep -qi "healthy"; then
		_oc_gateway_ready=true
		f_print_substep "Gateway initialized"
		break
	fi
	sleep 2
done

if [[ "$_oc_gateway_ready" != true ]]; then
	f_print_warning "Gateway health check timed out — continuing anyway"
fi

# Step 2: Write openclaw.json AFTER container first-run initialization
# The container overwrites openclaw.json on first startup (normalizes it).
# We write our config here — after initialization — then restart the container
# so it picks up our settings correctly.
#
# dangerouslyDisableDeviceAuth: true — completely disables device identity checks
#   for the Control UI. Required for homelab LAN installs where the browser cannot
#   generate a device identity (HTTP, non-localhost). Without this, the gateway
#   always demands device pairing regardless of allowInsecureAuth.
# allowInsecureAuth: true — fallback for token-only auth on HTTP connections.
# trustedProxies — required when running behind Traefik reverse proxy.
#   Without this, OpenClaw treats all connections as untrusted/remote.
f_print_substep "Writing OpenClaw gateway configuration..."
local _oc_docker_subnet="172.16.0.0/12"

if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^9router$'; then
	f_print_substep "9Router detected — auto-configuring provider endpoint..."
	sudo tee "$_oc_config_dir/openclaw.json" > /dev/null <<OCCONFIG
{
  "gateway": {
    "bind": "lan",
    "trustedProxies": ["$_oc_docker_subnet"],
    "controlUi": {
      "allowInsecureAuth": true,
      "dangerouslyDisableDeviceAuth": true
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "9router/auto"
      }
    }
  },
  "models": {
    "providers": {
      "9router": {
        "baseUrl": "http://9router:20128/v1",
        "apiKey": "sk_9router",
        "api": "openai-completions",
        "models": [
          {
            "id": "auto",
            "name": "9Router Auto (configure providers in 9Router dashboard)"
          }
        ]
      }
    }
  }
}
OCCONFIG
	f_print_success "Configured to use 9Router at http://9router:20128/v1"
	f_print_substep "NEXT STEP: Open 9Router dashboard and connect at least one provider"
else
	sudo tee "$_oc_config_dir/openclaw.json" > /dev/null <<OCCONFIG
{
  "gateway": {
    "bind": "lan",
    "trustedProxies": ["$_oc_docker_subnet"],
    "controlUi": {
      "allowInsecureAuth": true,
      "dangerouslyDisableDeviceAuth": true
    }
  }
}
OCCONFIG
	f_print_substep "9Router not found — configure API providers manually after install"
fi
sudo chown 1000:1000 "$_oc_config_dir/openclaw.json"
f_print_substep "Gateway config written (dangerouslyDisableDeviceAuth + trustedProxies)"

# Step 3: Restart container to apply the new openclaw.json
# The container must restart to pick up the config changes we just wrote.
f_print_substep "Restarting container to apply configuration..."
sudo docker restart "$_oc_container" > /dev/null 2>&1
sleep 3

# Step 4: Wait for gateway to become healthy again after restart
f_print_substep "Waiting for gateway to come back up..."
_oc_gateway_ready=false
for _oc_i in $(seq 1 15); do
	if sudo docker exec "$_oc_container" \
		node openclaw.mjs gateway health 2>/dev/null | grep -qi "healthy"; then
		_oc_gateway_ready=true
		f_print_substep "Gateway is ready"
		break
	fi
	sleep 2
done

if [[ "$_oc_gateway_ready" != true ]]; then
	f_print_warning "Gateway health check timed out after restart — continuing anyway"
fi

# Step 5: Show the gateway URL and token
# Device auth is disabled (dangerouslyDisableDeviceAuth: true) so no pairing needed.
# The token is still required for the initial Settings → Token setup in the UI.
local _oc_display_token
_oc_display_token=$(sudo cat "$_oc_secret_file" 2>/dev/null)

whiptail --title "OpenClaw Full — Setup Complete" --msgbox \
"The OpenClaw Full gateway is running!

Open the Control UI:

  http://${SERVER_LAN_IP}:${_oc_port}
  (or your reverse proxy URL if configured)

On first open, go to Settings → Token and paste:

  ${_oc_display_token:-[ERROR: could not read token from ${_oc_secret_file}]}

Click Save — you should connect immediately with no pairing prompt.

Note: Device authentication is disabled for LAN access.
To re-enable it, set dangerouslyDisableDeviceAuth: false
in ~/.openclaw/openclaw.json and restart the container." 24 72
