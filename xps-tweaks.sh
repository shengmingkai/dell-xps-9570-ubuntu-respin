#!/usr/bin/env bash

# Check if the script is running under Ubuntu 18.04 Bionic Beaver
if [ $(lsb_release -c -s) != "bionic" ]; then
    >&2 echo "This script is made for Ubuntu 18.04!"
    exit 1
fi

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
    >&2 echo "Please run xps-tweaks as root!"
    exit 2
fi

# Enable universe and proposed
add-apt-repository -y universe
apt -y update
apt -y full-upgrade

# Install all the power management tools
add-apt-repository -y ppa:linrunner/tlp
apt -y update
apt -y install thermald tlp tlp-rdw powertop

# Fix Sleep/Wake Bluetooth Bug
sed -i '/RESTORE_DEVICE_STATE_ON_STARTUP/s/=.*/=1/' /etc/default/tlp
systemctl restart tlp

# Install the latest nVidia driver and codecs
add-apt-repository -y ppa:graphics-drivers/ppa
apt -y update
apt -y install nvidia-driver-410 libnvidia-gl-410 nvidia-prime bbswitch-dkms pciutils

# Install codecs
apt -y install ubuntu-restricted-extras va-driver-all vainfo libva2 gstreamer1.0-libav gstreamer1.0-vaapi

# Other packages
apt -y install intel-microcode

# Install wifi drivers
rm -f /lib/firmware/ath10k/QCA6174/hw3.0/*
wget -O /lib/firmware/ath10k/QCA6174/hw3.0/board.bin https://github.com/kvalo/ath10k-firmware/blob/master/QCA6174/hw3.0/board.bin?raw=true
wget -O /lib/firmware/ath10k/QCA6174/hw3.0/board-2.bin https://github.com/kvalo/ath10k-firmware/blob/master/QCA6174/hw3.0/board-2.bin?raw=true
wget -O /lib/firmware/ath10k/QCA6174/hw3.0/firmware-4.bin https://github.com/kvalo/ath10k-firmware/blob/master/QCA6174/hw3.0/firmware-4.bin_WLAN.RM.2.0-00180-QCARMSWPZ-1?raw=true

# Load and enable systemd units
systemctl daemon-reload
systemctl disable nvidia-fallback

# Enable power saving tweaks for Intel chip
echo "options i915 enable_fbc=1 enable_psr=2 enable_guc=-1 disable_power_well=0 fastboot=1" > /etc/modprobe.d/i915.conf
update-initramfs -u

# Switch to Intel card
prime-select intel 2>/dev/null

# Tweak grub defaults
GRUB_OPTIONS_VAR_NAME="GRUB_CMDLINE_LINUX_DEFAULT"
GRUB_OPTIONS="quiet acpi_rev_override=1 acpi_osi=Linux scsi_mod.use_blk_mq=1 nouveau.modeset=0 nouveau.runpm=0 mem_sleep_default=deep"
GRUB_OPTIONS_VAR="$GRUB_OPTIONS_VAR_NAME=\"$GRUB_OPTIONS\""

if cat /etc/default/grub | grep "$GRUB_OPTIONS_VAR" &>/dev/null
then
    echo "Grub is already tweaked!"
else
    sed -i "s/^$GRUB_OPTIONS_VAR_NAME/# $GRUB_OPTIONS_VAR_NAME/g" /etc/default/grub
    awk '/# '"$GRUB_OPTIONS_VAR_NAME"'/{print;print "'"$GRUB_OPTIONS_VAR_NAME"'=\"'"$GRUB_OPTIONS"'\"";next}1' /etc/default/grub | \
        tee /etc/default/grub &>/dev/null
    update-grub
fi

echo "FINISHED! Please reboot the machine!"
