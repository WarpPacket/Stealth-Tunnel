#!/bin/bash
#====================================================================
#  StealthTunnel - Uninstall Script
#  Usage: bash uninstall.sh
#====================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Run as root${NC}"
    exit 1
fi

echo -e "${RED}${BOLD}══════════════════════════════════════${NC}"
echo -e "${RED}${BOLD}  StealthTunnel Complete Uninstall    ${NC}"
echo -e "${RED}${BOLD}══════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}This will remove:${NC}"
echo "  - All tunnel services"
echo "  - All configurations"
echo "  - GOST and RTT binaries"
echo "  - System optimizations"
echo ""
read -p "Type 'REMOVE' to confirm: " confirm

if [[ "$confirm" != "REMOVE" ]]; then
    echo -e "${GREEN}Cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Stopping all services...${NC}"
for service in /etc/systemd/system/st-*.service; do
    [[ -f "$service" ]] || continue
    name=$(basename "$service")
    systemctl stop "$name" 2>/dev/null
    systemctl disable "$name" 2>/dev/null
    rm -f "$service"
    echo -e "  Removed: $name"
done

systemctl daemon-reload

echo -e "${YELLOW}Removing files...${NC}"
rm -rf /opt/stealth-tunnel
rm -rf /etc/stealth-tunnel
rm -rf /var/log/stealth-tunnel
rm -f /usr/local/bin/stealth-tunnel
rm -f /usr/local/bin/gost
rm -f /usr/local/bin/RTT
rm -f /etc/sysctl.d/99-stealth-tunnel.conf
rm -f /etc/security/limits.d/stealth-tunnel.conf

echo ""
echo -e "${GREEN}${BOLD}✓ StealthTunnel completely removed${NC}"
