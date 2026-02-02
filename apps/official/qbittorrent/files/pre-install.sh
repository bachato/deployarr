#!/bin/bash
# qBittorrent pre-install hook
# Creates the appdata directory structure needed before config file copy

mkdir -p "$DOCKER_FOLDER/appdata/qbittorrent/qBittorrent"
