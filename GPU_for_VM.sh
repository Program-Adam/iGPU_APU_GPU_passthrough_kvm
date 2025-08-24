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

# --- Mask Ubuntu's GPU manager (conflicts with passthrough) ---
if systemctl is-enabled --quiet gpu-manager.service 2>/dev/null; then
  echo "Masking gpu-manager.service..."
  systemctl mask gpu-manager.service
fi

# --- Ensure AMD GPU is used for host (example PCI bus: adjust to your system) ---
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/10-amdgpu.conf <<'EOF'
Section "Device"
    Identifier "AMD"
    Driver "amdgpu"
    BusID "PCI:7:0:0"
EndSection
EOF
echo "Wrote /etc/X11/xorg.conf.d/10-amdgpu.conf"

# --- CONFIG: set this to the vendor:device IDs from `lspci -nn` ---
GPU_IDS="10de:2d04,10de:22eb"
echo "Using GPU_IDS=$GPU_IDS"

# Useful paths
GRUB_FILE="/etc/default/grub"
VFIO_CONF="/etc/modprobe.d/vfio.conf"
BLACKLIST_CONF="/etc/modprobe.d/blacklist-nvidia.conf"
INITRAMFS_MODULES="/etc/initramfs-tools/modules"

# --- 1) Blacklist NVIDIA + nouveau ---
cat > "$BLACKLIST_CONF" <<'EOF'
# Prevent vendor drivers from grabbing the GPU intended for passthrough
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nouveau

# Stronger prevention
install nvidia /bin/false
install nvidia_drm /bin/false
install nvidia_modeset /bin/false
install nouveau /bin/false
EOF
echo "Wrote $BLACKLIST_CONF"

# --- 2) VFIO modprobe config ---
cat > "$VFIO_CONF" <<EOF
options vfio-pci ids=$GPU_IDS disable_vga=1
softdep nouveau pre: vfio-pci
softdep nvidia pre: vfio-pci
EOF
echo "Wrote $VFIO_CONF"

# --- 3) Add VFIO modules to initramfs ---
VFIO_MODULES=(vfio vfio_iommu_type1 vfio_pci vfio_virqfd)
for m in "${VFIO_MODULES[@]}"; do
  grep -qxF "$m" "$INITRAMFS_MODULES" 2>/dev/null || echo "$m" >> "$INITRAMFS_MODULES"
done

# --- 4) Add kernel parameters in GRUB ---
KERNEL_PARAMS="amd_iommu=on iommu=pt vfio-pci.ids=${GPU_IDS} vfio-pci.disable_vga=1 modprobe.blacklist=nvidia,nvidia_drm,nvidia_modeset,nouveau"
existing=$(sed -n 's/^GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)".*/\1/p' "$GRUB_FILE" || true)
for p in $KERNEL_PARAMS; do
  grep -q -- "$p" <<<"$existing" || existing="$existing $p"
done
existing="$(echo "$existing" | xargs)"
if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE"; then
  sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$existing\"|" "$GRUB_FILE"
else
  echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$existing\"" >> "$GRUB_FILE"
fi
echo "Updated $GRUB_FILE"

# --- 5) Secure Boot check ---
if command -v mokutil &>/dev/null && mokutil --sb-state | grep -qi enabled; then
  echo "WARNING: Secure Boot is enabled. Unsigned vfio modules may be blocked."
fi

# --- 6) Rebuild initramfs & grub ---
update-initramfs -u -k "$(uname -r)"
update-grub

echo "Reboot and check with:"
echo "  lspci -nnk | grep -A 3 01:00"
echo "  lsmod | grep -E 'nvidia|nouveau'"
exit 0
