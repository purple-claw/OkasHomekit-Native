#!/bin/bash

echo "==> Installing Dependencies and Updating System <=="
USER_HOME="/home/OhKnx"
HKB_DIR="$USER_HOME"
APACHE_INSTALLED=false
# echo "==> Ensuring system is up-to-Date"
# sudo apt update && sudo apt upgrade -y

# Install Node.js and npm if not already
echo "==> Checking if Node.JS installed."
if ! command -v node &>/dev/null; then
  echo "==> Installing Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt install nodejs -y
else
  echo "==> Node.JS is already installed."
fi

# Install Apache and PHP if not already
echo "==> Checking if WebServer installed."
if ! dpkg -l | grep -q apache2; then
  echo "==> Installing WebServer..."
  sudo apt install apache2 -y
  APACHE_INSTALLED=true
else
  echo "==> WebServer is already installed."
fi

echo "==> Checking if PHP installed."
if ! dpkg -l | grep -q php; then
  echo "==> Installing PHP..."
  sudo apt install php libapache2-mod-php -y
else
  echo "==> PHP is already installed."
fi

pushd "$HKB_DIR" > /dev/null

echo "==> Checking if KNX installed."
#if [ -d "/home/OhKnx/node_modules/knx" ]; then
if [ -d "node_modules/knx" ]; then
  echo "==> KNX is already installed."
else
  echo "==> Installing KNX..."
  sudo npm install knx
  sudo -u OhKnx npm install knx
fi

echo "==> Checking if HomeKit installed."
if [ -d "node_modules/hap-nodejs" ]; then
  echo "==> HomeKit is already installed."
else
  echo "==> Installing HomeKit..."
  sudo npm install hap-nodejs
  sudo -u OhKnx npm install hap-nodejs
fi

# Enable and restart Apache if needed
if $APACHE_INSTALLED; then
  echo "==> Enabling and starting Apache..."
  sudo systemctl enable apache2
  sudo systemctl start apache2
else
  echo "==> Restarting Apache..."
  sudo systemctl restart apache2
fi

popd > /dev/null
sleep 2
echo "<== Dependencies installed and System up-to-date ==>"
exit 0
