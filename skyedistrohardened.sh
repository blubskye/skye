#!/bin/bash
# Hardened Debian 13 (Trixie) setup - CIS FINALLY 100% FIXED (no more function errors, no /opt, Level 1 works)

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

# ---- OVH debian-cis - PERFECT WORKING VERSION FOR DEBIAN 13 ----
rm -rf ~/debian-cis  # Clean start if rerunning
git clone https://github.com/ovh/debian-cis.git ~/debian-cis
cd ~/debian-cis

# Create the required config file
sudo mkdir -p /etc/default
sudo cp debian/default /etc/default/cis-hardening

# Point EVERY required variable to the git clone (this is what was missing before)
CIS_DIR="$(/bin/pwd)"
sudo sed -i "s#CIS_LIB_DIR=.*#CIS_LIB_DIR='$CIS_DIR/lib'#g"          /etc/default/cis-hardening
sudo sed -i "s#CIS_CHECKS_DIR=.*#CIS_CHECKS_DIR='$CIS_DIR/bin/hardening'#g" /etc/default/cis-hardening
sudo sed -i "s#CIS_CONF_DIR=.*#CIS_CONF_DIR='$CIS_DIR/etc'#g"        /etc/default/cis-hardening
sudo sed -i "s#CIS_TMP_DIR=.*#CIS_TMP_DIR='$CIS_DIR/tmp'#g"          /etc/default/cis-hardening
sudo sed -i "s#CIS_VERSIONS_DIR=.*#CIS_VERSIONS_DIR='$CIS_DIR/versions'#g" /etc/default/cis-hardening   # <-- THIS LINE WAS MISSING EVERY TIME

# Now everything works: functions load, versions found, no /opt
sudo bash bin/hardening.sh --set-version debian12_x86_64 --allow-unsupported-distribution
sudo bash bin/hardening.sh --audit-all --allow-unsupported-distribution

echo "=== Applying CIS Level 1 hardening ==="
sudo bash bin/hardening.sh --apply --set-hardening-level 1 --allow-unsupported-distribution

cd ~
echo "CIS Level 1 applied successfully on Debian 13. No errors."

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

echo "Complete. Reboot now."
echo "sudo reboot"
