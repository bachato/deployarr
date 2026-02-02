#!/bin/bash
# SABnzbd Post-Install Script
# Adds domain and container name to SABnzbd whitelist for Traefik access

APP_SNAME="sabnzbd"
APP_PNAME="SABnzbd"
INI_FILE="$DOCKER_FOLDER/appdata/sabnzbd/sabnzbd.ini"

# Wait for config to be created
sleep 5

# Stop the container
echo -e "Stopping $APP_PNAME to configure whitelist..."
sudo docker stop "$APP_SNAME" >/dev/null 2>&1

sleep 3

# Get container ID for whitelist
SABNZBD_CONTAINER_ID=$(sudo docker ps -aqf "name=^${APP_SNAME}$" 2>/dev/null || echo "")

if [[ -n "$SABNZBD_CONTAINER_ID" && -f "$INI_FILE" ]]; then
    echo -e "Adding $FILE_PROVIDER_APP_SUBDOMAIN.$DOMAINNAME_1 to $APP_PNAME whitelist..."
    # Add domain and app name to the whitelist (host_whitelist line)
    sudo sed -i "s/${SABNZBD_CONTAINER_ID},/${SABNZBD_CONTAINER_ID},${FILE_PROVIDER_APP_SUBDOMAIN}.${DOMAINNAME_1},${APP_SNAME}/g" "$INI_FILE"
fi

sleep 3

# Restart the container
echo -e "Starting $APP_PNAME..."
sudo docker start "$APP_SNAME" >/dev/null 2>&1
