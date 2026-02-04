#!/bin/bash
# qBittorrent VPN pre-install hook
# Creates the appdata directory structure needed before config file copy
# Removes old config to ensure fresh configuration on reinstall

# Create directory structure
mkdir -p "$DOCKER_FOLDER/appdata/qbittorrent-vpn/qBittorrent"

# Remove old config file if exists (ensures fresh config on reinstall)
sudo rm -f "$DOCKER_FOLDER/appdata/qbittorrent-vpn/qBittorrent/qBittorrent.conf" 2>/dev/null
