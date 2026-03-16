#!/bin/bash
# cAdvisor pre-install hook
# Uncomments /dev/kmsg device mapping if the device exists on the host
# PORTED FROM: v5.11.1 dpf5111:9629-9632

if [[ -c /dev/kmsg || -f /dev/kmsg ]]; then
	dev_echo "Activating /dev/kmsg device for cadvisor"
	f_sed_replace "    # devices:" "    devices:" "$DOCKER_FOLDER/compose/$HOSTNAME/cadvisor.yml"
	f_sed_replace "    #   - /dev/kmsg" "      - /dev/kmsg" "$DOCKER_FOLDER/compose/$HOSTNAME/cadvisor.yml"
fi
