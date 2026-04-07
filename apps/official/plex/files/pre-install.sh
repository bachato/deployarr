#!/bin/bash
# Plex pre-install hook
# Handles optional Plex claim token - if empty, comments out secrets section

APP_COMPOSE_FILE="$DOCKER_FOLDER/compose/$HOSTNAME/plex.yml"

# Read the plex claim secret (may be empty)
PLEX_CLAIM=$(sudo cat "$DOCKER_FOLDER/secrets/plex_claim" 2>/dev/null)

# If plex_claim is empty, comment out the secrets-related lines
if [[ -z "$PLEX_CLAIM" ]]; then
    f_print_substep "No Plex claim token provided, skipping claim configuration"

    # Comment out PLEX_CLAIM_FILE environment variable
    f_safe_sed 's|      PLEX_CLAIM_FILE: /run/secrets/plex_claim|      # PLEX_CLAIM_FILE: /run/secrets/plex_claim|' "$APP_COMPOSE_FILE"

    # Comment out secrets section
    f_safe_sed 's|    secrets:|    # secrets:|' "$APP_COMPOSE_FILE"
    f_safe_sed 's|      - plex_claim|      # - plex_claim|' "$APP_COMPOSE_FILE"

    f_print_substep "Secrets section commented out in: $APP_COMPOSE_FILE"
else
    f_print_substep "Plex claim token provided, server will claim on first start"
fi
