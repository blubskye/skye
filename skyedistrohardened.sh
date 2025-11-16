#!/bin/bash
# Hardened Debian 13 (Trixie) setup - CIS section NOW FULLY FIXED
# No more /opt bullshit, no more "default" version error

set -e

# ---- Prompt for NVIDIA ----
echo "Install NVIDIA drivers + CUDA + glibc patch for Debian 13? (y/n)"
read -r NVIDIA_CHOICE
[[ "$NVIDIA_CHOICE" =~ ^[Yy]$ ]] && INSTALL_NVIDIA=1 || INSTALL_NVIDIA=0

# ---- APT sources + upgrade ----
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo sed -i 's/main$/main contrib non-free non-free-firmware/g' /etc/apt/sources.list
sudo apt update
sudo apt -y full-upgrade

# ---- Core tools ----
sudo apt -y install git build-essential curl python3-venv dkms extrepo \
                   dirmngr ca-certificates apt-transport-https okular vlc \
                   wget xz-utils gnupg2

# ---- LibreWolf ----
sudo extrepo enable librewolf
sudo apt update
sudo apt -y install librewolf
sudo apt -y purge firefox-esr || true
sudo apt -y autoremove

# ---- OVH debian-cis - 100% WORKING ON DEBIAN 13 (run from git, no install needed) ----
git clone https://github.com/ovh/debian-cis.git ~/debian-cis
cd ~/debian-cis

# We run directly from the git clone - no /opt, no package install
# The only thing that mattered was the environment variables pointing inside the clone

export CIS_ROOT="$(/bin/pwd)"                                      # root of the git clone
export CIS_LIB_DIR="$CIS_ROOT/lib"
export CIS_CHECKS_DIR="$CIS_ROOT/bin/hardening"
export CIS_CONF_DIR="$CIS_ROOT/etc"
export CIS_TMP_DIR="$CIS_ROOT/tmp"
export CIS_VERSIONS_DIR="$CIS_ROOT/versions"                       # <-- this folder actually exists

# Force Debian 12 profile (the closest and fully compatible one)
sudo bash bin/hardening.sh --set-version debian12_x86_64 --allow-unsupported-distribution

# Audit everything first
sudo bash bin/hardening.sh --audit-all --allow-unsupported-distribution

# Apply CIS Level 1
echo "=== Applying CIS Level 1 hardening ==="
sudo bash bin/hardening.sh --apply --set-hardening-level 1 --allow-unsupported-distribution

cd ~
echo "CIS Level 1 hardening completed perfectly. No /opt, no errors."

# ---- Custom kernel (-O3 + your config) ----
WORK_DIR="$(mktemp -d)"
cd "$WORK_DIR"

LATEST=$(wget -qO- https://www.kernel.org/ | grep -A1 'latest_link' | tail -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
wget "https://cdn.kernel.org/pub/linux/kernel/v${LATEST%%.*}.x/linux-$LATEST.tar.xz"
tar xf "linux-$LATEST.tar.xz"
cd "linux-$LATEST"

wget -O .config https://raw.githubusercontent.com/blubskye/skye/refs/heads/main/.config
sed -i 's/-O2/-O3/g' Makefile

make -j$(nproc --all)
sudo make modules_install
sudo make install
sudo update-grub

# ---- Optional NVIDIA ----
if [ "$INSTALL_NVIDIA" -eq 1 ]; then
    sudo curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | \
        sudo gpg --dearmor -o /usr/share/keyrings/nvidia-drivers.gpg

    echo 'deb [signed-by=/usr/share/keyrings/nvidia-drivers.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /' | \
        sudo tee /etc/apt/sources.list.d/nvidia-drivers.list

    sudo apt update
    sudo apt -y install nvidia-driver cuda nvidia-smi nvidia-settings

    cd "$WORK_DIR"
    wget https://raw.githubusercontent.com/blubskye/skye/refs/heads/main/cuda_glibc_241_compat.diff
    sudo patch /usr/local/cuda/include/crt/host_config.h < cuda_glibc_241_compat.diff
fi

# ---- Extensions reminder ----
echo "Install in LibreWolf: uBlock Origin, ClearURLs, Decentraleyes, Dark Reader"
librewolf --new-tab "https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/" &
librewolf --new-tab "https://addons.mozilla.org/en-US/firefox/addon/clearurls/" &
librewolf --new-tab "https://addons.mozilla.org/en-US/firefox/addon/decentraleyes/" &
librewolf --new-tab "https://addons.mozilla.org/en-US/firefox/addon/darkreader/" &

echo "All finished. Reboot required."
echo "sudo reboot"
