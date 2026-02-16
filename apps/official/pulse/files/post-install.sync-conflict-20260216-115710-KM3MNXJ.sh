#!/bin/bash
# Pulse post-install hook
# Retrieves bootstrap token and saves it as a secret

APP_SNAME="pulse"
APP_PNAME="Pulse"

f_print_step "1/2" "Waiting for $APP_PNAME to generate bootstrap token..."
f_blank_line_sleep 5

f_print_step "2/2" "Retrieving $APP_PNAME bootstrap token..."
PULSE_TOKEN=$(sudo docker exec pulse cat /data/.bootstrap_token 2>/dev/null)

if [[ -n "$PULSE_TOKEN" ]]; then
    # Save token as a secret
    sudo mkdir -p "$DOCKER_FOLDER/secrets" 2>/dev/null
    sudo truncate -s 0 "$DOCKER_FOLDER/secrets/pulse_bootstrap_token" 2>/dev/null
    echo -n "$PULSE_TOKEN" | sudo tee "$DOCKER_FOLDER/secrets/pulse_bootstrap_token" >/dev/null
    f_set_root_600 "$DOCKER_FOLDER/secrets/pulse_bootstrap_token"

    echo
    echo -e "${GREEN}Bootstrap token retrieved and saved.${ENDCOLOR}"
    echo -e "${CYAN}Token:${ENDCOLOR} ${YELLOW}${PULSE_TOKEN}${ENDCOLOR}"
    echo -e "${CYAN}Saved to:${ENDCOLOR} $DOCKER_FOLDER/secrets/pulse_bootstrap_token"
else
    echo
    echo -e "${RED}[WARNING]${ENDCOLOR} Could not retrieve bootstrap token."
    echo "You can retrieve it manually with: sudo docker exec pulse cat /data/.bootstrap_token"
fi
