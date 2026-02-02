#!/bin/bash
# Pre-install script for Cloudflare Tunnel
# Creates the hosts file needed for container mount

sudo mkdir -p "$DOCKER_FOLDER/appdata/cloudflare-tunnel"
sudo touch "$DOCKER_FOLDER/appdata/cloudflare-tunnel/hosts"
sudo chmod 644 "$DOCKER_FOLDER/appdata/cloudflare-tunnel/hosts"
