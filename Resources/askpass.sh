#!/bin/bash
# SSH_ASKPASS helper for Open Stack Menu
# Retrieves SSH password from macOS Keychain based on server ID

SERVER_ID="$SSH_OPM_SERVER_ID"
if [ -z "$SERVER_ID" ]; then
    exit 1
fi

# Retrieve password from Keychain
security find-generic-password -s "com.openstackmenu.OpenStackMenu.ssh" -a "$SERVER_ID" -w 2>/dev/null
