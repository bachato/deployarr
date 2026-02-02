#!/bin/bash
# Mosquitto post-install hook
# Creates empty files, hashes password, fixes permissions, and recreates container

# Create empty passwd file if it doesn't exist
sudo touch "$DOCKER_FOLDER/appdata/mosquitto/config/passwd"
sudo touch "$DOCKER_FOLDER/appdata/mosquitto/log/mosquitto.log"

# Wait for container to be ready
f_blank_line_sleep 5

# Hash the Mosquitto password
echo
f_print_info "Hashing Mosquitto password (you may ignore the warning below)..."
MQTT_USER=$(sudo cat "$DOCKER_FOLDER/secrets/mosquitto_username")
MQTT_PASS=$(sudo cat "$DOCKER_FOLDER/secrets/mosquitto_password")
sudo docker exec -i mosquitto sh -c "exec mosquitto_passwd -b /mosquitto/config/passwd $MQTT_USER $MQTT_PASS"

# Fix permissions
echo
f_print_info "Fixing permissions..."
sudo chmod -R 0700 "$DOCKER_FOLDER/appdata/mosquitto/"
sudo chown -R 1883:root "$DOCKER_FOLDER/appdata/mosquitto/"

# Recreate container to apply permission changes
echo
f_print_info "Recreating Mosquitto to apply changes..."
f_docker_compose_recreate "mosquitto" "06"
