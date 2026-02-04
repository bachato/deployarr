#!/bin/bash
# ZeroTier post-install script
# Joins the ZeroTier network if NETWORKID was provided

if [[ -n "$ZEROTIER_NETWORKID" ]]; then
    echo "Connecting Docker Host to ZeroTier network $ZEROTIER_NETWORKID..."

    # Wait a moment for the container to fully initialize
    sleep 2

    ZEROTIER_CONNECTION_STATUS="$(sudo docker exec zerotier zerotier-cli join "$ZEROTIER_NETWORKID" 2>/dev/null)"

    if [[ "${ZEROTIER_CONNECTION_STATUS}" == "200"* ]]; then
        echo -e "${GREEN}Successfully joined ZeroTier network.${ENDCOLOR}"
        echo -e "${YELLOW}[NOTE]${ENDCOLOR} Remember to authorize this device in ZeroTier Central."
    else
        echo -e "${RED}[WARNING]${ENDCOLOR} Failed to join ZeroTier network. Status: $ZEROTIER_CONNECTION_STATUS"
        echo "You can manually join later with: sudo docker exec zerotier zerotier-cli join $ZEROTIER_NETWORKID"
    fi
else
    echo -e "${YELLOW}[NOTE]${ENDCOLOR} No Network ID provided. To join a network later, run:"
    echo "sudo docker exec zerotier zerotier-cli join YOUR_NETWORK_ID"
fi
