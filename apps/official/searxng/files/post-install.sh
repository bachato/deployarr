#!/bin/bash
# SearXNG post-install hook
# Configures Redis limiter URL in settings.yml and copies limiter.toml

APP_SNAME="searxng"
APP_PNAME="SearXNG"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

f_print_step "1/4" "Waiting for $APP_PNAME to generate initial configuration..."
f_blank_line_sleep 5
echo

f_print_step "2/4" "Stopping $APP_PNAME container..."
f_stop_containers "$APP_SNAME"
echo

f_print_step "3/4" "Configuring $APP_PNAME..."
f_print_substep "Setting Redis limiter URL in settings.yml"
sudo sed -i 's|  url: false|  url: redis://redis:6379/0|g' "$DOCKER_FOLDER/appdata/searxng/settings.yml"
f_print_substep "Copying limiter.toml for bot detection"
sudo cp "$APP_DIR/files/limiter.toml" "$DOCKER_FOLDER/appdata/searxng/limiter.toml"
echo

f_print_step "4/4" "Recreating $APP_PNAME container..."
f_docker_compose_recreate "$APP_SNAME" "06"

f_print_success "$APP_PNAME configuration complete"
