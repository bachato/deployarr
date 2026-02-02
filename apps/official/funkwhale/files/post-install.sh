#!/bin/bash
# Funkwhale post-install hook
# Creates the initial superuser account via interactive prompt

echo
f_print_note "Creating Funkwhale superuser account..."
f_blank_line_sleep 5
sudo docker exec -ti funkwhale manage createsuperuser
