#!/bin/bash
# SABnzbd Post-Install Script
# Adds domain and container name to SABnzbd whitelist for Traefik access

APP_SNAME="sabnzbd"
APP_PNAME="SABnzbd"
INI_FILE="$DOCKER_FOLDER/appdata/sabnzbd/sabnzbd.ini"

f_print_step "1/3" "Waiting for $APP_PNAME config to be created..."
f_print_substep "Waiting 5 seconds for $INI_FILE"
sleep 5
echo

f_print_step "2/3" "Configuring $APP_PNAME whitelist..."
f_print_substep "Stopping $APP_PNAME container"
sudo docker stop "$APP_SNAME" >/dev/null 2>&1
sleep 3

# Get container ID for whitelist
SABNZBD_CONTAINER_ID=$(sudo docker ps -aqf "name=^${APP_SNAME}$" 2>/dev/null || echo "")

if [[ -n "$SABNZBD_CONTAINER_ID" && -f "$INI_FILE" ]]; then
    f_print_substep "Adding to whitelist: ${FILE_PROVIDER_APP_SUBDOMAIN}.${DOMAINNAME_1}"
    f_print_substep "Editing: $INI_FILE"
    # Add domain and app name to the whitelist (host_whitelist line)
    f_safe_sed "s/${SABNZBD_CONTAINER_ID},/${SABNZBD_CONTAINER_ID},${FILE_PROVIDER_APP_SUBDOMAIN}.${DOMAINNAME_1},${APP_SNAME}/g" "$INI_FILE"
else
    f_print_substep "Container ID or config file not found, skipping whitelist update"
fi
sleep 3
echo

f_print_step "3/3" "Restarting $APP_PNAME..."
sudo docker start "$APP_SNAME" >/dev/null 2>&1
f_print_success "$APP_PNAME whitelist configuration complete"
