#!/bin/bash
# PdfDing Post-Install Hook
# Modifies the compose file to set the correct HOST_NAME value

# This script is called after PdfDing is installed
# It replaces the HOST_NAME placeholder with the appropriate value

APP_SNAME="pdfding"
COMPOSE_FILE="$DOCKER_FOLDER/compose/$HOSTNAME/$APP_SNAME.yml"

echo -e "[INFO] Configuring PdfDing hostname..."

# Determine the hostname value
if [[ -z "$DOMAINNAME_1" ]]; then
    # No domain configured - use server IP
    PDFDING_HOSTNAME="$SERVER_LAN_IP"
    echo -e "[INFO] No domain configured, using IP: $PDFDING_HOSTNAME"
else
    # Domain configured - use subdomain.domain format
    # Use the app's subdomain from Traefik configuration or default to 'pdfding'
    PDFDING_SUBDOMAIN="${FILE_PROVIDER_APP_SUBDOMAIN:-pdfding}"
    PDFDING_HOSTNAME="${PDFDING_SUBDOMAIN}.${DOMAINNAME_1}"
    echo -e "[INFO] Using hostname: $PDFDING_HOSTNAME"
fi

# Replace the placeholder in the compose file
if [[ -f "$COMPOSE_FILE" ]]; then
    sed -i "s|PDFDING_HOSTNAME_PLACEHOLDER|$PDFDING_HOSTNAME|g" "$COMPOSE_FILE"
    echo -e "[INFO] Updated HOST_NAME in compose file"
else
    echo -e "[WARNING] Compose file not found: $COMPOSE_FILE"
fi

# Stop and recreate the container to apply changes
echo -e "[INFO] Recreating PdfDing container with updated configuration..."
f_stop_containers "$APP_SNAME"
sleep 2
f_docker_compose_recreate "$APP_SNAME" "06"

echo -e "[INFO] PdfDing hostname configuration complete"
