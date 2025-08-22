#!/bin/bash
# Full setup: Blacklist NVIDIA and configure VFIO for NVIDIA GPU passthrough

set -euo pipefail

# Check if running as root; if not, re-run with sudo
if [[ $EUID -ne 0 ]]; then
    echo "Not running as root. Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

echo "Creating NVIDIA blacklist..."
cat <<EOF > /etc/modprobe.d/blacklist-nvidia.conf
# Blacklist NVIDIA drivers to prevent them from loading
blacklist nvidia
blacklist nouveau
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidiafb
EOF


echo "Add VFIO blacklist..."
cat <<EOF > /etc/modprobe.d/vfio.conf
# Bind NVIDIA GPU to VFIO for passthrough (replace IDs with "lspci -nn | grep -A3 VGA" output if needed)
softdep nouveau pre: vfio-pci
softdep nvidia pre: vfio-pci
options vfio-pci ids=10de:2d04,10de:22eb disable_vga=1
EOF


echo "Appending VFIO modules to initramfs-tools/modules..."
VFIO_MODULES=("vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd")

for module in "${VFIO_MODULES[@]}"; do
    if ! grep -Fxq "$module" /etc/initramfs-tools/modules; then
        echo "$module" >> /etc/initramfs-tools/modules
        echo "Added $module"
    else
        echo "$module already exists, skipping"
    fi
done

echo "Updating initramfs..."
update-initramfs -u

echo "Setup complete. Reboot your system to apply changes."
exit 0
