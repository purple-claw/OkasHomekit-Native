#!/bin/bash

echo "==> Creating OKAS HomeKit Service to run on every Boot..."
SERVICE="sirius.service"
SOURCE="/home/OhKnx/runOnce/$SERVICE"
DEST="/etc/systemd/system/$SERVICE"
if [ ! -f "$DEST" ]; then
    sudo cp "$SOURCE" "$DEST"
    echo "==> Registering OhKnx Sevice with Startup..."
else
    sudo systemctl stop "$SERVICE"
fi
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE"
sleep 4
echo '==> Service Registered.'
sudo chown -R www-data:www-data "/home/OhKnx/Data"
sudo chmod -R 775 "/home/OhKnx/Data"
# Authorization hashes and the command-session signing key must never be
# writable by Apache/PHP. The Node service runs as root.
sudo install -d -o root -g root -m 700 "/home/OhKnx/AuthData"
# Install Apache auth proxy config
if [ -f "/home/OhKnx/runOnce/okas-auth-proxy.conf" ] && [ -d "/etc/apache2/conf-available" ]; then
  sudo cp "/home/OhKnx/runOnce/okas-auth-proxy.conf" /etc/apache2/conf-available/okas-auth-proxy.conf
  sudo a2enconf okas-auth-proxy.conf 2>/dev/null || true
  sudo a2enmod proxy proxy_http headers 2>/dev/null || true
  sudo systemctl restart apache2 2>/dev/null || true
  echo '==> Auth proxy enabled.'
fi
# Link www folder to Apache web root
if [ ! -L "/var/www/html" ]; then
  sudo rm -rf /var/www/html
  sudo ln -s "/home/OhKnx/www" /var/www/html
fi
echo '==> System will Reboot automatically after 2 Seconds...'
sleep 2
sudo reboot
exit 0