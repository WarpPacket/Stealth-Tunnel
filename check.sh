#!/bin/bash
#====================================================================
#  StealthTunnel - Quick Health Check Script
#  Usage: bash check.sh
#====================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

CONFIG_DIR="/etc/stealth-tunnel"
TUNNELS_DIR="$CONFIG_DIR/tunnels"

echo -e "${CYAN}${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║   StealthTunnel Health Check         ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""

# Check components
echo -e "${BOLD}[Components]${NC}"
echo -e "  GOST: $(command -v gost &>/dev/null && echo -e "${GREEN}✓ OK${NC}" || echo -e "${RED}✗ Missing${NC}")"
echo -e "  RTT:  $(command -v RTT &>/dev/null && echo -e "${GREEN}✓ OK${NC}" || echo -e "${YELLOW}○ Not installed${NC}")"
echo -e "  jq:   $(command -v jq &>/dev/null && echo -e "${GREEN}✓ OK${NC}" || echo -e "${RED}✗ Missing${NC}")"
echo ""

# Check config
echo -e "${BOLD}[Configuration]${NC}"
if [[ -f "$CONFIG_DIR/config.json" ]]; then
    local role=$(jq -r '.server_role' "$CONFIG_DIR/config.json" 2>/dev/null)
    echo -e "  Config:  ${GREEN}✓ Found${NC}"
    echo -e "  Role:    ${CYAN}${role:-Not set}${NC}"
else
    echo -e "  Config: ${RED}✗ Not found${NC}"
fi
echo ""

# Check tunnels
echo -e "${BOLD}[Tunnels]${NC}"
if [[ -d "$TUNNELS_DIR" ]]; then
    local count=$(ls "$TUNNELS_DIR"/*.json 2>/dev/null | wc -l)
    echo -e "  Total tunnels: ${CYAN}${count}${NC}"
    
    for f in "$TUNNELS_DIR"/*.json; do
        [[ -f "$f" ]] || continue
        local name=$(jq -r '.name' "$f")
        local running="no"
        
        if systemctl is-active "st-gost-${name}.service" &>/dev/null || \
           systemctl is-active "st-rtt-${name}.service" &>/dev/null; then
            running="yes"
        fi
        
        if [[ "$running" == "yes" ]]; then
            echo -e "  ${GREEN}✓${NC} ${name} - ${GREEN}running${NC}"
        else
            echo -e "  ${RED}✗${NC} ${name} - ${RED}stopped${NC}"
        fi
    done
else
    echo -e "  ${YELLOW}No tunnels directory${NC}"
fi
echo ""

# Network info
echo -e "${BOLD}[Network]${NC}"
echo -e "  IP: $(curl -s -4 ifconfig.me 2>/dev/null || echo 'N/A')"
echo -e "  BBR: $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}' || echo 'N/A')"
echo -e "  Connections: $(ss -tun state established 2>/dev/null | wc -l)"
echo ""

# System
echo -e "${BOLD}[System]${NC}"
echo -e "  OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo 'N/A')"
echo -e "  Kernel: $(uname -r)"
echo -e "  Uptime: $(uptime -p 2>/dev/null || echo 'N/A')"
echo -e "  Memory: $(free -m 2>/dev/null | awk 'NR==2{printf "%sMB/%sMB (%.1f%%)", $3, $2, $3*100/$2}' || echo 'N/A')"
echo ""
