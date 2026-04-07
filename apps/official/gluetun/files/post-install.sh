#!/bin/bash
# Gluetun post-install hook
# Handles conditional VPN type configuration and connection verification

APP_SNAME="gluetun"
APP_PNAME="Gluetun"
APP_COMPOSE_FILE="$DOCKER_FOLDER/compose/$HOSTNAME/$APP_SNAME.yml"

# Get VPN type from environment
VPN_TYPE="$GLUETUN_VPN_TYPE"

f_print_step "1/4" "Configuring $APP_PNAME for $VPN_TYPE..."
echo

if [[ "$VPN_TYPE" == "wireguard" ]]; then
    f_print_substep "Collecting WireGuard credentials"

    # Prompt for WireGuard-specific variables
    f_update_envars "GLUETUN_WIREGUARD_PRIVATE_KEY" "$GLUETUN_WIREGUARD_PRIVATE_KEY" "Enter the \\Z2Private Key\\Zn from the configuration provided by the Provider:"
    f_update_envars "GLUETUN_WIREGUARD_ADDRESSES" "$GLUETUN_WIREGUARD_ADDRESSES" "Enter the \\Z2Wireguard Addresses\\Zn from the configuration provided by the Provider (usually of the format XX.XX.XX.XX/XX):"

    # Uncomment WireGuard lines in compose file
    f_print_step "2/4" "Updating compose file for WireGuard..."
    f_sed_replace "# WIREGUARD_PRIVATE_KEY:" "WIREGUARD_PRIVATE_KEY:" "$APP_COMPOSE_FILE"
    f_sed_replace "# WIREGUARD_ADDRESSES:" "WIREGUARD_ADDRESSES:" "$APP_COMPOSE_FILE"
    echo

elif [[ "$VPN_TYPE" == "openvpn" ]]; then
    f_print_substep "Collecting OpenVPN credentials"

    # Prompt for OpenVPN-specific variables
    f_update_envars "GLUETUN_OPENVPN_USERNAME" "$GLUETUN_OPENVPN_USERNAME" "Enter the \\Z2OpenVPN Username\\Zn from the Provider:"
    f_update_envars "GLUETUN_OPENVPN_PASSWORD" "$GLUETUN_OPENVPN_PASSWORD" "Enter the \\Z2OpenVPN Password\\Zn from the Provider:"

    # Uncomment OpenVPN lines in compose file
    f_print_step "2/4" "Updating compose file for OpenVPN..."
    f_sed_replace "# OPENVPN_USER:" "OPENVPN_USER:" "$APP_COMPOSE_FILE"
    f_sed_replace "# OPENVPN_PASSWORD:" "OPENVPN_PASSWORD:" "$APP_COMPOSE_FILE"
    echo

else
    f_print_warning "Unknown VPN type: $VPN_TYPE. Please verify your configuration."
fi

f_print_step "3/4" "Recreating $APP_PNAME container with VPN configuration..."
f_docker_compose_recreate "$APP_SNAME" "06"
echo

f_print_step "4/4" "Waiting for $APP_PNAME to connect to VPN..."
TIMEOUT=0
TIMEOUT_LIMIT=60
GLUETUN_CONNECTED="false"

while [[ "$GLUETUN_CONNECTED" != "true" ]]; do
    if [[ $TIMEOUT -ge $TIMEOUT_LIMIT ]]; then
        f_print_error "Timed out after ${TIMEOUT_LIMIT}s. Could not verify VPN connection."
        f_print_warning "Check container logs with: sudo docker logs gluetun"
        break
    fi

    # Check if container is running
    CONTAINER_RUNNING="$(sudo docker container inspect -f '{{.State.Running}}' gluetun 2>/dev/null)"
    if [[ "$CONTAINER_RUNNING" == "true" ]]; then
        # Check logs for successful VPN connection
        if sudo docker logs gluetun 2>&1 | grep -q "Public IP address is"; then
            GLUETUN_CONNECTED="true"
            PUBLIC_IP=$(sudo docker logs gluetun 2>&1 | grep "Public IP address is" | tail -1 | sed 's/.*Public IP address is //')
            f_print_success "VPN connected successfully!"
            f_print_substep "Public IP: $PUBLIC_IP"
        fi
    fi

    ((TIMEOUT++))
    sleep 1
done

echo
f_print_success "$APP_PNAME configuration complete"
