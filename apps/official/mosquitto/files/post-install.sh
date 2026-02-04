#!/bin/bash
# Mosquitto post-install hook
# Creates empty files, hashes password, fixes permissions, and recreates container

APP_SNAME="mosquitto"
APP_PNAME="Mosquitto"

f_print_step "1/4" "Creating $APP_PNAME configuration files..."
f_print_substep "Creating: $DOCKER_FOLDER/appdata/mosquitto/config/passwd"
sudo touch "$DOCKER_FOLDER/appdata/mosquitto/config/passwd"
f_print_substep "Creating: $DOCKER_FOLDER/appdata/mosquitto/log/mosquitto.log"
sudo touch "$DOCKER_FOLDER/appdata/mosquitto/log/mosquitto.log"
echo

f_print_step "2/4" "Waiting for $APP_PNAME container to be ready..."
f_blank_line_sleep 5
echo

f_print_step "3/4" "Hashing $APP_PNAME password..."
f_print_substep "You may ignore any warning below from mosquitto_passwd"
MQTT_USER=$(sudo cat "$DOCKER_FOLDER/secrets/mosquitto_username")
MQTT_PASS=$(sudo cat "$DOCKER_FOLDER/secrets/mosquitto_password")
sudo docker exec -i mosquitto sh -c "exec mosquitto_passwd -b /mosquitto/config/passwd $MQTT_USER $MQTT_PASS"
echo

f_print_step "4/4" "Fixing permissions and recreating container..."
f_print_substep "Setting permissions on: $DOCKER_FOLDER/appdata/mosquitto/"
sudo chmod -R 0700 "$DOCKER_FOLDER/appdata/mosquitto/"
sudo chown -R 1883:root "$DOCKER_FOLDER/appdata/mosquitto/"
f_print_substep "Recreating $APP_PNAME container"
f_docker_compose_recreate "mosquitto" "06"

f_print_success "$APP_PNAME configuration complete"
