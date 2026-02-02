#!/bin/bash
# Tautulli pre-install hook
# Uncomments Plex logs volume if Plex is installed
# PORTED FROM: v5.11.1 dpf5111:8449-8452

if [[ "${APP_STATUS_plex}" == "- \Z2RUNNING\Zn"* || -d "$DOCKER_FOLDER/appdata/plex/Library" ]]; then
	dev_echo "Activating Plex logs volume for Tautulli"
	f_sed_replace "      # - \$DOCKERDIR/appdata/plex/Library" "      - \$DOCKERDIR/appdata/plex/Library" "$DOCKER_FOLDER/apps/official/tautulli/compose.yml"
fi
