#!/bin/bash
# SearXNG pre-install hook
# Generates secret key and deploys preconfigured settings before containers start

APP_SNAME="searxng"
APP_PNAME="SearXNG"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Generate secret key
f_print_substep "Generating $APP_PNAME secret key..."
SEARXNG_SECRET_VALUE=$(openssl rand -hex 16)
f_set_env "SEARXNG_SECRET" "$SEARXNG_SECRET_VALUE"

# Create appdata directories
f_print_substep "Creating $APP_PNAME configuration directories..."
sudo mkdir -p "$DOCKER_FOLDER/appdata/searxng/settings"
sudo mkdir -p "$DOCKER_FOLDER/appdata/searxng/cache"

# Copy preconfigured settings.yml and substitute secret key placeholder
f_print_substep "Deploying $APP_PNAME configuration files..."
sudo cp "$APP_DIR/files/settings.yml" "$DOCKER_FOLDER/appdata/searxng/settings/settings.yml"
sudo sed -i "s|SEARXNG-SECRET-KEY-PLACEHOLDER|$SEARXNG_SECRET_VALUE|g" "$DOCKER_FOLDER/appdata/searxng/settings/settings.yml"

# Copy limiter.toml for bot detection
sudo cp "$APP_DIR/files/limiter.toml" "$DOCKER_FOLDER/appdata/searxng/settings/limiter.toml"
