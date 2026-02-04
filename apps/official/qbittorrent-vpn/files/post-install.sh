#!/bin/bash
# Post-install script for qBittorrent VPN
# Configures Gluetun to expose the qBittorrent VPN port

APP_SNAME="qbittorrent-vpn"
APP_PNAME="qBittorrent VPN"

# Gluetun compose file location
GLUETUN_COMPOSE="$DOCKER_FOLDER/compose/$HOSTNAME/gluetun.yml"

f_print_step "1/4" "Configuring Gluetun port mapping..."

if [[ ! -f "$GLUETUN_COMPOSE" ]]; then
    f_print_error "Gluetun compose file not found: $GLUETUN_COMPOSE"
    return 1
fi

# Check if port mapping already exists (uncommented)
if grep -q "^\s*-\s*\$QBITTORRENTVPN_PORT:8080" "$GLUETUN_COMPOSE" 2>/dev/null; then
    f_print_substep "Port mapping already configured"
else
    # Uncomment the ports section if commented
    if grep -q "^\s*#\s*ports:" "$GLUETUN_COMPOSE" 2>/dev/null; then
        f_print_substep "Enabling ports section in Gluetun"
        sudo sed -i 's/^\(\s*\)#\s*ports:/\1ports:/' "$GLUETUN_COMPOSE"
    fi

    # Uncomment the qbittorrent-vpn port if it exists commented
    if grep -q "^\s*#.*\$QBITTORRENTVPN_PORT:8080" "$GLUETUN_COMPOSE" 2>/dev/null; then
        f_print_substep "Enabling qBittorrent VPN port mapping"
        sudo sed -i 's/^\(\s*\)#\s*-\s*\$QBITTORRENTVPN_PORT:8080/\1- \$QBITTORRENTVPN_PORT:8080/' "$GLUETUN_COMPOSE"
    elif ! grep -q "QBITTORRENTVPN_PORT:8080" "$GLUETUN_COMPOSE" 2>/dev/null; then
        # Port mapping doesn't exist, add it after the ports: line
        f_print_substep "Adding qBittorrent VPN port mapping to Gluetun"
        sudo sed -i '/^\s*ports:/a\      - $QBITTORRENTVPN_PORT:8080 # qBittorrent VPN' "$GLUETUN_COMPOSE"
    fi
fi
echo

f_print_step "2/4" "Stopping $APP_PNAME..."
f_stop_containers "$APP_SNAME"
echo

f_print_step "3/4" "Restarting Gluetun to apply port mapping..."
f_docker_compose_recreate "gluetun" "06"
echo

f_print_step "4/4" "Starting $APP_PNAME..."
f_start_containers "$APP_SNAME"
echo

f_print_success "$APP_PNAME configuration complete"
