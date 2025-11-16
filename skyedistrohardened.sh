#!/bin/bash
# Hardened Debian 13 (Trixie) setup - fixed & automated with optional NVIDIA
# Run as normal user with sudo privileges

set -e  # Exit immediately on any error

# ---- Prompt for NVIDIA ----
echo "Do you want to install NVIDIA drivers + CUDA (using debian12 repo) and apply glibc 2.41 patch? (y/n)"
read -r NVIDIA_CHOICE
if [[ "$NVIDIA_CHOICE" =~ ^[Yy]$ ]]; then
    INSTALL_NVIDIA=1
else
    INSTALL_NVIDIA=0
fi

# ---- APT sources + upgrade ----
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo sed -i 's/main$/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
sudo apt update
sudo apt -y full-upgrade

# ---- Core tools ----
sudo apt -y install git build-essential curl python3-venv dkms extrepo \
                   dirmngr ca-certificates apt-transport-https okular vlc \
                   wget xz-utils gnupg2

# ---- LibreWolf (replaces Firefox) ----
sudo extrepo enable librewolf
sudo apt update
sudo apt -y install librewolf
sudo apt -y purge firefox-esr || true
sudo apt -y autoremove

# ---- OVH debian-cis hardening ----
git clone https://github.com/ovh/debian-cis.git
cd debian-cis
CIS_DIR="$(/bin/pwd)"  # Absolute path

sudo cp debian/default /etc/default/cis-hardening

sudo sed -i "s#CIS_LIB_DIR=.*#CIS_LIB_DIR='$CIS_DIR/lib'#g"       /etc/default/cis-hardening
sudo sed -i "s#CIS_CHECKS_DIR=.*#CIS_CHECKS_DIR='$CIS_DIR/bin/hardening'#g" /etc/default/cis-hardening
sudo sed -i "s#CIS_CONF_DIR=.*#CIS_CONF_DIR='$CIS_DIR/etc'#g"     /etc/default/cis-hardening
sudo sed -i "s#CIS_TMP_DIR=.*#CIS_TMP_DIR='$CIS_DIR/tmp'#g"       /etc/default/cis-hardening

sudo ./bin/hardening.sh --audit-all
sudo ./bin/hardening.sh --apply --set-hardening-level 1
cd ..

# ---- Custom latest stable kernel (-O3, your .config) ----
WORK_DIR="$(mktemp -d)"
cd "$WORK_DIR"

# Fetch latest stable version automatically
LATEST=$(wget -qO- https://www.kernel.org/ | grep -A1 'latest_link' | tail -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

wget "https://cdn.kernel.org/pub/linux/kernel/v${LATEST%%.*}.x/linux-$LATEST.tar.xz"
tar xf "linux-$LATEST.tar.xz"
cd "linux-$LATEST"

# Your personal config
wget -O .config https://raw.githubusercontent.com/blubskye/skye/refs/heads/main/.config

# -O3 instead of -O2
sed -i 's/-O2/-O3/g' Makefile

# Build
make -j$(nproc --all)
sudo make modules_install
sudo make install

# Update grub
sudo update-grub

# ---- Optional NVIDIA + CUDA ----
if [ "$INSTALL_NVIDIA" -eq 1 ]; then
    sudo curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | \
        sudo gpg --dearmor -o /usr/share/keyrings/nvidia-drivers.gpg

    echo 'deb [signed-by=/usr/share/keyrings/nvidia-drivers.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /' | \
        sudo tee /etc/apt/sources.list.d/nvidia-drivers.list

    sudo apt update
    sudo apt -y install nvidia-driver cuda nvidia-smi nvidia-settings

    # glibc compatibility patch
    cd "$WORK_DIR"  # Reuse temp dir for download
    wget https://raw.githubusercontent.com/blubskye/skye/refs/heads/main/cuda_glibc_241_compat.diff
    sudo patch /usr/local/cuda/include/crt/host_config.h < cuda_glibc_241_compat.diff
fi

# ---- Browser extensions reminder ----
echo "Install these in LibreWolf:"
echo "uBlock Origin, ClearURLs, Decentraleyes, Dark Reader"

librewolf --new-tab "https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/" &
librewolf --new-tab "https://addons.mozilla.org/en-US/firefox/addon/clearurls/" &
librewolf --new-tab "https://addons.mozilla.org/en-US/firefox/addon/decentraleyes/" &
librewolf --new-tab "https://addons.mozilla.org/en-US/firefox/addon/darkreader/" &

echo "All done. Reboot now for kernel changes (and NVIDIA if installed)."
echo "sudo reboot"
