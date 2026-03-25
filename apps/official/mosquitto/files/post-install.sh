#!/bin/bash
# Mosquitto post-install hook
# Fixes permissions, hashes user password, and recreates container

APP_SNAME="mosquitto"
APP_PNAME="Mosquitto"

f_print_step "1/3" "Fixing permissions for $APP_PNAME..."
f_print_substep "Setting permissions on: $DOCKER_FOLDER/appdata/mosquitto/"
sudo chmod -R 0700 "$DOCKER_FOLDER/appdata/mosquitto/"
sudo chown -R 1000:root "$DOCKER_FOLDER/appdata/mosquitto/"

f_print_step "2/3" "Hashing $APP_PNAME password..."
f_print_substep "You may ignore any warning below from mosquitto_passwd"
MQTT_USER=$(sudo cat "$DOCKER_FOLDER/secrets/mosquitto_username")
MQTT_PASS=$(sudo cat "$DOCKER_FOLDER/secrets/mosquitto_password")
sudo docker exec -i mosquitto sh -c "exec mosquitto_passwd -b /mosquitto/config/passwd $MQTT_USER $MQTT_PASS"
echo

f_print_step "3/3" "Recreating $APP_PNAME container..."
f_docker_compose_recreate "mosquitto" "06"

f_print_success "$APP_PNAME configuration complete"
