#!/bin/bash
# Revert NVIDIA blacklist and VFIO passthrough setup

set -euo pipefail

# Check if running as root; if not, re-run with sudo
if [[ $EUID -ne 0 ]]; then
    echo "Not running as root. Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

# Remove NVIDIA blacklist
BLACKLIST_FILE="/etc/modprobe.d/blacklist-nvidia.conf"
if [[ -f "$BLACKLIST_FILE" ]]; then
    echo "Removing NVIDIA blacklist file..."
    rm -f "$BLACKLIST_FILE"
else
    echo "NVIDIA blacklist file not found, skipping..."
fi

# Remove VFIO config
VFIO_FILE="/etc/modprobe.d/vfio.conf"
if [[ -f "$VFIO_FILE" ]]; then
    echo "Removing VFIO configuration file..."
    rm -f "$VFIO_FILE"
else
    echo "VFIO config file not found, skipping..."
fi

# Remove VFIO modules from initramfs-tools/modules
VFIO_MODULES=("vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd")
for module in "${VFIO_MODULES[@]}"; do
    if grep -Fxq "$module" /etc/initramfs-tools/modules; then
        echo "Removing $module from /etc/initramfs-tools/modules..."
        sed -i "\|^$module\$|d" /etc/initramfs-tools/modules
    else
        echo "$module not found in modules file, skipping..."
    fi
done

echo "Updating initramfs..."
update-initramfs -u

echo "Revert complete. Reboot your system to apply changes."
exit 0

