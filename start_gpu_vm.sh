#!/bin/bash
set -euo pipefail

# --- Detect if running in terminal; if not, relaunch in Konsole ---
if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    if command -v konsole >/dev/null 2>&1; then
        exec konsole -e bash -c "\"$0\" \"$@\"; echo; read -p 'Press Enter to exit...'"
    else
        echo "This script must be run in a terminal."
        exit 1
    fi
fi



# --- Start KVM VM ---
VM_NAME="win11-main"

# Check if the VM is already running
if ! virsh list --name | grep -qx "$VM_NAME"; then
    echo "Starting VM $VM_NAME..."
    sudo virsh start "$VM_NAME"
else
    echo "VM $VM_NAME is already running."
fi

# --- Show /dev/shm contents ---
ls -lh /dev/shm

# --- Check /dev/shm/looking-glass ownership and permissions ---
FILE="/dev/shm/looking-glass"
NEEDED_PERMS="660"
NEEDED_OWNER="$USER"
NEEDED_GROUP="kvm"

if [[ -e "$FILE" ]]; then
    CURRENT_OWNER=$(stat -c '%U' "$FILE")
    CURRENT_GROUP=$(stat -c '%G' "$FILE")
    CURRENT_PERMS=$(stat -c '%a' "$FILE")

    if [[ "$CURRENT_OWNER" != "$NEEDED_OWNER" ]] || [[ "$CURRENT_GROUP" != "$NEEDED_GROUP" ]] || [[ "$CURRENT_PERMS" != "$NEEDED_PERMS" ]]; then
        echo "Fixing permissions for $FILE..."
        sudo chown "$USER:kvm" "$FILE"
        sudo chmod 660 "$FILE"
    fi
else
    echo "$FILE does not exist yet. Make sure the VM is running and Looking Glass server is active."
fi

# --- Launch Looking Glass client ---
looking-glass-client -m KEY_RIGHTCTRL
exit 0