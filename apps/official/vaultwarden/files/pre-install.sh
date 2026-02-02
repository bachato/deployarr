#!/bin/bash
# Vaultwarden pre-install hook
# Enables Admin WebUI by hashing the admin token with argon2 and updating compose.yml

COMPOSE_FILE="$DOCKER_FOLDER/compose/$HOSTNAME/vaultwarden.yml"

# Read the admin token secret
ADMIN_TOKEN_RAW=$(sudo cat "$DOCKER_FOLDER/secrets/vaultwarden_admin_token")

# Hash the token with argon2
VAULTWARDEN_ADMIN_TOKEN=$(echo -n "$ADMIN_TOKEN_RAW" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4)
echo -e "[INFO] Admin Token created."

# Uncomment ADMIN_TOKEN line in compose
sed -i 's|# - ADMIN_TOKEN=|- ADMIN_TOKEN=|' "$COMPOSE_FILE"
sleep 1

# Replace placeholder with hashed token
sed -i "s|ADMIN-TOKEN-PLACEHOLDER|$VAULTWARDEN_ADMIN_TOKEN|" "$COMPOSE_FILE"
sleep 1

# Escape $ signs for Docker Compose (argon2 hash contains $ characters)
sed -i '/.*ADMIN_TOKEN.*/s/\$/\$\$/g' "$COMPOSE_FILE"
echo -e "[INFO] Admin Token added to compose file."
