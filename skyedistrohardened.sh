#!/bin/bash
#This script will harden a debian 13 install. Will try to comment as we go. The only thing this script cannot do is pre-install extensions for the browser.
#A list of browser extensions to install will be given
#clearurls ublock origin decentraleyes dark reader (makes everything dark for reading personal prefrence)

# Add contrib non-free non-free-firmware
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak && \
sudo sed -i 's/main$/main contrib non-free non-free-firmware/g' /etc/apt/sources.list && \
sudo apt update
sudo apt-get -y upgrade
#installs nessecary packages for: stable diffusion to start, pull from git, kernel compile tools for things
sudo apt-get -y install git build-essential libncurses5-dev zlib1g-dev curl virtualenv python3-virtualenv dkms extrepo install dirmngr ca-certificates software-properties-common apt-transport-https dkms okular
python3 -m venv venv
sudo apt-get -y build-dep linux
sudo extrepo enable librewolf
sudo apt update && sudo apt -y install librewolf vlc
sudo apt-get -y remove firefox
git clone https://github.com/ovh/debian-cis.git
cd debian-cis.git
sudo cp debian/default /etc/default/cis-hardening
sudo git clone https://github.com/ovh/debian-cis.git && cd debian-cis
sudo cp debian/default /etc/default/cis-hardening
sudo sed -i "s#CIS_LIB_DIR=.*#CIS_LIB_DIR='sudo(pwd)'/lib#" /etc/default/cis-hardening
sudo sed -i "s#CIS_CHECKS_DIR=.*#CIS_CHECKS_DIR='sudo(pwd)'/bin/hardening#" /etc/default/cis-hardening
sudo sed -i "s#CIS_CONF_DIR=.*#CIS_CONF_DIR='sudo(pwd)'/etc#" /etc/default/cis-hardening
sudo sed -i "s#CIS_TMP_DIR=.*#CIS_TMP_DIR='sudo(pwd)'/tmp#" /etc/default/cis-hardening
sudo bash bin/hardening.sh --set-hardening-level 1 --audit
sudo bash bin/hardening.sh --set-hardening-level 1 --apply
cd ..
cd /usr/src/
# Get the latest stable kernel version number straight from kernel.org
LATEST=$(wget -qO- https://kernel.org | grep 'latest_link' -A1 | tail -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

# Download the latest .tar.xz
sudo wget https://cdn.kernel.org/pub/linux/kernel/v${LATEST:0:1}.x/linux-${LATEST}.tar.xz

# Extract it (xvpf preserves permissions and shows files as they extract)
sudo tar xvpf linux-${LATEST}.tar.xz

# Jump right into the new directory
cd linux-${LATEST}

wget https://raw.githubusercontent.com/blubskye/skye/refs/heads/main/.config
grep -q 'O2' Makefile && sed -i 's/-O2/-O3/g' Makefile
sudo make -j$(($(nproc) + 1))
sudo make make -j$(($(nproc) + 1)) modules_install
sudo make install

##uncomment below for nvidia crap includes a patch F nvidia they won't fix they own crap
#sudo curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | sudo gpg --dearmor | sudo tee /usr/share/keyrings/nvidia-drivers.gpg > /dev/null 2>&1
#sudo echo 'deb [signed-by=/usr/share/keyrings/nvidia-drivers.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /' | sudo tee /etc/apt/sources.list.d/nvidia-drivers.list
#sudo apt install nvidia-driver cuda nvidia-smi nvidia-settings
#cd ~
#wget https://raw.githubusercontent.com/blubskye/skye/refs/heads/main/cuda_glibc_241_compat.diff
#pushd /usr/local/cuda/include/crt
#patch < ~/cuda_glibc_241_compat.diff
#popd
## Source - https://stackoverflow.com/a
# Posted by einpoklum, modified by community. See post 'Timeline' for change history
# Retrieved 2025-11-16, License - CC BY-SA 4.0



echo "Remember to install in librewolf clearurls ublock origin decentraleyes dark reader. Cool."
librewolf --new-tab "https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/"
librewolf --new-tab "https://addons.mozilla.org/en-US/firefox/addon/decentraleyes/"
librewolf --new-tab "https://addons.mozilla.org/en-US/firefox/addon/darkreader/"
librewolf --new-tab "https://addons.mozilla.org/en-US/firefox/addon/clearurls/"

echo "Full reboot required for all changes to take effect recommended"
