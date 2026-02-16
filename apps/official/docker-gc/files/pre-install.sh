#!/bin/bash
# Docker-GC pre-install hook
# Creates docker-gc-exclude file before container starts to prevent Docker from creating a directory

# Get the directory where this script is located (app/files/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/docker-gc-exclude"

# Create parent directory if it doesn't exist
sudo mkdir -p "$DOCKER_FOLDER/appdata/docker-gc"

# Copy docker-gc-exclude file to destination
# This must happen BEFORE the container starts, otherwise Docker creates a directory at this path
if [[ -f "$SOURCE_FILE" ]]; then
    sudo cp "$SOURCE_FILE" "$DOCKER_FOLDER/appdata/docker-gc/docker-gc-exclude"
    sudo chown "$USERNAME:$USERNAME" "$DOCKER_FOLDER/appdata/docker-gc/docker-gc-exclude"
    sudo chmod 644 "$DOCKER_FOLDER/appdata/docker-gc/docker-gc-exclude"
    dev_echo "Created docker-gc-exclude file at $DOCKER_FOLDER/appdata/docker-gc/docker-gc-exclude"
else
    dev_echo "ERROR: Source file not found: $SOURCE_FILE"
    return 1
fi
