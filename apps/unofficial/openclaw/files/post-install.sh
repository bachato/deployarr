#!/bin/bash
# OpenClaw: Post-install hook
# This script is sourced by f_execute_app_hook after container starts.
# All Deployrr variables (DOCKER_FOLDER, SERVER_LAN_IP, etc.) are available.

local _oc_container="openclaw"
local _oc_secret_file="$DOCKER_FOLDER/secrets/openclaw_gateway_token"
local _oc_config_dir="$DOCKER_FOLDER/appdata/shared/openclaw-cli"
local _oc_port="${OPENCLAW_PORT:-18789}"
local _oc_gateway_ready=false

# Step 1: Wait for gateway to become healthy (up to 30s)
# The container does first-run initialization on startup (writes openclaw.json,
# sets up workspace, etc.). We must wait for this to complete before overwriting
# openclaw.json — otherwise the container will overwrite our config.
f_print_substep "Waiting for OpenClaw gateway to initialize..."
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
# gateway.auth.mode: "trusted-proxy" — trusts the user identity header set by
#   the active Traefik auth middleware (basicAuth, Authelia, Authentik, etc.).
#   The correct header is auto-detected from the Traefik file provider.
# dangerouslyDisableDeviceAuth: true — completely disables device identity checks
#   for the Control UI. Required for homelab LAN installs.
# trustedProxies — required when running behind Traefik reverse proxy.
#   Without this, OpenClaw treats all connections as untrusted/remote.
f_print_substep "Writing OpenClaw gateway configuration..."
local _oc_docker_subnet="172.16.0.0/12"

# Detect active auth chain → set correct userHeader
# Each auth middleware sets a different header for the authenticated username:
#   basicAuth/OAuth   → X-Forwarded-User
#   Authelia/TinyAuth  → Remote-User
#   Authentik          → X-authentik-username
local _oc_user_header="x-forwarded-user"  # safe default
# $CHAIN_NAME is a global set during the install flow's auth selection
local _oc_detected_chain="${CHAIN_NAME:-}"
# Fallback: read from Traefik file provider if CHAIN_NAME not set (e.g. reinstall)
if [[ -z "$_oc_detected_chain" ]]; then
	local _oc_file_provider="$DOCKER_FOLDER/appdata/traefik3/rules/$HOSTNAME/app-openclaw.yml"
	if [[ -f "$_oc_file_provider" ]]; then
		_oc_detected_chain=$(grep -o 'chain-[a-z-]*' "$_oc_file_provider" 2>/dev/null | head -1)
	fi
fi
case "$_oc_detected_chain" in
	chain-authelia|chain-tinyauth)
		_oc_user_header="remote-user"
		;;
	chain-authentik)
		_oc_user_header="x-authentik-username"
		;;
esac
f_print_substep "Auth: ${_oc_detected_chain:-no chain} → userHeader: $_oc_user_header"

if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^9router$'; then
	f_print_substep "9Router detected — auto-configuring provider endpoint..."

	# Query 9Router for its actual available models (from the shim)
	local _oc_9r_models_json
	_oc_9r_models_json=$(sudo docker exec "$_oc_container" \
		wget -qO- http://9router:20128/v1/models 2>/dev/null)

	# Build OpenClaw-format models array from 9Router's /v1/models response
	local _oc_9r_models_array="[]"
	local _oc_9r_primary=""
	if [[ -n "$_oc_9r_models_json" ]]; then
		_oc_9r_models_array=$(echo "$_oc_9r_models_json" | jq '[.data[] | {id: .id, name: (.root // .id)}]' 2>/dev/null)
		_oc_9r_primary=$(echo "$_oc_9r_models_json" | jq -r '.data[0].id // empty' 2>/dev/null)
	fi

	# Fallback if query failed or returned no models
	if [[ -z "$_oc_9r_primary" ]]; then
		f_print_warning "Could not query 9Router models — using placeholder"
		_oc_9r_models_array='[{"id": "placeholder", "name": "Configure models in 9Router dashboard"}]'
		_oc_9r_primary="placeholder"
	else
		f_print_substep "Found $(echo "$_oc_9r_models_array" | jq 'length') model(s) from 9Router"
	fi

	# Write config to temp file first (NEVER use sudo tee — it injects password)
	local _oc_tmp_cfg="/tmp/openclaw_cfg_$$.json"
	cat > "$_oc_tmp_cfg" <<OCCONFIG
{
  "gateway": {
    "bind": "lan",
    "auth": {
      "mode": "trusted-proxy",
      "trustedProxy": {
        "userHeader": "$_oc_user_header"
      }
    },
    "trustedProxies": ["$_oc_docker_subnet"],
    "controlUi": {
      "allowInsecureAuth": true,
      "dangerouslyDisableDeviceAuth": true
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "9router/$_oc_9r_primary"
      }
    }
  },
  "models": {
    "providers": {
      "9router": {
        "baseUrl": "http://9router:20128/v1",
        "apiKey": "sk_9router",
        "api": "openai-completions",
        "models": $_oc_9r_models_array
      }
    }
  }
}
OCCONFIG
	sudo cp "$_oc_tmp_cfg" "$_oc_config_dir/openclaw.json"
	rm -f "$_oc_tmp_cfg"
	f_print_success "Configured to use 9Router (model: 9router/$_oc_9r_primary)"
else
	# No 9Router — write gateway-only config
	local _oc_tmp_cfg="/tmp/openclaw_cfg_$$.json"
	cat > "$_oc_tmp_cfg" <<OCCONFIG
{
  "gateway": {
    "bind": "lan",
    "auth": {
      "mode": "trusted-proxy",
      "trustedProxy": {
        "userHeader": "$_oc_user_header"
      }
    },
    "trustedProxies": ["$_oc_docker_subnet"],
    "controlUi": {
      "allowInsecureAuth": true,
      "dangerouslyDisableDeviceAuth": true
    }
  }
}
OCCONFIG
	sudo cp "$_oc_tmp_cfg" "$_oc_config_dir/openclaw.json"
	rm -f "$_oc_tmp_cfg"
	f_print_substep "9Router not found — configure API providers manually after install"
fi
sudo chown 1000:1000 "$_oc_config_dir/openclaw.json"
f_print_substep "Gateway config written (dangerouslyDisableDeviceAuth + trustedProxies)"

# Step 2b: Ollama Heartbeat Configuration (optional)
# If user chose to route heartbeats to Ollama, pull the model and merge config.
# This runs BEFORE the container restart so all config changes are picked up at once.
if [[ "${OPENCLAW_OLLAMA_HEARTBEAT:-no}" == "yes" ]]; then
	f_print_substep "Configuring Ollama heartbeat..."

	# Verify Ollama container is running
	if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^ollama$'; then
		# Pull the heartbeat model into Ollama
		f_print_substep "Pulling llama3.2:3b model into Ollama (this may take a minute)..."
		if sudo docker exec ollama ollama pull llama3.2:3b 2>&1; then
			f_print_success "Model llama3.2:3b pulled successfully"
		else
			f_print_warning "Failed to pull model — heartbeat will still try at runtime"
		fi

		# Merge heartbeat config + Ollama provider into openclaw.json using jq
		# IMPORTANT: heartbeat must go under agents.defaults.heartbeat (NOT top-level)
		# OpenClaw rejects top-level "heartbeat" key and crash-loops with "Config invalid"
		f_print_substep "Adding heartbeat and Ollama provider to openclaw.json..."
		local _oc_tmp_config="/tmp/openclaw_config_merge_$$.json"
		if sudo jq '. * {
			"agents": (.agents // {}) * {
				"defaults": ((.agents // {}).defaults // {}) * {
					"heartbeat": {
						"every": "1h",
						"model": "ollama/llama3.2:3b",
						"session": "main",
						"target": "slack",
						"prompt": "Check: Any blockers, opportunities, or progress updates needed?"
					}
				}
			},
			"models": (.models // {}) * {
				"providers": ((.models // {}).providers // {}) * {
					"ollama": ((.models // {}).providers // {}).ollama // {} | . * {
						"baseUrl": "http://ollama:11434",
						"api": "openai-completions",
						"models": [
							{
								"id": "llama3.2:3b",
								"name": "Llama 3.2 3B (heartbeat)"
							}
						]
					}
				}
			}
		}' "$_oc_config_dir/openclaw.json" > "$_oc_tmp_config" 2>/dev/null; then
			sudo mv "$_oc_tmp_config" "$_oc_config_dir/openclaw.json"
			sudo chown 1000:1000 "$_oc_config_dir/openclaw.json"
			f_print_success "Heartbeat configured to use Ollama (free local LLM)"
			f_print_substep "Heartbeats will use ollama/llama3.2:3b instead of paid API"
		else
			f_print_warning "Failed to merge heartbeat config — configure manually in openclaw.json"
			sudo rm -f "$_oc_tmp_config"
		fi
	else
		f_print_warning "Ollama container not found — skipping heartbeat configuration"
		f_print_substep "Install Ollama first, then reconfigure heartbeat manually"
	fi
fi

# Step 2c: Configure allowedOrigins for gateway Control UI
# Without correct allowedOrigins, the browser cannot connect to the gateway WebSocket.
# We construct the origins list from Deployrr environment variables that are available
# at this point (DOMAINNAME_1, SERVER_LAN_IP, port).
f_print_substep "Configuring gateway allowedOrigins..."

# Try to read existing subdomain from Traefik file provider (reinstall case)
local _oc_subdomain
_oc_subdomain=$(f_get_app_subdomain "openclaw" 2>/dev/null)
# Default: sname with hyphens removed (matches Deployrr's default subdomain pattern)
[[ -z "$_oc_subdomain" ]] && _oc_subdomain="openclaw"

# Build origins array — always include localhost entries
local _oc_origins
_oc_origins='["http://localhost:'"$_oc_port"'","http://127.0.0.1:'"$_oc_port"'"]'

# Add LAN IP entry if available
if [[ -n "$SERVER_LAN_IP" ]]; then
	_oc_origins=$(echo "$_oc_origins" | jq '. + ["http://'"${SERVER_LAN_IP}:${_oc_port}"'"]')
fi

# Add Traefik/HTTPS entry if a domain is configured
if [[ -n "$DOMAINNAME_1" ]]; then
	_oc_origins=$(echo "$_oc_origins" | jq '. + ["https://'"${_oc_subdomain}.${DOMAINNAME_1}"'"]')
	f_print_substep "Added Traefik origin: https://${_oc_subdomain}.${DOMAINNAME_1}"
fi

# Merge allowedOrigins into openclaw.json
local _oc_tmp_origins="/tmp/openclaw_origins_$$.json"
if sudo jq --argjson origins "$_oc_origins" \
	'.gateway.controlUi.allowedOrigins = $origins' \
	"$_oc_config_dir/openclaw.json" > "$_oc_tmp_origins" 2>/dev/null; then
	sudo mv "$_oc_tmp_origins" "$_oc_config_dir/openclaw.json"
	sudo chown 1000:1000 "$_oc_config_dir/openclaw.json"
	f_print_success "Gateway allowedOrigins configured"
else
	f_print_warning "Failed to set allowedOrigins — you may need to configure manually"
	sudo rm -f "$_oc_tmp_origins"
fi



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

# Step 5: Show the gateway URL
# Trusted-proxy auth mode — Traefik's basicAuth sets X-Forwarded-User header
# (requires headerField in middlewares-basic-auth.yml). No tokens needed.
if [[ -n "$DOMAINNAME_1" ]]; then
	whiptail --title "OpenClaw — Setup Complete" --msgbox \
"The OpenClaw gateway is running!

Open the Control UI:

  https://${_oc_subdomain:-openclaw}.${DOMAINNAME_1}

No token or device pairing needed — just open the URL.
Traefik handles authentication automatically." 14 72
else
	local _oc_display_token
	_oc_display_token=$(sudo cat "$_oc_secret_file" 2>/dev/null)
	whiptail --title "OpenClaw — Setup Complete" --msgbox \
"The OpenClaw gateway is running!

Open the Control UI:

  http://${SERVER_LAN_IP}:${_oc_port}

You will need your gateway token for LAN access:
  ${_oc_display_token:-TOKEN}" 14 72
fi
