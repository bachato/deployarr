#!/bin/bash
# OpenClaw pre-install hook
# Clones the OpenClaw repo and builds the Docker image locally
# Auto-configures 9Router integration if available


BUILD_DIR="$DOCKER_FOLDER/appdata/openclaw/build"
IMAGE_NAME="deployrr/openclaw:latest"
CONFIG_DIR="$DOCKER_FOLDER/appdata/shared/openclaw-cli"

# Step 1: Check if image already exists
f_print_substep "Checking for existing OpenClaw image..."
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
		f_print_substep "Cloning OpenClaw repository..."
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

	# Step 4: Build the Docker image (using full paths, no cd needed)
	f_print_substep "Building OpenClaw Docker image (this may take 5-10 minutes)..."
	f_print_substep "Image name: $IMAGE_NAME"
	if sudo docker build -t "$IMAGE_NAME" -f "$BUILD_DIR/Dockerfile" "$BUILD_DIR"; then
		f_print_success "OpenClaw image built successfully"
	else
		f_print_error "Failed to build OpenClaw image"
		return 1
	fi
fi

# Step 5: Read the gateway token Deployrr generated and write it to the service env file.
# We use env_file: in compose (not Docker secrets) because Docker Compose standalone secrets
# are bind-mounted with the host file's permissions (root:root 0600), and mode: in compose
# does NOT override host permissions for file-type secrets. env_file is read by the Docker
# daemon (root) and injected as env vars — the container process never reads any file.
f_print_substep "Reading gateway token from Docker secret..."
GATEWAY_TOKEN=$(sudo cat "$DOCKER_FOLDER/secrets/openclaw_gateway_token" 2>/dev/null)
if [[ -z "$GATEWAY_TOKEN" ]]; then
	f_print_error "Gateway token secret not found — Deployrr should have created it before pre-install"
	return 1
fi

# Write the env file that compose injects via env_file:
# root:root 0600 — only root can read it on the host; Docker daemon reads it as root
sudo bash -c "printf 'OPENCLAW_GATEWAY_TOKEN=%s\n' '$GATEWAY_TOKEN' > '$DOCKER_FOLDER/secrets/openclaw.env'"
sudo chmod 600 "$DOCKER_FOLDER/secrets/openclaw.env"
sudo chown root:root "$DOCKER_FOLDER/secrets/openclaw.env"
export OPENCLAW_GATEWAY_TOKEN="$GATEWAY_TOKEN"
f_print_success "Gateway token written to env file (root:root 0600)"

# Step 5b: Clean stale device identity/pairing state from previous installs
# These directories cache device-auth and paired-device data tied to the old token.
# Without cleaning them, a new token causes "1008: pairing required" errors.
f_print_substep "Cleaning stale device pairing state..."
for _stale_dir in identity devices credentials sessions; do
    if sudo test -d "$CONFIG_DIR/$_stale_dir"; then
        sudo rm -rf "$CONFIG_DIR/$_stale_dir"
        f_print_substep "Removed stale $_stale_dir directory"
    fi
done

# Step 6: Ensure config directory exists
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

# Step 7: Set ownership of ALL volume-mounted directories (container runs as node:1000)
# Compose mounts: shared/openclaw-cli -> /home/node/.openclaw, workspace -> /home/node/.openclaw/workspace
f_print_substep "Setting directory ownership (UID 1000 for node user)..."
sudo mkdir -p "$DOCKER_FOLDER/appdata/openclaw/workspace"
sudo chown -R 1000:1000 "$CONFIG_DIR"
sudo chown -R 1000:1000 "$DOCKER_FOLDER/appdata/openclaw/workspace"
f_print_success "OpenClaw pre-install completed"
