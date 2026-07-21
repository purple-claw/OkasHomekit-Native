#!/bin/bash
# =============================================================================
# OhKnx - KNX Bridge Service Setup Script
# Registers the Python xknx bridge (OhKnxKnx.service) as a systemd service
# that starts automatically on boot. Run as: sudo bash setup-knx-bridge-service.sh
# =============================================================================
set -e

SERVICE="OhKnxKnx.service"
SOURCE="/home/OhKnx/runOnce/$SERVICE"
DEST="/etc/systemd/system/$SERVICE"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC}  $*"; }
info() { echo -e "${YELLOW}[--] $*${NC}"; }
warn() { echo -e "${YELLOW}[!!] $*${NC}"; }

[[ $EUID -ne 0 ]] && { echo -e "${RED}[ERR]${NC} Run with sudo: sudo bash setup-knx-bridge-service.sh"; exit 1; }
[[ -f "$SOURCE" ]] || { echo -e "${RED}[ERR]${NC} Source $SOURCE not found. Run this script from the OhKnx home directory."; exit 1; }

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  OhKnx - KNX Bridge Service Setup${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

# ── 1. Install or refresh the service unit ────────────────────────────────────
info "Installing $SERVICE …"
if [ ! -f "$DEST" ]; then
    cp "$SOURCE" "$DEST"
    ok "Service file copied to $DEST."
else
    systemctl stop "$SERVICE" 2>/dev/null || true
    cp "$SOURCE" "$DEST"
    ok "Service file updated (was already registered)."
fi

# ── 2. Reload and enable ──────────────────────────────────────────────────────
info "Reloading systemd and enabling service …"
systemctl daemon-reload
systemctl enable "$SERVICE"
ok "Service enabled (will start on boot)."

# ── 3. Start the service now ──────────────────────────────────────────────────
info "Starting $SERVICE …"
systemctl start "$SERVICE" 2>/dev/null && ok "Service started successfully." \
    || warn "Service could not be started. Check: sudo journalctl -u $SERVICE"

# ── 4. Show status ────────────────────────────────────────────────────────────
echo ""
systemctl status "$SERVICE" --no-pager 2>&1 | head -15
echo ""
info "Use 'sudo journalctl -u $SERVICE -f' to follow logs."
echo -e "${GREEN}Done.${NC}"
