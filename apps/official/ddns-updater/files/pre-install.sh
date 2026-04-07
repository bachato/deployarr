#!/bin/bash
# Pre-install script for DDNS-Updater
# Copies config.json and replaces placeholders with actual values from secrets

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$DOCKER_FOLDER/appdata/ddns-updater/backups"

# Copy config template
sudo cp "$APP_DIR/files/config.json" "$DOCKER_FOLDER/appdata/ddns-updater/config.json"

# Replace placeholders with actual values
CF_ZONE_ID=$(sudo cat "$DOCKER_FOLDER/secrets/cf_zone_identifier")
CF_API_TOKEN=$(sudo cat "$DOCKER_FOLDER/secrets/cf_dns_api_token")

f_safe_sed "s|CLOUDFLARE-ZONE-IDENTIFIER-PLACEHOLDER|${CF_ZONE_ID}|g" "$DOCKER_FOLDER/appdata/ddns-updater/config.json"
f_safe_sed "s|CLOUDFLARE-DOMAIN-PLACEHOLDER|${DOMAINNAME_1}|g" "$DOCKER_FOLDER/appdata/ddns-updater/config.json"
f_safe_sed "s|CLOUDFLARE-API-TOKEN-PLACEHOLDER|${CF_API_TOKEN}|g" "$DOCKER_FOLDER/appdata/ddns-updater/config.json"
