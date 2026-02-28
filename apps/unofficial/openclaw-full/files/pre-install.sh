#!/bin/bash
# OpenClaw Full pre-install hook
# Clones the OpenClaw repo and builds the Docker image with extra packages
# Uses upstream pnpm build with OPENCLAW_DOCKER_APT_PACKAGES and OPENCLAW_INSTALL_BROWSER
# Includes: git, curl, jq, build-essential, Chromium/Playwright baked into image
# Auto-configures 9Router integration if available


BUILD_DIR="$DOCKER_FOLDER/appdata/openclaw-full/build"
IMAGE_NAME="deployrr/openclaw-full:latest"
CONFIG_DIR="$DOCKER_FOLDER/appdata/shared/openclaw-cli"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Step 1: Check if image already exists
f_print_substep "Checking for existing OpenClaw Full image..."
if sudo docker image inspect "$IMAGE_NAME" &>/dev/null; then
	f_print_substep "Image $IMAGE_NAME already exists"
	f_print_substep "To rebuild, run: sudo docker rmi $IMAGE_NAME"
else
	# Step 2: Clone or update the OpenClaw repository
	f_print_substep "Preparing OpenClaw source code..."
	if [[ -d "$BUILD_DIR/.git" ]]; then
		f_print_substep "Updating existing repository..."
		if ! sudo git -C "$BUILD_DIR" pull --ff-only; then
			f_print_substep "Pull failed, re-cloning..."
			sudo rm -rf "$BUILD_DIR"
			if ! sudo git clone --depth 1 https://github.com/openclaw/openclaw.git "$BUILD_DIR"; then
				f_print_error "Failed to clone OpenClaw repository"
				return 1
			fi
		fi
	else
		f_print_substep "Cloning OpenClaw repository (this may take a minute)..."
		sudo mkdir -p "$(dirname "$BUILD_DIR")"
		sudo rm -rf "$BUILD_DIR"
		if ! sudo git clone --depth 1 https://github.com/openclaw/openclaw.git "$BUILD_DIR"; then
			f_print_error "Failed to clone OpenClaw repository"
			return 1
		fi
	fi

	# Fix permissions so build context is readable
	sudo chmod -R a+rX "$BUILD_DIR"

	# Step 3: Validate build context has essential files
	for _required_file in package.json pnpm-lock.yaml .npmrc pnpm-workspace.yaml; do
		if ! sudo test -f "$BUILD_DIR/$_required_file"; then
			f_print_error "Build context missing '$_required_file' — clone may have failed"
			f_print_error "Try removing $BUILD_DIR and re-running the installer"
			return 1
		fi
	done
	f_print_substep "Build context validated ($(sudo du -sh "$BUILD_DIR" | cut -f1) source tree)"

	# Step 4: Copy the full Dockerfile into the build context
	f_print_substep "Using full-featured Dockerfile (pnpm + extra packages)..."
	sudo cp "$APP_DIR/Dockerfile.full" "$BUILD_DIR/Dockerfile.full"

	# Step 5: Build the Docker image with extra packages (using full paths, no cd needed)
	f_print_substep "Building OpenClaw Full image (this may take 10-15 minutes)..."
	f_print_substep "Image name: $IMAGE_NAME"
	f_print_substep "Includes: git, curl, jq, build-essential, Chromium/Playwright"
	if sudo docker build -t "$IMAGE_NAME" -f "$BUILD_DIR/Dockerfile.full" "$BUILD_DIR"; then
		f_print_success "OpenClaw Full image built successfully"
	else
		f_print_error "Failed to build OpenClaw Full image"
		return 1
	fi
fi

# Step 6: Read the gateway token Deployrr generated and write it to the service env file.
# We use env_file: in compose (not Docker secrets) because Docker Compose standalone secrets
# are bind-mounted with the host file's permissions (root:root 0600), and mode: in compose
# does NOT override host permissions for file-type secrets. env_file is read by the Docker
# daemon (root) and injected as env vars — the container process never reads any file.
f_print_substep "Reading gateway token from Docker secret..."
sudo mkdir -p "$DOCKER_FOLDER/secrets"
GATEWAY_TOKEN=$(sudo cat "$DOCKER_FOLDER/secrets/openclaw_full_gateway_token" 2>/dev/null)
if [[ -z "$GATEWAY_TOKEN" ]]; then
	f_print_error "Gateway token secret not found — Deployrr should have created it before pre-install"
	return 1
fi

# Write the env file that compose injects via env_file:
# root:root 0600 — only root can read it on the host; Docker daemon reads it as root
sudo bash -c "printf 'OPENCLAW_GATEWAY_TOKEN=%s\n' '$GATEWAY_TOKEN' > '$DOCKER_FOLDER/secrets/openclaw-full.env'"
sudo chmod 600 "$DOCKER_FOLDER/secrets/openclaw-full.env"
sudo chown root:root "$DOCKER_FOLDER/secrets/openclaw-full.env"
export OPENCLAW_FULL_GATEWAY_TOKEN="$GATEWAY_TOKEN"
f_print_success "Gateway token written to env file (root:root 0600)"

# Step 6b: Clean stale device identity/pairing state from previous installs
# These directories cache device-auth and paired-device data tied to the old token.
# Without cleaning them, a new token causes "1008: pairing required" errors.
f_print_substep "Cleaning stale device pairing state..."
for _stale_dir in identity devices credentials sessions; do
    if sudo test -d "$CONFIG_DIR/$_stale_dir"; then
        sudo rm -rf "$CONFIG_DIR/$_stale_dir"
        f_print_substep "Removed stale $_stale_dir directory"
    fi
done

# Step 7: Ensure config directory exists
# NOTE: openclaw.json is written in post-install AFTER the container starts.
# The container overwrites openclaw.json on first startup (normalizes it),
# so writing it here would be immediately discarded. Post-install writes it
# after the container has done its first-run initialization, then restarts
# the container so it picks up allowInsecureAuth and trustedProxies.
f_print_substep "Preparing OpenClaw config directory..."
sudo mkdir -p "$CONFIG_DIR"

# Create shim binary if it doesn't exist (handles OpenClaw installed before 9Router)
# 9Router needs this for `command -v openclaw` to succeed in its container
if [[ ! -f "$CONFIG_DIR/openclaw" ]]; then
	printf '#!/bin/sh\nexit 0\n' | sudo tee "$CONFIG_DIR/openclaw" > /dev/null
	sudo chmod +x "$CONFIG_DIR/openclaw"
fi

# Step 8: Set ownership of ALL volume-mounted directories (container runs as node:1000)
f_print_substep "Setting directory ownership (UID 1000 for node user)..."
sudo mkdir -p "$DOCKER_FOLDER/appdata/openclaw-full/home"
sudo chown -R 1000:1000 "$CONFIG_DIR"
sudo chown -R 1000:1000 "$DOCKER_FOLDER/appdata/openclaw-full/workspace"
sudo chown -R 1000:1000 "$DOCKER_FOLDER/appdata/openclaw-full/home"

# Step 9: Run non-interactive onboard to create device identity
# This is CRITICAL — without it, the gateway has no approved devices and
# all connections (browser UI, CLI) get "1008: pairing required".
# Upstream flow: build → onboard → start gateway. We replicate this with raw docker run.
f_print_substep "Running OpenClaw onboarding (creating device identity)..."

# Build onboard args — with or without 9Router provider
ONBOARD_ARGS=(
	"onboard" "--non-interactive" "--accept-risk"
	"--gateway-port" "18789"
	"--gateway-bind" "lan"
	"--no-install-daemon"
	"--skip-skills"
)

# If 9Router is running, configure it as the provider during onboard
if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^9router$'; then
	ONBOARD_ARGS+=(
		"--auth-choice" "custom-api-key"
		"--custom-base-url" "http://9router:20128/v1"
		"--custom-model-id" "auto"
		"--custom-api-key" "sk_9router"
		"--custom-provider-id" "9router"
		"--custom-compatibility" "openai"
	)
fi

# Run onboard via raw docker run (not compose — avoids timing issues)
# Must use same volumes so identity is written to the shared config dir
# Pass OPENCLAW_GATEWAY_TOKEN so onboarding registers this gateway's identity
# with the correct token (the one Deployrr generated and stored in the secret).
if sudo docker run --rm \
	-e HOME=/home/node \
	-e OPENCLAW_GATEWAY_TOKEN="$GATEWAY_TOKEN" \
	-v "$CONFIG_DIR:/home/node/.openclaw" \
	-v "$DOCKER_FOLDER/appdata/openclaw-full/workspace:/home/node/.openclaw/workspace" \
	--user 1000:1000 \
	"$IMAGE_NAME" \
	node openclaw.mjs "${ONBOARD_ARGS[@]}" 2>&1; then
	f_print_success "Device identity created — pairing will be automatic"
else
	f_print_warning "Onboard returned non-zero (may still work — identity might already exist)"
fi

# Step 10: Verify Docker socket access for sandbox support
f_print_substep "Checking Docker socket access for sandbox support..."
if [[ -S /var/run/docker.sock ]]; then
	f_print_substep "Docker socket available — sandbox features enabled"
	f_print_substep "Chromium/Playwright pre-installed in image (no first-run download needed)"
else
	f_print_warning "Docker socket not found — sandbox features will be limited"
fi

f_print_success "OpenClaw Full pre-install completed"
