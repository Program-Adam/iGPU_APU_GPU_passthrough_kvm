#!/usr/bin/env bash
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

# --- Re-run as root if needed ---
if [[ $EUID -ne 0 ]]; then
  echo "Re-running with sudo..."
  exec sudo bash "$0" "$@"
fi

echo "Reverting VFIO passthrough setup... returning GPU to host drivers."

# Paths
GRUB_FILE="/etc/default/grub"
VFIO_CONF="/etc/modprobe.d/vfio.conf"
BLACKLIST_CONF="/etc/modprobe.d/blacklist-nvidia.conf"
INITRAMFS_MODULES="/etc/initramfs-tools/modules"


# --- 1) Unmask gpu-manager.service (so host can reconfigure GPU) ---
if systemctl is-enabled --quiet gpu-manager.service 2>/dev/null; then
  echo "gpu-manager.service already enabled."
else
  echo "Unmasking gpu-manager.service..."
  systemctl unmask gpu-manager.service || true
fi

# --- 2) Remove VFIO config ---
if [[ -f "$VFIO_CONF" ]]; then
  rm -f "$VFIO_CONF"
  echo "Removed $VFIO_CONF"
fi

# --- 3) Remove NVIDIA/ nouveau blacklist ---
if [[ -f "$BLACKLIST_CONF" ]]; then
  rm -f "$BLACKLIST_CONF"
  echo "Removed $BLACKLIST_CONF"
fi

# --- 4) Clean VFIO modules from initramfs/modules ---
if [[ -f "$INITRAMFS_MODULES" ]]; then
  sed -i '/^vfio$/d;/^vfio_iommu_type1$/d;/^vfio_pci$/d;/^vfio_virqfd$/d' "$INITRAMFS_MODULES"
  echo "Removed VFIO modules from $INITRAMFS_MODULES"
fi

# --- 5) Remove kernel parameters from GRUB ---
if [[ -f "$GRUB_FILE" ]]; then
  current=$(sed -n 's/^GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)".*/\1/p' "$GRUB_FILE" || true)

  # Parameters we want to strip
  REMOVE_PARAMS=(amd_iommu=on iommu=pt vfio-pci.ids= vfio-pci.disable_vga=1 modprobe.blacklist=)

  for p in "${REMOVE_PARAMS[@]}"; do
    current=$(echo "$current" | sed "s/$p[^ ]*//g")
  done

  current="$(echo "$current" | xargs)" # trim whitespace

  sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$current\"|" "$GRUB_FILE"
  echo "Cleaned kernel params in $GRUB_FILE"
fi

# --- 6) Rebuild initramfs & grub ---
update-initramfs -u -k "$(uname -r)"
update-grub

echo "Revert complete."
echo ""
echo "Now reboot. After reboot, check:"
echo "  lspci -nnk | grep -A 3 VGA"
echo "  lsmod | grep nvidia   (should show NVIDIA driver loaded if installed)"
exit 0
