#!/bin/bash

echo '==> Backing up hosts file'
sudo cp /etc/hosts /etc/hosts.bak
echo '==> Creating Host Name: "okas-homekit"...'
sudo hostnamectl set-hostname okas-homekit
sudo sed -i 's/khadas-vim3l/okas-homekit/g' /etc/hosts
sudo sed -i 's/^BOARD_NAME=.*/BOARD_NAME="OKAS HomeKit"/' /etc/armbian-image-release
sudo sed -i 's/^BOARD=.*/BOARD="OhKnx v1"/' /etc/armbian-image-release
sudo sed -i 's/^VENDOR=.*/VENDOR="OKAS"/' /etc/armbian-image-release
sudo sed -i 's/^BOARD_NAME=.*/BOARD_NAME="OKAS HomeKit"/' /etc/armbian-release
sudo sed -i 's/^BOARD=.*/BOARD="OhKnx v1"/' /etc/armbian-release
sudo sed -i 's/^VENDOR=.*/VENDOR="OKAS"/' /etc/armbian-release
echo '==> Created Host Name: "okas-homekit". Will take effect after Reboot.'
echo '==> Creating User Group & adding necessary Permissions.'
OLDUSER="HkB4KNX"
NEWUSER="OhKnx"
OLDHOME="/home/$OLDUSER"
NEWHOME="/home/$NEWUSER"
if id "$OLDUSER" &>/dev/null; then
    echo "User $OLDUSER exists. Proceeding with rename..."
    # Rename the user
    sudo usermod -l "$NEWUSER" "$OLDUSER"
    # Rename the home directory and move contents
    if [ -d "$OLDHOME" ]; then
        sudo usermod -d "$NEWHOME" -m "$NEWUSER"
        echo "Home directory renamed to $NEWHOME"
    else
        echo "Home directory $OLDHOME does not exist, skipping..."
    fi
    echo "User rename completed: $OLDUSER → $NEWUSER"
else
    echo "User $OLDUSER does not exist. Exiting."
fi


sudo groupadd hkgroup
sudo usermod -aG hkgroup OhKnx
sudo usermod -aG hkgroup www-data
sudo usermod -aG hkgroup root
sudo chown -R OhKnx:hkgroup /home/OhKnx
sudo chmod -R 777 /home/OhKnx
sudo chmod g+s /home/OhKnx
sudo chown -R :hkgroup /home/OhKnx
sudo chmod -R g+rwX /home/OhKnx
sudo find /home/OhKnx -type d -exec chmod g+s {} +
sudo cp /home/OhKnx/runOnce/www-data /etc/sudoers.d/www-data
echo '==> System will Reboot automatically after 2 Seconds...'
sleep 2
sudo reboot