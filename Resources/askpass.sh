#!/bin/bash
# SSH_ASKPASS helper for Open Stack Menu
# Retrieves SSH password from macOS Keychain based on server ID
# Supports Touch ID when biometric access control is set on the item

SERVER_ID="$SSH_OPM_SERVER_ID"
if [ -z "$SERVER_ID" ]; then
    exit 1
fi

# Retrieve password from Keychain
# If the item has Touch ID access control, this triggers the system auth dialog
security find-generic-password -s "com.openstackmenu.OpenStackMenu.ssh" -a "$SERVER_ID" -w 2>/dev/null
