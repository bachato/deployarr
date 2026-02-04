#!/bin/bash
# WG-Easy post-install hook
# Hashes password with bcrypt and updates compose file

APP_SNAME="wg-easy"
APP_PNAME="WG-Easy"
COMPOSE_FILE="$DOCKER_FOLDER/compose/$HOSTNAME/$APP_SNAME.yml"

f_print_step "1/3" "Reading $APP_PNAME password from secrets..."
WGEASY_PASSWORD=$(sudo cat "$DOCKER_FOLDER/secrets/wgeasy_password")
echo

f_print_step "2/3" "Hashing password with bcrypt..."
# Hash password using htpasswd (bcrypt with cost 10)
WGEASY_PASSWORD_HASH=$(htpasswd -bnBC 10 "" "$WGEASY_PASSWORD" | tr -d ':\n')
f_print_substep "Password hashed successfully"
echo

f_print_step "3/3" "Updating compose file with password hash..."
# Replace placeholder with hashed password
sudo sed -i "s|WG-EASY-PASSWORD-HASH-PLACEHOLDER|$WGEASY_PASSWORD_HASH|g" "$COMPOSE_FILE"
# Escape $ signs for Docker Compose (bcrypt hashes contain $ characters)
if ! grep -q 'PASSWORD_HASH=\$\$' "$COMPOSE_FILE"; then
    f_print_substep "Escaping special characters in password hash"
    sudo sed -i '/.*PASSWORD_HASH.*/s/\$/\$\$/g' "$COMPOSE_FILE"
fi
echo

f_print_step "4/4" "Recreating $APP_PNAME container with hashed password..."
f_docker_compose_recreate "$APP_SNAME" "06"

f_print_success "$APP_PNAME password configuration complete"
