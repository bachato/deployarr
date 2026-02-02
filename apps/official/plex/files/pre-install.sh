#!/bin/bash
# Plex pre-install hook
# Handles optional Plex claim token - if empty, comments out secrets section

COMPOSE_FILE="$DOCKER_FOLDER/compose/$HOSTNAME/plex.yml"

# Read the plex claim secret (may be empty)
PLEX_CLAIM=$(sudo cat "$DOCKER_FOLDER/secrets/plex_claim" 2>/dev/null)

# If plex_claim is empty, comment out the secrets-related lines
if [[ -z "$PLEX_CLAIM" ]]; then
    echo -e "[INFO] No Plex claim token provided. Skipping claim configuration."

    # Comment out PLEX_CLAIM_FILE environment variable
    sed -i 's|      PLEX_CLAIM_FILE: /run/secrets/plex_claim|      # PLEX_CLAIM_FILE: /run/secrets/plex_claim|' "$COMPOSE_FILE"

    # Comment out secrets section
    sed -i 's|    secrets:|    # secrets:|' "$COMPOSE_FILE"
    sed -i 's|      - plex_claim|      # - plex_claim|' "$COMPOSE_FILE"

    echo -e "[INFO] Secrets section commented out in compose file."
else
    echo -e "[INFO] Plex claim token provided. Server will attempt to claim on first start."
fi
