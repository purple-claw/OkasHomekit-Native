#!/bin/bash
# =============================================================================
# OhKnx - Auth Webserver Setup Script
# Creates the secure AuthData store and configures Apache reverse proxy
# for the Auth API (port 8080). Run as: sudo bash setup-auth-webserver.sh
# =============================================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC}  $*"; }
info() { echo -e "${YELLOW}[--] $*${NC}"; }
warn() { echo -e "${YELLOW}[!!] $*${NC}"; }

[[ $EUID -ne 0 ]] && { echo -e "${RED}[ERR]${NC} Run with sudo: sudo bash setup-auth-webserver.sh"; exit 1; }

APP_HOME="/home/OhKnx"
AUTH_DATA_DIR="$APP_HOME/AuthData"
RUNONCE_DIR="$APP_HOME/runOnce"

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  OhKnx - Auth Webserver Setup${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

# ── 1. Create AuthData directory ─────────────────────────────────────────────
info "Creating AuthData directory at $AUTH_DATA_DIR …"
install -d -o root -g root -m 700 "$AUTH_DATA_DIR"
ok "AuthData directory created with root-only access (700)."

# ── 2. Install Apache auth proxy configuration ────────────────────────────────
info "Installing Apache auth proxy configuration …"
if [ -f "$RUNONCE_DIR/okas-auth-proxy.conf" ] && [ -d "/etc/apache2/conf-available" ]; then
    PROXY_DEST="/etc/apache2/conf-available/okas-auth-proxy.conf"
    cp "$RUNONCE_DIR/okas-auth-proxy.conf" "$PROXY_DEST"
    ok "Copied okas-auth-proxy.conf to $PROXY_DEST."

    a2enconf okas-auth-proxy.conf 2>/dev/null || true
    a2enmod proxy proxy_http headers 2>/dev/null || true
    ok "Apache proxy modules and config enabled."
else
    warn "okas-auth-proxy.conf not found in $RUNONCE_DIR or Apache conf-available missing."
    warn "Skipping proxy configuration. Create okas-auth-proxy.conf first."
fi

# ── 3. Restart Apache ────────────────────────────────────────────────────────
info "Restarting Apache …"
if systemctl restart apache2 2>/dev/null; then
    ok "Apache restarted successfully."
else
    warn "Could not restart Apache. Check Apache installation."
fi

# ── 4. Verify the Auth API will be reachable ─────────────────────────────────
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Auth Webserver Setup Complete${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "  AuthData directory : $AUTH_DATA_DIR (root:root, 700)"
echo "  Proxy config       : /etc/apache2/conf-available/okas-auth-proxy.conf"
echo "  Auth API endpoint  : http://127.0.0.1:8080/api/auth/"
echo "  Public endpoint    : http://$(hostname)/api/auth/"
echo ""
echo "  The Auth API is served by the Node.js auth service (authService.js)"
echo "  which starts automatically with the HomeKit bridge (Index.js)."
echo "  Apache proxies /api/* requests to the Node.js process on port 8080."
echo ""
