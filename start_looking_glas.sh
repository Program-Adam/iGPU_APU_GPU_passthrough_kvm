#!/bin/bash

# Relaunch in Konsole if not already running there
if [ -z "$KONSOLE_DBUS_SERVICE" ]; then
    konsole -e "$0"
    exit
fi

# Show /dev/shm contents
ls -lh /dev/shm

# Check if /dev/shm/looking-glass has correct ownership and permissions
FILE="/dev/shm/looking-glass"
NEEDED_PERMS="660"
NEEDED_OWNER="$USER"
NEEDED_GROUP="kvm"

CURRENT_OWNER=$(stat -c '%U' "$FILE")
CURRENT_GROUP=$(stat -c '%G' "$FILE")
CURRENT_PERMS=$(stat -c '%a' "$FILE")

if [ "$CURRENT_OWNER" != "$NEEDED_OWNER" ] || [ "$CURRENT_GROUP" != "$NEEDED_GROUP" ] || [ "$CURRENT_PERMS" != "$NEEDED_PERMS" ]; then
    echo "Fixing permissions for $FILE..."
    sudo chown $USER:kvm "$FILE"
    sudo chmod 660 "$FILE"
fi

# Launch Looking Glass client
looking-glass-client -m KEY_RIGHTCTRL
