#!/bin/bash
# PdfDing Post-Install Hook
# Modifies the compose file to set the correct HOST_NAME value
#
# HOST_NAME in compose.yml: ${SERVER_LAN_IP},PDFDING_HOSTNAME_PLACEHOLDER
# - SERVER_LAN_IP is always included
# - PDFDING_HOSTNAME_PLACEHOLDER is replaced with subdomain.domain ONLY if:
#   1. Traefik is running with production status
#   2. A file provider was created for this app

APP_SNAME="pdfding"
APP_PNAME="PdfDing"
COMPOSE_FILE="$DOCKER_FOLDER/compose/$HOSTNAME/$APP_SNAME.yml"
FILE_PROVIDER_PATH="$DOCKER_FOLDER/appdata/traefik3/rules/$HOSTNAME/app-$APP_SNAME.yml"

f_print_step "1/2" "Configuring $APP_PNAME hostname..."

# Check if Traefik is running with production status and file provider exists
TRAEFIK_RUNNING=$(sudo docker ps --filter "name=^traefik$" --filter "status=running" -q 2>/dev/null)
TRAEFIK_PRODUCTION_STATUS="$DEPLOYRR_CONFIG/status/04_traefik_production_status"

if [[ -n "$TRAEFIK_RUNNING" && -f "$TRAEFIK_PRODUCTION_STATUS" && -f "$FILE_PROVIDER_PATH" && -n "$FILE_PROVIDER_APP_SUBDOMAIN" && -n "$DOMAINNAME_1" ]]; then
    # Traefik is running with file provider - add subdomain.domain
    PDFDING_HOSTNAME="${FILE_PROVIDER_APP_SUBDOMAIN}.${DOMAINNAME_1}"
    f_print_substep "Traefik file provider found: $FILE_PROVIDER_PATH"
    f_print_substep "Adding hostname: $PDFDING_HOSTNAME"

    if [[ -f "$COMPOSE_FILE" ]]; then
        sudo sed -i "s|PDFDING_HOSTNAME_PLACEHOLDER|$PDFDING_HOSTNAME|g" "$COMPOSE_FILE"
        f_print_substep "Updated HOST_NAME in: $COMPOSE_FILE"
        f_print_substep "HOST_NAME set to: \$SERVER_LAN_IP,$PDFDING_HOSTNAME"
    else
        f_print_warning "Compose file not found: $COMPOSE_FILE"
    fi
else
    # No Traefik/file provider - remove placeholder and comma
    f_print_substep "No Traefik file provider configured"
    f_print_substep "Using SERVER_LAN_IP only for HOST_NAME"

    if [[ -f "$COMPOSE_FILE" ]]; then
        sudo sed -i "s|,PDFDING_HOSTNAME_PLACEHOLDER||g" "$COMPOSE_FILE"
        f_print_substep "Updated HOST_NAME in: $COMPOSE_FILE"
    else
        f_print_warning "Compose file not found: $COMPOSE_FILE"
    fi
fi
echo

# Stop and recreate the container to apply changes
f_print_step "2/2" "Recreating $APP_PNAME container with updated configuration..."
f_stop_containers "$APP_SNAME"
sleep 2
f_docker_compose_recreate "$APP_SNAME" "06"

f_print_success "$APP_PNAME hostname configuration complete"
