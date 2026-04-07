#!/bin/bash
# 9Router pre-install hook
# Clones the 9Router repo and builds the Docker image locally
# Then injects secrets into the compose file

APP_COMPOSE_FILE="$DOCKER_FOLDER/compose/$HOSTNAME/9router.yml"
BUILD_DIR="$DOCKER_FOLDER/appdata/9router/build"
IMAGE_NAME="deployrr/9router:latest"

# Step 1: Check if image already exists
f_print_substep "Checking for existing 9Router image..."
if sudo docker image inspect "$IMAGE_NAME" &>/dev/null; then
	f_print_substep "Image $IMAGE_NAME already exists"
	f_print_substep "To rebuild, run: sudo docker rmi $IMAGE_NAME"
else
	# Step 2: Clone or update the 9Router repository
	f_print_substep "Preparing 9Router source code..."
	if [[ -d "$BUILD_DIR/.git" ]]; then
		f_print_substep "Updating existing repository..."
		sudo git -C "$BUILD_DIR" pull --ff-only 2>/dev/null || {
			f_print_substep "Pull failed, re-cloning..."
			sudo rm -rf "$BUILD_DIR"
			sudo git clone --depth 1 https://github.com/decolua/9router.git "$BUILD_DIR"
		}
	else
		f_print_substep "Cloning 9Router repository..."
		sudo mkdir -p "$(dirname "$BUILD_DIR")"
		sudo rm -rf "$BUILD_DIR"
		sudo git clone --depth 1 https://github.com/decolua/9router.git "$BUILD_DIR"
	fi

	# Fix permissions so build context is readable
	sudo chmod -R a+rX "$BUILD_DIR"

	# Apply OAuth race condition fix
	f_print_substep "Applying OAuth Race Condition patch..."
	if [[ -f "$app_folder/files/oauth-fix.patch" ]]; then
		sudo git -C "$BUILD_DIR" apply "$app_folder/files/oauth-fix.patch" 2>/dev/null || f_print_substep "Patch already applied or failed"
	fi

	# Step 3: Build the Docker image (using full paths, no cd needed)
	f_print_substep "Building 9Router Docker image (this may take 3-5 minutes)..."
	f_print_substep "Image name: $IMAGE_NAME"
	if sudo docker build -t "$IMAGE_NAME" -f "$BUILD_DIR/Dockerfile" "$BUILD_DIR"; then
		f_print_success "9Router image built successfully"
	else
		f_print_error "Failed to build 9Router image"
		return 1
	fi
fi

# Step 4: Inject secrets into compose file
f_print_substep "Configuring 9Router secrets..."

JWT_SECRET=$(sudo cat "$DOCKER_FOLDER/secrets/ninerouter_jwt_secret" 2>/dev/null)
if [[ -n "$JWT_SECRET" ]]; then
	f_safe_sed "s|JWT-SECRET-PLACEHOLDER|$JWT_SECRET|" "$APP_COMPOSE_FILE"
	f_print_substep "JWT secret injected into compose file"
else
	f_print_error "JWT secret not found in secrets"
	return 1
fi

INITIAL_PASSWORD=$(sudo cat "$DOCKER_FOLDER/secrets/ninerouter_password" 2>/dev/null)
if [[ -n "$INITIAL_PASSWORD" ]]; then
	f_safe_sed "s|INITIAL-PASSWORD-PLACEHOLDER|$INITIAL_PASSWORD|" "$APP_COMPOSE_FILE"
	export INITIAL_PASSWORD  # Export so envsubst can substitute in post-install messages
	f_print_substep "Initial password injected into compose file"
else
	f_print_error "Initial password not found in secrets"
	return 1
fi

# Generate unique API key secret and machine ID salt
API_KEY_SECRET=$(openssl rand -hex 16 2>/dev/null || head -c 32 /dev/urandom | xxd -p | head -c 32)
MACHINE_ID_SALT=$(openssl rand -hex 16 2>/dev/null || head -c 32 /dev/urandom | xxd -p | head -c 32)
f_safe_sed "s|API-KEY-SECRET-PLACEHOLDER|$API_KEY_SECRET|" "$APP_COMPOSE_FILE"
f_safe_sed "s|MACHINE-ID-SALT-PLACEHOLDER|$MACHINE_ID_SALT|" "$APP_COMPOSE_FILE"
f_print_substep "API key secret and machine ID salt generated"

# Step 5: Set ownership of ALL volume-mounted directories
f_print_substep "Setting directory ownership..."
sudo mkdir -p "$DOCKER_FOLDER/appdata/9router/data"
sudo mkdir -p "$DOCKER_FOLDER/appdata/9router/usage"
sudo chown -R "$PUID:$PGID" "$DOCKER_FOLDER/appdata/9router/data"
sudo chown -R "$PUID:$PGID" "$DOCKER_FOLDER/appdata/9router/usage"
f_print_success "9Router pre-install completed"
