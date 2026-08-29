#!/bin/bash
# =============================================================================
# OhKnx - Complete Cleanup Script
# Undoes everything setup.sh did. Run as: sudo bash cleanup.sh
# =============================================================================

set -e

APP_USER="OhKnx"
APP_HOME="/home/$APP_USER"
SVC_NAME="sirius.service"
SVC_DEST="/etc/systemd/system/$SVC_NAME"
SUDOERS_DEST="/etc/sudoers.d/www-data"
APACHE_ROOT="/var/www/html"
VHOST="/etc/apache2/sites-available/000-default.conf"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC}  $*"; }
info() { echo -e "${YELLOW}[--] $*${NC}"; }
warn() { echo -e "${YELLOW}[!!] $*${NC}"; }

[[ $EUID -ne 0 ]] && { echo -e "${RED}[ERR]${NC} Run with sudo: sudo bash cleanup.sh"; exit 1; }

echo ""
echo -e "${RED}============================================================${NC}"
echo -e "${RED}  OhKnx - FULL CLEANUP${NC}"
echo -e "${RED}  This will remove ALL installed components.${NC}"
echo -e "${RED}============================================================${NC}"
echo ""
read -r -p "Are you sure you want to continue? [y/N] " CONFIRM
[[ "${CONFIRM,,}" != "y" ]] && { echo "Aborted."; exit 0; }
echo ""

# ── 1. Stop & disable systemd service ────────────────────────────────────────
info "Stopping and disabling $SVC_NAME …"
systemctl stop    "$SVC_NAME" 2>/dev/null && ok "Service stopped."   || warn "Service was not running."
systemctl disable "$SVC_NAME" 2>/dev/null && ok "Service disabled."  || warn "Service was not enabled."
if [[ -f "$SVC_DEST" ]]; then
    rm -f "$SVC_DEST"
    ok "Removed $SVC_DEST"
fi
systemctl daemon-reload
ok "systemd reloaded."

# ── 2. Remove sudoers rule ────────────────────────────────────────────────────
info "Removing sudoers rule …"
if [[ -f "$SUDOERS_DEST" ]]; then
    rm -f "$SUDOERS_DEST"
    ok "Removed $SUDOERS_DEST"
else
    warn "$SUDOERS_DEST not found, skipping."
fi

# ── 3. Remove OhKnx user & home directory ────────────────────────────────────
info "Removing user $APP_USER and home directory …"
if id "$APP_USER" &>/dev/null; then
    # Kill any processes still running as this user
    pkill -u "$APP_USER" 2>/dev/null || true
    sleep 1
    userdel -r "$APP_USER" 2>/dev/null && ok "User $APP_USER and $APP_HOME removed." || {
        warn "userdel had issues. Force-removing home directory manually."
        rm -rf "$APP_HOME"
    }
else
    warn "User $APP_USER does not exist, skipping."
    # Still clean up home dir if it exists
    [[ -d "$APP_HOME" ]] && rm -rf "$APP_HOME" && ok "Removed leftover $APP_HOME"
fi

# ── 4. Remove hkgroup ────────────────────────────────────────────────────────
info "Removing hkgroup …"
if getent group hkgroup &>/dev/null; then
    groupdel hkgroup 2>/dev/null && ok "Group hkgroup removed." || warn "Could not remove hkgroup (may still have members)."
else
    warn "Group hkgroup not found, skipping."
fi

# ── 5. Restore Apache web root ───────────────────────────────────────────────
info "Restoring Apache web root …"
if [[ -L "$APACHE_ROOT" ]]; then
    rm -f "$APACHE_ROOT"
    mkdir -p "$APACHE_ROOT"
    chown www-data:www-data "$APACHE_ROOT"
    # Restore Apache default index page
    cat > "$APACHE_ROOT/index.html" <<'HTML'
<!DOCTYPE html>
<html><body><h1>Apache2 Default Page</h1><p>Cleanup complete.</p></body></html>
HTML
    ok "Restored $APACHE_ROOT as a real directory."
else
    warn "$APACHE_ROOT is not a symlink, leaving it untouched."
fi

# ── 6. Restore Apache default vhost ──────────────────────────────────────────
info "Restoring Apache default vhost …"
cat > "$VHOST" <<'APACHEEOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
APACHEEOF
ok "Default vhost restored."

# ── 7. Uninstall Node.js ──────────────────────────────────────────────────────
info "Uninstalling Node.js …"
if command -v node &>/dev/null; then
    apt purge -y nodejs 2>/dev/null && ok "Node.js removed." || warn "Could not remove Node.js via apt."
    rm -f /etc/apt/sources.list.d/nodesource.list
    apt autoremove -y 2>/dev/null || true
    ok "Node.js clean up done."
else
    warn "Node.js not installed, skipping."
fi

# ── 8. Uninstall Apache & PHP ─────────────────────────────────────────────────
info "Uninstalling Apache2 and PHP …"
apt purge -y apache2 apache2-utils php php-cli libapache2-mod-php 'php*' 2>/dev/null || true
apt autoremove -y 2>/dev/null || true
# Remove any leftover apache/php config
rm -rf /etc/apache2 /etc/php
ok "Apache2 and PHP removed."

# ── 9. Restore hostname ───────────────────────────────────────────────────────
info "Restoring hostname …"
hostnamectl set-hostname localhost
sed -i 's/okas-homekit/localhost/g' /etc/hosts 2>/dev/null || true
ok "Hostname reset to 'localhost'. Change it again manually if needed."

# ── 10. Restore Armbian branding ──────────────────────────────────────────────
info "Restoring Armbian release branding …"
for F in /etc/armbian-image-release /etc/armbian-release; do
    if [[ -f "$F" ]]; then
        sed -i 's/^BOARD_NAME=.*/BOARD_NAME="Khadas VIM3L"/' "$F"
        sed -i 's/^BOARD=.*/BOARD="khadas-vim3l"/'           "$F"
        sed -i 's/^VENDOR=.*/VENDOR="Khadas"/'               "$F"
        ok "Restored branding in $F"
    fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Cleanup Complete${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "  Removed : $SVC_DEST"
echo "  Removed : $SUDOERS_DEST"
echo "  Removed : $APP_HOME (user $APP_USER)"
echo "  Removed : hkgroup"
echo "  Removed : Node.js, Apache2, PHP"
echo "  Restored: $APACHE_ROOT (real directory)"
echo "  Restored: $VHOST (default vhost)"
echo "  Hostname: reset to 'localhost'"
echo ""
echo -e "${YELLOW}  Board is clean. Ready for fresh setup.${NC}"
echo -e "${GREEN}============================================================${NC}"
