#!/bin/bash
# Sshwifty pre-install hook
# Configures the sshwifty.conf.json with password and SSH preset details

CONFIG_FILE="$DOCKER_FOLDER/appdata/sshwifty/conf.json"

# Read password from secret file
SSHWIFTY_PASSWORD=""
if sudo test -f "$DOCKER_FOLDER/secrets/sshwifty_password"; then
    SSHWIFTY_PASSWORD=$(sudo cat "$DOCKER_FOLDER/secrets/sshwifty_password")
fi

# Replace password placeholder
if [[ -n "$SSHWIFTY_PASSWORD" ]]; then
    f_sed_replace "WEB_ACCESS_PASSWORD" "$SSHWIFTY_PASSWORD" "$CONFIG_FILE"
fi

# Detect SSH port
ssh_port=$(sudo ss -tlnp 2>/dev/null | grep sshd | awk '{print $4}' | grep -oE '[0-9]+$' | head -1)
if [[ -z "$ssh_port" ]]; then
    # Fallback: try netstat
    ssh_port=$(sudo netstat -tlnp 2>/dev/null | grep sshd | awk '{print $4}' | grep -oE '[0-9]+$' | head -1)
fi

# Configure SSH preset if port detected
if [[ "$ssh_port" =~ ^[0-9]+$ ]] && [[ "$ssh_port" -ge 1 ]] && [[ "$ssh_port" -le 65535 ]]; then
    f_sed_replace "PORT-PLACEHOLDER" "$ssh_port" "$CONFIG_FILE"
    f_sed_replace "HOSTNAME-PLACEHOLDER" "$HOSTNAME" "$CONFIG_FILE"
    f_sed_replace "USER-PLACEHOLDER" "$USERNAME" "$CONFIG_FILE"
fi

# Set secure permissions on config file (contains password)
sudo chmod 600 "$CONFIG_FILE"
sudo chown "$USERNAME:$USERNAME" "$CONFIG_FILE"
