#!/bin/bash
# Pre-install script for Viniplay
# Generates a random SESSION_SECRET and writes it to appdata/.env

VINIPLAY_SECRET_KEY=$(tr -cd '[:alnum:]' </dev/urandom | fold -w "32" | head -n 1 | tr -d '\n')
sudo mkdir -p "$DOCKER_FOLDER/appdata/viniplay"
sudo chown -R "$USERNAME":"$USERNAME" "$DOCKER_FOLDER/appdata/viniplay"
echo "SESSION_SECRET=$VINIPLAY_SECRET_KEY" | sudo tee "$DOCKER_FOLDER/appdata/viniplay/.env" >/dev/null
sudo chmod 644 "$DOCKER_FOLDER/appdata/viniplay/.env"
