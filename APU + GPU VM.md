````markdown
# Ryzen 5600G iGPU + NVIDIA GPU → Windows VM Passthrough Guide

This guide explains how to passthrough your NVIDIA GPU to a Windows VM while keeping your Ryzen 5600G iGPU for Linux desktop.

---

## 1️⃣ Preliminary Checks

### Verify GPUs

```bash
lspci -nnk | grep -A 3 VGA
```

Expected output:

```
01:00.0 NVIDIA Corporation Device [10de:xxxx]
07:00.0 AMD/ATI Cezanne [Radeon Vega] [1002:1638]
```

Here, `01:00.0` is NVIDIA and `07:00.0` is the integrated GPU (iGPU).

### Verify IOMMU

```bash
dmesg | grep -e DMAR -e IOMMU
```

You should see:

```
AMD-Vi: IOMMU enabled
```

---

## 2️⃣ Install Virtualization Packages

```bash
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients \
bridge-utils virt-manager ovmf
```

* **virt-manager** → GUI for managing VMs
* **OVMF** → UEFI firmware for VMs

### virt-manager setup

```bash
sudo virsh net-define /usr/share/libvirt/networks/default.xml
sudo virsh net-autostart default
sudo virsh net-start default

sudo usermod -aG libvirt $USER
```

Logout and back in.

---

## 3️⃣ Enable IOMMU in Linux

1. Edit GRUB:

```bash
sudo nano /etc/default/grub
```

2. Add the following to `GRUB_CMDLINE_LINUX_DEFAULT`:

```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=on iommu=pt"
```

3. Update GRUB and reboot:

```bash
sudo update-grub
sudo reboot
```

4. Verify IOMMU again:

```bash
dmesg | grep -e DMAR -e IOMMU
```

---

## 4️⃣ Bind NVIDIA GPU to VFIO

1. Load VFIO kernel module:

```bash
sudo modprobe vfio-pci
```

2. Create VFIO config for NVIDIA:

```bash
echo "options vfio-pci ids=10de:xxxx,10de:yyyy disable_vga=1" | sudo tee /etc/modprobe.d/vfio-nvidia.conf
```

> Replace `10de:xxxx` with your NVIDIA GPU ID and `10de:yyyy` with the associated HDMI/Audio function.

3. Blacklist NVIDIA driver:

```bash
echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
```

4. Ensure VFIO modules load at boot:

```bash
sudo nano /etc/initramfs-tools/modules
```

Add:

```
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

5. Update initramfs and reboot:

```bash
sudo update-initramfs -u
sudo reboot
```

6. Verify NVIDIA GPU is bound to VFIO:

```bash
lspci -nnk | grep -A3 01:00.0
```

Expected output:

```
Kernel driver in use: vfio-pci
```

---

## 5️⃣ Setup Windows VM in Virt-Manager

1. Open **Virt-Manager** → Create New VM
2. OS: Windows 10/11
3. Firmware: UEFI/OVMF
4. CPU: Host Passthrough
5. Memory/Disk: As needed
6. **Add PCI Host Device**:
   * Select NVIDIA GPU (`01:00.0`)
   * Optionally also select HDMI audio function
7. Boot Windows → install NVIDIA GPU drivers

---

## 6️⃣ Optional: Headless / Dummy HDMI

* If no monitor is connected to NVIDIA GPU, Windows may require a **dummy HDMI plug**.
* Alternatively, use **VNC / Spice** to view the VM remotely.

---

## 7️⃣ Install Looking Glass (Optional)

Add PCI of APU in virt manager inside the `<devices>` section:

```xml
<shmem name='lg-shm'>
  <model type='ivshmem-plain'/>
  <size unit='M'>32</size>
</shmem>
```

### Install Dependencies

```bash
sudo apt update
sudo apt install build-essential cmake libegl-dev libgl-dev libgles-dev \
libsdl2-dev libsdl2-ttf-dev libspice-protocol-dev libfontconfig-dev \
libx11-dev libxfixes-dev libxinerama-dev libxcursor-dev libxss-dev \
libxext-dev libxpresent-dev libxi-dev libdecor-0-dev libwayland-dev \
libxkbcommon-dev wayland-protocols libpipewire-0.3-dev libpulse-dev \
libsamplerate0-dev binutils-dev nettle-dev pkg-config
```

### Clone & Build

```bash
git clone --recursive https://github.com/gnif/LookingGlass.git
cd LookingGlass
git checkout Release/B7
git submodule update --init --recursive
cd client
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
```

### Configure

```bash
nano ~/.looking-glass-client.ini
```

Example config:

```ini
[win]
fullScreen=yes
size=1920x1080
position=0x0
```

### Run Client

```bash
looking-glass-client -s /dev/shm/lg-shm
```

---

## 8️⃣ Notes

* After shutting down Windows, Linux automatically reclaims the NVIDIA GPU.
* Linux desktop continues to use the Ryzen 5600G iGPU.
* Avoids the "whole IOMMU group" issue by passing NVIDIA GPU only.

---

✅ This setup allows:

* **Linux Desktop** → Ryzen 5600G iGPU
* **Windows VM** → NVIDIA GPU via VFIO
````
