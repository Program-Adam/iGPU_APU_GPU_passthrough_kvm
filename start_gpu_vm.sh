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
VM_WAS_RUNNING=true

if ! virsh list --name | grep -qx "$VM_NAME"; then
    echo "Starting VM $VM_NAME..."
    # Only call sudo if needed
    if ! sudo virsh start "$VM_NAME"; then
        echo "Failed to start VM $VM_NAME. Make sure you have permission."
        exit 1
    fi
    VM_WAS_RUNNING=false
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
        # Only use sudo if needed
        sudo chown "$USER:kvm" "$FILE"
        sudo chmod 660 "$FILE"
    fi
fi

# --- Wait if the VM was just started ---
if [ "$VM_WAS_RUNNING" = false ]; then
    echo "Waiting 5 seconds for VM to initialize..."
    sleep 5
fi

# --- Wait for Looking Glass server ---
echo "Waiting for Looking Glass server to create $FILE..."
while [ ! -e "$FILE" ]; do
    sleep 5
done

echo "$FILE is now available. Launching Looking Glass client..."
looking-glass-client -m KEY_RIGHTCTRL
exit 0
