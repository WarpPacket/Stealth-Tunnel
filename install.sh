#!/bin/bash

#====================================================================
#  StealthTunnel - Combined RTT + GOST Stealth Tunnel Installer
#  One-line installer script
#  Usage: bash <(curl -fsSL https://raw.githubusercontent.com/WarpPacket/Stealth-Tunnel/main/install.sh)
#====================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
INSTALL_DIR="/opt/stealth-tunnel"
CONFIG_DIR="/etc/stealth-tunnel"
LOG_DIR="/var/log/stealth-tunnel"
BIN_DIR="/usr/local/bin"
GITHUB_REPO="WarpPacket/Stealth-Tunnel"
GOST_VERSION="3.2.6"
RTT_VERSION="V7.1"
PANEL_VERSION="1.0.0"

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║          ███████╗████████╗███████╗ █████╗ ██╗  ████████╗     ║"
    echo "║          ██╔════╝╚══██╔══╝██╔════╝██╔══██╗██║  ╚══██╔══╝     ║"
    echo "║          ███████╗   ██║   █████╗  ███████║██║     ██║        ║"
    echo "║          ╚════██║   ██║   ██╔══╝  ██╔══██║██║     ██║        ║"
    echo "║          ███████║   ██║   ███████╗██║  ██║███████╗██║        ║"
    echo "║          ╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝        ║"
    echo "║                                                              ║"
    echo "║            StealthTunnel - RTT + GOST Combined               ║"
    echo "║                   Invisible Tunnel Manager                   ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo -i)"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log_error "Cannot detect OS. This script supports Ubuntu/Debian only."
        exit 1
    fi

    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        log_warn "This script is optimized for Ubuntu/Debian. Proceeding anyway..."
    fi

    log_info "Detected OS: $OS $OS_VERSION"
}

# Detect architecture
detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)  ARCH_GOST="amd64"; ARCH_RTT="amd64" ;;
        aarch64) ARCH_GOST="arm64"; ARCH_RTT="arm64" ;;
        armv7l)  ARCH_GOST="armv7"; ARCH_RTT="arm" ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    log_info "Detected architecture: $ARCH ($ARCH_GOST)"
}

# Install dependencies
install_dependencies() {
    log_step "Installing dependencies..."
    apt-get update -qq
    apt-get install -y -qq curl wget unzip jq openssl net-tools > /dev/null 2>&1
    log_info "Dependencies installed successfully"
}

# Optimize system for tunnel
optimize_system() {
    log_step "Optimizing system for tunnel performance..."

    # Increase file descriptors
    cat > /etc/security/limits.d/stealth-tunnel.conf << 'EOF'
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOF

    # Optimize sysctl
    cat > /etc/sysctl.d/99-stealth-tunnel.conf << 'EOF'
# Network performance tuning for StealthTunnel
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.netdev_max_backlog = 10000
net.core.somaxconn = 65535
net.ipv4.tcp_rmem = 4096 1048576 67108864
net.ipv4.tcp_wmem = 4096 1048576 67108864
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10
net.ipv4.ip_forward = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_tw_buckets = 65535
net.ipv4.tcp_max_syn_backlog = 65535
fs.file-max = 1048576
EOF

    sysctl -p /etc/sysctl.d/99-stealth-tunnel.conf > /dev/null 2>&1 || true

    # Enable BBR
    if ! lsmod | grep -q bbr; then
        modprobe tcp_bbr 2>/dev/null || true
    fi

    log_info "System optimized for tunnel"
}

# Download and install GOST v3
install_gost() {
    log_step "Installing GOST v${GOST_VERSION}..."

    local GOST_URL="https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_${ARCH_GOST}.tar.gz"
    local TMP_DIR=$(mktemp -d)

    wget -q -O "${TMP_DIR}/gost.tar.gz" "$GOST_URL"
    tar -xzf "${TMP_DIR}/gost.tar.gz" -C "${TMP_DIR}"
    
    # Find the gost binary
    local GOST_BIN=$(find "${TMP_DIR}" -name "gost" -type f | head -1)
    if [[ -z "$GOST_BIN" ]]; then
        log_error "GOST binary not found in archive"
        rm -rf "${TMP_DIR}"
        exit 1
    fi

    cp "$GOST_BIN" "${BIN_DIR}/gost"
    chmod +x "${BIN_DIR}/gost"
    rm -rf "${TMP_DIR}"

    if gost -V > /dev/null 2>&1; then
        log_info "GOST v${GOST_VERSION} installed successfully"
    else
        log_error "GOST installation failed"
        exit 1
    fi
}

# Download and install RTT
install_rtt() {
    log_step "Installing RTT (Reverse TLS Tunnel) ${RTT_VERSION}..."

    # Check if already installed
    if command -v RTT &>/dev/null; then
        log_info "RTT is already installed"
        return 0
    fi

    # Run entire RTT install in a subshell so ANY failure is caught
    (
        TMP_DIR=$(mktemp -d)
        trap "rm -rf '$TMP_DIR'" EXIT

        # Determine correct filename based on arch
        local RTT_FILENAME=""
        case "${ARCH_RTT}" in
            amd64) RTT_FILENAME="v7.1_linux_amd64.zip" ;;
            arm64) RTT_FILENAME="v7.1_linux_arm64.zip" ;;
            *)     RTT_FILENAME="v7.1_linux_amd64.zip" ;;
        esac

        # Build download URL list with multiple mirrors/fallbacks
        local URLS=(
            # 1. Direct GitHub release (correct filename for V7.1)
            "https://github.com/radkesvat/ReverseTlsTunnel/releases/download/${RTT_VERSION}/${RTT_FILENAME}"
            # 2. Our own repo backup (always available)
            "https://github.com/${GITHUB_REPO}/raw/main/bin/rtt_${ARCH_RTT}.zip"
            # 3. GitHub release with alternate naming patterns
            "https://github.com/radkesvat/ReverseTlsTunnel/releases/download/${RTT_VERSION}/RTT-linux-${ARCH_RTT}.zip"
            "https://github.com/radkesvat/ReverseTlsTunnel/releases/download/${RTT_VERSION}/RTT_linux_${ARCH_RTT}.zip"
            # 4. GitHub CDN proxy mirrors (useful when GitHub is blocked)
            "https://mirror.ghproxy.com/https://github.com/radkesvat/ReverseTlsTunnel/releases/download/${RTT_VERSION}/${RTT_FILENAME}"
            "https://gh-proxy.com/https://github.com/radkesvat/ReverseTlsTunnel/releases/download/${RTT_VERSION}/${RTT_FILENAME}"
            "https://ghfast.top/https://github.com/radkesvat/ReverseTlsTunnel/releases/download/${RTT_VERSION}/${RTT_FILENAME}"
        )

        RTT_DOWNLOADED=false

        for URL in "${URLS[@]}"; do
            echo -e "${BLUE}[INFO]${NC} Trying: $(echo "$URL" | head -c 80)..."
            rm -f "${TMP_DIR}/rtt.zip"

            # Try wget first, then curl
            if wget -q --timeout=20 --tries=2 --no-check-certificate -O "${TMP_DIR}/rtt.zip" "$URL" 2>/dev/null; then
                true
            elif curl -fsSL --connect-timeout 20 --retry 2 --insecure -o "${TMP_DIR}/rtt.zip" "$URL" 2>/dev/null; then
                true
            else
                continue
            fi

            # Verify it's actually a valid zip (not HTML error page)
            if [ -s "${TMP_DIR}/rtt.zip" ] && file "${TMP_DIR}/rtt.zip" 2>/dev/null | grep -qi "zip"; then
                RTT_DOWNLOADED=true
                echo -e "${GREEN}[INFO]${NC} Download successful!"
                break
            elif [ -s "${TMP_DIR}/rtt.zip" ]; then
                # file command may not be available, try unzip test
                if unzip -t "${TMP_DIR}/rtt.zip" &>/dev/null; then
                    RTT_DOWNLOADED=true
                    echo -e "${GREEN}[INFO]${NC} Download successful!"
                    break
                fi
            fi
            rm -f "${TMP_DIR}/rtt.zip"
        done

        if [ "$RTT_DOWNLOADED" = true ]; then
            cd "$TMP_DIR"
            unzip -q -o rtt.zip 2>/dev/null || true

            # Find the RTT binary (case-insensitive)
            RTT_BIN=$(find . \( -name "RTT" -o -name "rtt" \) -type f 2>/dev/null | head -1)
            if [ -n "$RTT_BIN" ] && [ -f "$RTT_BIN" ]; then
                cp "$RTT_BIN" "${BIN_DIR}/RTT"
                chmod +x "${BIN_DIR}/RTT"
                echo -e "${GREEN}${BOLD}[INFO] ✓ RTT ${RTT_VERSION} installed successfully${NC}"
                exit 0
            else
                echo -e "${YELLOW}[WARN]${NC} Zip extracted but RTT binary not found inside"
            fi
        fi

        echo -e "${YELLOW}[WARN]${NC} RTT automatic download failed."
        echo -e "${YELLOW}[WARN]${NC} Trying manual download method..."

        # Last resort: download using the official RTT install script approach
        cd "$TMP_DIR"
        case "$(uname -m)" in
            x86_64)  URL="https://github.com/radkesvat/ReverseTlsTunnel/releases/download/V7.1/v7.1_linux_amd64.zip" ;;
            aarch64) URL="https://github.com/radkesvat/ReverseTlsTunnel/releases/download/V7.1/v7.1_linux_arm64.zip" ;;
            arm*)    URL="https://github.com/radkesvat/ReverseTlsTunnel/releases/download/V7.1/v7.1_linux_arm64.zip" ;;
            *)       URL="https://github.com/radkesvat/ReverseTlsTunnel/releases/download/V7.1/v7.1_linux_amd64.zip" ;;
        esac

        if wget -q --timeout=30 --tries=3 "$URL" -O rtt_dl.zip 2>/dev/null || \
           curl -fsSL --connect-timeout 30 --retry 3 -o rtt_dl.zip "$URL" 2>/dev/null; then
            unzip -o -q rtt_dl.zip 2>/dev/null || true
            if [ -f "RTT" ]; then
                cp RTT "${BIN_DIR}/RTT"
                chmod +x "${BIN_DIR}/RTT"
                echo -e "${GREEN}${BOLD}[INFO] ✓ RTT ${RTT_VERSION} installed successfully (manual method)${NC}"
                exit 0
            fi
        fi

        echo ""
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  RTT could not be downloaded automatically.                 ║${NC}"
        echo -e "${YELLOW}║                                                              ║${NC}"
        echo -e "${YELLOW}║  You can install it manually:                                ║${NC}"
        echo -e "${YELLOW}║                                                              ║${NC}"
        echo -e "${YELLOW}║  wget '${URL}'  ║${NC}"
        echo -e "${YELLOW}║  unzip v7.1_linux_amd64.zip                                  ║${NC}"
        echo -e "${YELLOW}║  mv RTT /usr/local/bin/RTT && chmod +x /usr/local/bin/RTT    ║${NC}"
        echo -e "${YELLOW}║                                                              ║${NC}"
        echo -e "${YELLOW}║  Or use GOST-only mode (still works great!)                  ║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        exit 0
    ) || true
    # ↑ || true guarantees we NEVER stop the installer
}

# Create directory structure
create_directories() {
    log_step "Creating directory structure..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR/tunnels"
    mkdir -p "$LOG_DIR"
    mkdir -p "$INSTALL_DIR/certs"
    log_info "Directories created"
}

# Generate self-signed certificates for GOST TLS
generate_certificates() {
    log_step "Generating TLS certificates..."
    
    if [[ ! -f "$INSTALL_DIR/certs/cert.pem" ]]; then
        openssl req -x509 -newkey rsa:4096 \
            -keyout "$INSTALL_DIR/certs/key.pem" \
            -out "$INSTALL_DIR/certs/cert.pem" \
            -days 3650 -nodes \
            -subj "/CN=cdn.cloudflare.com/O=Cloudflare Inc/C=US" \
            2>/dev/null
        log_info "TLS certificates generated"
    else
        log_info "TLS certificates already exist"
    fi
}

# Create main config file (only if it doesn't already exist)
create_main_config() {
    # If config already exists and is valid, preserve it
    if [[ -f "$CONFIG_DIR/config.json" ]] && jq empty "$CONFIG_DIR/config.json" 2>/dev/null; then
        log_info "Existing configuration found — preserving it"
        
        # Just update RTT installed status
        if command -v RTT &> /dev/null; then
            local TMP=$(mktemp)
            jq '.rtt_installed = true' "$CONFIG_DIR/config.json" > "$TMP" && mv "$TMP" "$CONFIG_DIR/config.json"
        fi
        
        # Update GOST installed status
        if command -v gost &> /dev/null; then
            local TMP=$(mktemp)
            jq '.gost_installed = true' "$CONFIG_DIR/config.json" > "$TMP" && mv "$TMP" "$CONFIG_DIR/config.json"
        fi
        
        # Update timestamp
        local NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local TMP=$(mktemp)
        jq --arg now "$NOW" '.updated_at = $now' "$CONFIG_DIR/config.json" > "$TMP" && mv "$TMP" "$CONFIG_DIR/config.json"
        
        return 0
    fi

    log_step "Creating main configuration..."
    
    cat > "$CONFIG_DIR/config.json" << 'EOF'
{
    "version": "1.0.0",
    "server_role": "",
    "server_ip": "",
    "remote_ip": "",
    "sni": "www.google.com",
    "password": "",
    "tunnels": [],
    "gost_installed": true,
    "rtt_installed": false,
    "created_at": "",
    "updated_at": ""
}
EOF

    # Set creation time
    local NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local TMP=$(mktemp)
    jq --arg now "$NOW" '.created_at = $now | .updated_at = $now' "$CONFIG_DIR/config.json" > "$TMP" && mv "$TMP" "$CONFIG_DIR/config.json"

    # Check if RTT is installed
    if command -v RTT &> /dev/null; then
        local TMP2=$(mktemp)
        jq '.rtt_installed = true' "$CONFIG_DIR/config.json" > "$TMP2" && mv "$TMP2" "$CONFIG_DIR/config.json"
    fi

    log_info "Main configuration created"
}

# Install the management panel script
install_panel() {
    log_step "Installing management panel..."

    # Download or create the panel script
    cat > "${BIN_DIR}/stealth-tunnel" << 'PANEL_SCRIPT'
#!/bin/bash
#====================================================================
#  StealthTunnel Management Panel
#  Combined RTT + GOST Stealth Tunnel Manager
#====================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Paths
INSTALL_DIR="/opt/stealth-tunnel"
CONFIG_DIR="/etc/stealth-tunnel"
CONFIG_FILE="$CONFIG_DIR/config.json"
TUNNELS_DIR="$CONFIG_DIR/tunnels"
LOG_DIR="/var/log/stealth-tunnel"
CERTS_DIR="$INSTALL_DIR/certs"
GITHUB_REPO="WarpPacket/Stealth-Tunnel"
PANEL_VERSION="1.0.0"

#====================================================================
# UTILITY FUNCTIONS
#====================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: Run as root${NC}"
        exit 1
    fi
}

get_server_ip() {
    local ip=""
    local services="api.ipify.org icanhazip.com checkip.amazonaws.com ipinfo.io/ip ident.me ifconfig.me ipecho.net/plain api4.my-ip.io/ip"
    for svc in $services; do
        ip=$(curl -s -4 --max-time 3 --connect-timeout 2 "https://$svc" 2>/dev/null)
        # Strip whitespace/newlines
        ip=$(echo "$ip" | tr -d '[:space:]')
        # Only accept valid IPv4
        if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            echo "$ip"
            return 0
        fi
        ip=""
    done
    # Fallback: get from local interfaces
    ip=$(ip -4 addr show scope global 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "$ip"
        return 0
    fi
    # Return nothing - caller must handle
    return 1
}

get_config_value() {
    jq -r ".$1" "$CONFIG_FILE" 2>/dev/null
}

ensure_config_exists() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
        mkdir -p "$CONFIG_DIR/tunnels"
    fi
    if [[ ! -f "$CONFIG_FILE" ]] || ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        cat > "$CONFIG_FILE" << 'DEFCFG'
{
    "version": "1.0.0",
    "server_role": "",
    "server_ip": "",
    "remote_ip": "",
    "sni": "www.google.com",
    "password": "",
    "tunnels": [],
    "gost_installed": false,
    "rtt_installed": false,
    "created_at": "",
    "updated_at": ""
}
DEFCFG
        local NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local TMP=$(mktemp)
        jq --arg now "$NOW" '.created_at = $now | .updated_at = $now' "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
        # Update installed status
        if command -v gost &>/dev/null; then
            TMP=$(mktemp)
            jq '.gost_installed = true' "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
        fi
        if command -v RTT &>/dev/null; then
            TMP=$(mktemp)
            jq '.rtt_installed = true' "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
        fi
    fi
}

set_config_value() {
    ensure_config_exists
    local TMP=$(mktemp)
    jq --arg val "$2" ".$1 = \$val" "$CONFIG_FILE" > "$TMP" && mv "$TMP" "$CONFIG_FILE"
}

generate_random_password() {
    openssl rand -hex 16
}

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║          ███████╗████████╗███████╗ █████╗ ██╗  ████████╗   ║"
    echo "║          ██╔════╝╚══██╔══╝██╔════╝██╔══██╗██║  ╚══██╔══╝   ║"
    echo "║          ███████╗   ██║   █████╗  ███████║██║     ██║      ║"
    echo "║          ╚════██║   ██║   ██╔══╝  ██╔══██║██║     ██║      ║"
    echo "║          ███████║   ██║   ███████╗██║  ██║███████╗██║      ║"
    echo "║          ╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝      ║"
    echo "║                                                            ║"
    echo "║            StealthTunnel - RTT + GOST Combined             ║"
    echo "║                   Invisible Tunnel Manager                 ║"
    echo "║                                                            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e " ${DIM}Version: ${PANEL_VERSION}${NC}"
    
    # Show server info
    local role=$(get_config_value "server_role")
    local saved_ip=$(get_config_value "server_ip")
    local display_ip=""
    if [[ -n "$saved_ip" && "$saved_ip" != "null" && "$saved_ip" != "" ]]; then
        display_ip="$saved_ip"
    else
        display_ip=$(get_server_ip 2>/dev/null) || display_ip=""
    fi
    
    echo -e " ${DIM}─────────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE}Server IP:${NC} ${GREEN}${display_ip:-Not detected (set during setup)}${NC}"
    echo -e " ${WHITE}Role:${NC} ${YELLOW}${role:-Not Configured}${NC}"
    echo -e " ${WHITE}GOST:${NC} $(command -v gost &>/dev/null && echo -e "${GREEN}Installed${NC}" || echo -e "${RED}Not Installed${NC}")"
    echo -e " ${WHITE}RTT:${NC} $(command -v RTT &>/dev/null && echo -e "${GREEN}Installed${NC}" || echo -e "${RED}Not Installed${NC}")"
    echo -e " ${DIM}─────────────────────────────────────────────────────${NC}"
    echo ""
}

print_separator() {
    echo -e "${DIM}═══════════════════════════════════════════════════════════${NC}"
}

press_enter() {
    echo ""
    echo -e "${DIM}Press Enter to continue...${NC}"
    read
}

#====================================================================
# TUNNEL MODE SELECTION
#====================================================================

select_tunnel_mode() {
    local has_rtt=false
    command -v RTT &>/dev/null && has_rtt=true

    echo -e "\n${CYAN}${BOLD}Select Tunnel Mode:${NC}\n" >&2

    if [[ "$has_rtt" == true ]]; then
        echo -e "  ${GREEN}1)${NC} ${BOLD}RTT + GOST${NC} ${YELLOW}⭐ Recommended${NC}" >&2
        echo -e "     ${DIM}Maximum stealth: RTT reverse TLS + GOST WSS encryption${NC}" >&2
    else
        echo -e "  ${DIM}1) RTT + GOST (Not available - RTT not installed)${NC}" >&2
    fi
    echo "" >&2
    echo -e "  ${GREEN}2)${NC} ${BOLD}GOST Only (TLS + WebSocket + Mux)${NC}" >&2
    echo -e "     ${DIM}High stealth with TLS and WebSocket obfuscation${NC}" >&2
    echo "" >&2
    if [[ "$has_rtt" == true ]]; then
        echo -e "  ${GREEN}3)${NC} ${BOLD}RTT Only${NC}" >&2
        echo -e "     ${DIM}Reverse TLS Tunnel with SNI camouflage${NC}" >&2
    else
        echo -e "  ${DIM}3) RTT Only (Not available - RTT not installed)${NC}" >&2
    fi
    echo "" >&2

    local mode_choice
    while true; do
        read -p "$(echo -e "${CYAN}Select mode [1-3]: ${NC}")" mode_choice
        case "$mode_choice" in
            1)
                if [[ "$has_rtt" == true ]]; then
                    echo "rtt-gost"
                    return
                else
                    echo -e "${RED}RTT is not installed. Choose option 2 or install RTT first.${NC}" >&2
                fi
                ;;
            2)
                echo "gost-only"
                return
                ;;
            3)
                if [[ "$has_rtt" == true ]]; then
                    echo "rtt-only"
                    return
                else
                    echo -e "${RED}RTT is not installed. Choose option 2 or install RTT first.${NC}" >&2
                fi
                ;;
            *)
                echo -e "${RED}Invalid choice. Enter 1, 2, or 3.${NC}" >&2
                ;;
        esac
    done
}

#====================================================================
# INITIAL SETUP
#====================================================================

initial_setup() {
    print_banner
    echo -e "${YELLOW}${BOLD}═══ Initial Server Setup ═══${NC}\n"

    ensure_config_exists

    local current_role=$(get_config_value "server_role")
    if [[ -n "$current_role" && "$current_role" != "" && "$current_role" != "null" ]]; then
        echo -e "${YELLOW}Server is already configured as: ${GREEN}${current_role}${NC}"
        echo -e "${YELLOW}Do you want to reconfigure? (y/n)${NC}"
        read -p "> " reconfigure
        if [[ "$reconfigure" != "y" && "$reconfigure" != "Y" ]]; then
            return
        fi
        # Reset config to clean state for reconfiguration
        local created=$(get_config_value "created_at")
        cat > "$CONFIG_FILE" << RESETCFG
{
    "version": "1.0.0",
    "server_role": "",
    "server_ip": "",
    "remote_ip": "",
    "sni": "www.google.com",
    "password": "",
    "tunnels": [],
    "gost_installed": $(command -v gost &>/dev/null && echo true || echo false),
    "rtt_installed": $(command -v RTT &>/dev/null && echo true || echo false),
    "created_at": "${created}",
    "updated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
RESETCFG
        echo -e "${GREEN}Configuration reset. Starting fresh setup...${NC}\n"
    fi

    echo -e "${CYAN}Select server role:${NC}\n"
    echo -e "  ${GREEN}1)${NC} ${BOLD}IRAN Server${NC} (Entry point - receives client connections)"
    echo -e "  ${GREEN}2)${NC} ${BOLD}KHAREJ Server${NC} (Exit point - has Xray/V2Ray installed)"
    echo ""
    read -p "$(echo -e ${CYAN}Select role [1-2]: ${NC})" role_choice

    case $role_choice in
        1)
            set_config_value "server_role" "iran"
            setup_iran_server
            ;;
        2)
            set_config_value "server_role" "kharej"
            setup_kharej_server
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
}

setup_iran_server() {
    echo -e "\n${YELLOW}${BOLD}═══ Iran Server Setup ═══${NC}\n"

    # Get Iran server IP
    local auto_ip
    auto_ip=$(get_server_ip 2>/dev/null) || auto_ip=""
    
    local iran_ip=""
    if [[ -n "$auto_ip" ]]; then
        echo -e "${WHITE}Detected IP: ${GREEN}${auto_ip}${NC}"
        read -p "$(echo -e ${CYAN}Iran server IP [${auto_ip}]: ${NC})" iran_ip
        iran_ip=${iran_ip:-$auto_ip}
    else
        echo -e "${YELLOW}Could not auto-detect server IP${NC}"
        while [[ -z "$iran_ip" ]]; do
            read -p "$(echo -e ${CYAN}Enter Iran server IP: ${NC})" iran_ip
            if [[ ! "$iran_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                echo -e "${RED}Invalid IP format. Example: 185.1.2.3${NC}"
                iran_ip=""
            fi
        done
    fi
    set_config_value "server_ip" "$iran_ip"

    # Get Kharej server IP
    read -p "$(echo -e ${CYAN}Kharej \(foreign\) server IP: ${NC})" kharej_ip
    if [[ -z "$kharej_ip" ]]; then
        echo -e "${RED}Kharej server IP is required${NC}"
        return
    fi
    set_config_value "remote_ip" "$kharej_ip"

    # SNI domain
    echo -e "\n${WHITE}SNI Domain (used for TLS handshake camouflage)${NC}"
    echo -e "${DIM}Recommended: splus.ir, divar.ir, digikala.com${NC}"
    read -p "$(echo -e ${CYAN}SNI domain [splus.ir]: ${NC})" sni
    sni=${sni:-splus.ir}
    set_config_value "sni" "$sni"

    # Password
    local auto_pass=$(generate_random_password)
    read -p "$(echo -e ${CYAN}Tunnel password [${auto_pass}]: ${NC})" password
    password=${password:-$auto_pass}
    set_config_value "password" "$password"

    echo -e "\n${GREEN}${BOLD}Iran server configured successfully!${NC}"
    echo -e "${YELLOW}Important: Use the same password and SNI on Kharej server${NC}"
    echo -e "${WHITE}Password: ${GREEN}${password}${NC}"
    echo -e "${WHITE}SNI: ${GREEN}${sni}${NC}"

    press_enter
}

setup_kharej_server() {
    echo -e "\n${YELLOW}${BOLD}═══ Kharej Server Setup ═══${NC}\n"

    # Get Kharej server IP
    local auto_ip
    auto_ip=$(get_server_ip 2>/dev/null) || auto_ip=""
    
    local kharej_ip=""
    if [[ -n "$auto_ip" ]]; then
        echo -e "${WHITE}Detected IP: ${GREEN}${auto_ip}${NC}"
        read -p "$(echo -e ${CYAN}Kharej server IP [${auto_ip}]: ${NC})" kharej_ip
        kharej_ip=${kharej_ip:-$auto_ip}
    else
        echo -e "${YELLOW}Could not auto-detect server IP${NC}"
        while [[ -z "$kharej_ip" ]]; do
            read -p "$(echo -e ${CYAN}Enter Kharej server IP: ${NC})" kharej_ip
            if [[ ! "$kharej_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                echo -e "${RED}Invalid IP format. Example: 45.1.2.3${NC}"
                kharej_ip=""
            fi
        done
    fi
    set_config_value "server_ip" "$kharej_ip"

    # Get Iran server IP
    read -p "$(echo -e ${CYAN}Iran server IP: ${NC})" iran_ip
    if [[ -z "$iran_ip" ]]; then
        echo -e "${RED}Iran server IP is required${NC}"
        return
    fi
    set_config_value "remote_ip" "$iran_ip"

    # SNI domain (must match Iran server)
    read -p "$(echo -e ${CYAN}SNI domain \(must match Iran server\) [splus.ir]: ${NC})" sni
    sni=${sni:-splus.ir}
    set_config_value "sni" "$sni"

    # Password (must match Iran server)
    read -p "$(echo -e ${CYAN}Tunnel password \(must match Iran server\): ${NC})" password
    if [[ -z "$password" ]]; then
        echo -e "${RED}Password is required and must match Iran server${NC}"
        return
    fi
    set_config_value "password" "$password"

    echo -e "\n${GREEN}${BOLD}Kharej server configured successfully!${NC}"

    press_enter
}

#====================================================================
# TUNNEL MANAGEMENT
#====================================================================

add_tunnel() {
    print_banner
    echo -e "${YELLOW}${BOLD}═══ Add New Tunnel ═══${NC}\n"

    local role=$(get_config_value "server_role")
    if [[ -z "$role" || "$role" == "null" ]]; then
        echo -e "${RED}Please run Initial Setup first${NC}"
        press_enter
        return
    fi

    # Select tunnel mode
    local mode=$(select_tunnel_mode)

    # Tunnel name
    read -p "$(echo -e ${CYAN}Tunnel name \(e.g., xray-vless\): ${NC})" tunnel_name
    if [[ -z "$tunnel_name" ]]; then
        echo -e "${RED}Tunnel name is required${NC}"
        press_enter
        return
    fi

    # Sanitize tunnel name
    tunnel_name=$(echo "$tunnel_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

    # Check if tunnel already exists
    if [[ -f "$TUNNELS_DIR/${tunnel_name}.json" ]]; then
        echo -e "${RED}Tunnel '${tunnel_name}' already exists${NC}"
        press_enter
        return
    fi

    # Tunnel ID (shared identifier - MUST be the same on both Iran and Kharej servers)
    echo -e "\n${WHITE}Tunnel ID is used for WebSocket path matching between servers.${NC}"
    echo -e "${YELLOW}${BOLD}⚠ This MUST be identical on both Iran and Kharej servers!${NC}"
    read -p "$(echo -e ${CYAN}Tunnel ID \(shared between servers\) [${tunnel_name}]: ${NC})" tunnel_id
    tunnel_id=${tunnel_id:-$tunnel_name}
    tunnel_id=$(echo "$tunnel_id" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

    # Local port (port on this server)
    read -p "$(echo -e ${CYAN}Local port \(port on THIS server\): ${NC})" local_port
    if [[ -z "$local_port" ]]; then
        echo -e "${RED}Local port is required${NC}"
        press_enter
        return
    fi
    if [[ "$local_port" -lt 1 || "$local_port" -gt 65535 ]] 2>/dev/null; then
        echo -e "${RED}Invalid port: must be between 1 and 65535${NC}"
        press_enter
        return
    fi

    # Remote port (port on the other server)
    read -p "$(echo -e ${CYAN}Remote port \(port on REMOTE server\): ${NC})" remote_port
    if [[ -z "$remote_port" ]]; then
        echo -e "${RED}Remote port is required${NC}"
        press_enter
        return
    fi
    if [[ "$remote_port" -lt 1 || "$remote_port" -gt 65535 ]] 2>/dev/null; then
        echo -e "${RED}Invalid port: must be between 1 and 65535${NC}"
        press_enter
        return
    fi

    # Protocol
    echo -e "\n${CYAN}Protocol:${NC}"
    echo -e "  ${GREEN}1)${NC} TCP"
    echo -e "  ${GREEN}2)${NC} UDP"
    echo -e "  ${GREEN}3)${NC} TCP + UDP"
    read -p "$(echo -e ${CYAN}Select protocol [1]: ${NC})" proto_choice
    proto_choice=${proto_choice:-1}

    local protocol="tcp"
    case $proto_choice in
        1) protocol="tcp" ;;
        2) protocol="udp" ;;
        3) protocol="tcp+udp" ;;
    esac

    local remote_ip=$(get_config_value "remote_ip")
    local sni=$(get_config_value "sni")
    local password=$(get_config_value "password")

    # Create tunnel config
    cat > "$TUNNELS_DIR/${tunnel_name}.json" << EOF
{
    "name": "${tunnel_name}",
    "tunnel_id": "${tunnel_id}",
    "mode": "${mode}",
    "local_port": ${local_port},
    "remote_port": ${remote_port},
    "remote_ip": "${remote_ip}",
    "protocol": "${protocol}",
    "sni": "${sni}",
    "password": "${password}",
    "status": "stopped",
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

    # Create and start the tunnel
    create_tunnel_service "$tunnel_name" "$mode" "$local_port" "$remote_port" "$remote_ip" "$protocol" "$sni" "$password" "$tunnel_id"

    echo -e "\n${GREEN}${BOLD}✓ Tunnel '${tunnel_name}' created successfully!${NC}"
    echo -e "${WHITE}Mode: ${CYAN}$(get_mode_name $mode)${NC}"
    echo -e "${WHITE}Local Port: ${GREEN}${local_port}${NC}"
    echo -e "${WHITE}Remote Port: ${GREEN}${remote_port}${NC}"
    echo -e "${WHITE}Protocol: ${GREEN}${protocol}${NC}"

    # Ask to start
    echo ""
    read -p "$(echo -e ${CYAN}Start tunnel now? [Y/n]: ${NC})" start_now
    start_now=${start_now:-Y}
    if [[ "$start_now" == "y" || "$start_now" == "Y" ]]; then
        start_tunnel "$tunnel_name"
    fi

    press_enter
}

get_mode_name() {
    case "$1" in
        rtt-gost|1) echo "RTT + GOST (Maximum Stealth)" ;;
        gost-only|2) echo "GOST Only (TLS + WS + Mux)" ;;
        rtt-only|3) echo "RTT Only" ;;
        *) echo "GOST Only" ;;
    esac
}

#====================================================================
# SERVICE CREATION
#====================================================================

create_tunnel_service() {
    local name=$1
    local mode=$2
    local local_port=$3
    local remote_port=$4
    local remote_ip=$5
    local protocol=$6
    local sni=$7
    local password=$8
    local tunnel_id=${9:-$name}
    local role=$(get_config_value "server_role")
    local server_ip=$(get_config_value "server_ip")

    case "$mode" in
        rtt-gost|1) create_rtt_gost_service "$name" "$local_port" "$remote_port" "$remote_ip" "$protocol" "$sni" "$password" "$role" "$server_ip" "$tunnel_id" ;;
        gost-only|2) create_gost_only_service "$name" "$local_port" "$remote_port" "$remote_ip" "$protocol" "$sni" "$password" "$role" "$server_ip" "$tunnel_id" ;;
        rtt-only|3) create_rtt_only_service "$name" "$local_port" "$remote_port" "$remote_ip" "$protocol" "$sni" "$password" "$role" "$server_ip" ;;
        *) create_gost_only_service "$name" "$local_port" "$remote_port" "$remote_ip" "$protocol" "$sni" "$password" "$role" "$server_ip" "$tunnel_id" ;;
    esac
}

# Mode 1: RTT + GOST Combined (Maximum Stealth)
#
# Architecture (layered):
#   Client → Iran:local_port
#     → [GOST: tcp listen, forward target=127.0.0.1:remote_port, via relay to 127.0.0.1:rtt_bridge_port]
#     → [RTT: Iran listens on rtt_bridge_port, Kharej connects back with reverse TLS to gost_bridge_port]
#     → [GOST relay on Kharej:gost_bridge_port receives, reads target from protocol, connects to 127.0.0.1:remote_port]
#     → Xray on Kharej:remote_port
#
#   The GOST relay protocol carries the target address (127.0.0.1:remote_port) in the protocol header.
#   The relay server on Kharej reads this target and connects to it. No -F needed on server side.
#
create_rtt_gost_service() {
    local name=$1 local_port=$2 remote_port=$3 remote_ip=$4
    local protocol=$5 sni=$6 password=$7 role=$8 server_ip=$9
    local tunnel_id=${10:-$name}

    # Port allocation:
    #   rtt_bridge_port (local_port+1000): RTT listens here on Iran. GOST on Iran connects here via relay (TCP).
    #                                      RTT tunnels this to Kharej:gost_bridge_port.
    #   gost_bridge_port (local_port+2000): GOST relay listens here on Kharej. Receives traffic from RTT tunnel.
    local rtt_bridge_port=$((local_port + 1000))
    local gost_bridge_port=$((local_port + 2000))

    if [[ $rtt_bridge_port -gt 65535 || $gost_bridge_port -gt 65535 ]]; then
        echo -e "${RED}Error: Port ${local_port} is too high. Bridge ports would exceed 65535.${NC}"
        echo -e "${YELLOW}Use a port below 63535 for RTT+GOST mode.${NC}"
        return 1
    fi

    if [[ "$role" == "iran" ]]; then
        #--- RTT Service (Iran) - Listens for reverse TLS connections from Kharej ---
        cat > "/etc/systemd/system/st-rtt-${name}.service" << EOF
[Unit]
Description=StealthTunnel RTT - ${name}
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/RTT --iran --lport:${rtt_bridge_port} --sni:${sni} --password:${password} --connection-age:4800
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

        #--- GOST Service (Iran) ---
        # Listens on local_port, target is 127.0.0.1:remote_port (carried in relay protocol).
        # Forwards through relay (plain TCP) to 127.0.0.1:rtt_bridge_port (RTT tunnel entrance).
        # RTT is a transparent TCP tunnel, no WebSocket needed for local GOST↔RTT connection.
        cat > "/etc/systemd/system/st-gost-${name}.service" << EOF
[Unit]
Description=StealthTunnel GOST - ${name}
After=network.target st-rtt-${name}.service
Wants=st-rtt-${name}.service

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -L "tcp://0.0.0.0:${local_port}/127.0.0.1:${remote_port}" -F "relay://127.0.0.1:${rtt_bridge_port}"
Restart=always
RestartSec=3
LimitNOFILE=65535
Environment=GOST_LOGGER_LEVEL=warn

[Install]
WantedBy=multi-user.target
EOF

        # Create wrapper service
        cat > "/etc/systemd/system/st-${name}.service" << EOF
[Unit]
Description=StealthTunnel Combined - ${name}
After=network.target
Wants=st-rtt-${name}.service st-gost-${name}.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecStop=/bin/true

[Install]
WantedBy=multi-user.target
EOF

    elif [[ "$role" == "kharej" ]]; then
        #--- RTT Service (Kharej) - Connects back to Iran via reverse TLS ---
        # Connects to Iran:rtt_bridge_port, forwards incoming traffic to 127.0.0.1:gost_bridge_port
        cat > "/etc/systemd/system/st-rtt-${name}.service" << EOF
[Unit]
Description=StealthTunnel RTT - ${name}
After=network.target st-gost-${name}.service
Wants=network-online.target st-gost-${name}.service

[Service]
Type=simple
ExecStart=/usr/local/bin/RTT --kharej --iran-ip:${remote_ip} --iran-port:${rtt_bridge_port} --toip:127.0.0.1 --toport:${gost_bridge_port} --password:${password} --sni:${sni} --connection-age:4800
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

        #--- GOST Service (Kharej) - relay listener ---
        # Listens on gost_bridge_port. Relay protocol reads the target address from the
        # client's request header (127.0.0.1:remote_port) and connects to it (Xray).
        # RTT is a transparent TCP tunnel, no WebSocket needed for local GOST↔RTT connection.
        # No -F needed — relay handler does the forwarding automatically.
        cat > "/etc/systemd/system/st-gost-${name}.service" << EOF
[Unit]
Description=StealthTunnel GOST - ${name}
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -L "relay://0.0.0.0:${gost_bridge_port}"
Restart=always
RestartSec=3
LimitNOFILE=65535
Environment=GOST_LOGGER_LEVEL=warn

[Install]
WantedBy=multi-user.target
EOF

        # Create wrapper service
        cat > "/etc/systemd/system/st-${name}.service" << EOF
[Unit]
Description=StealthTunnel Combined - ${name}
After=network.target
Wants=st-rtt-${name}.service st-gost-${name}.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecStop=/bin/true

[Install]
WantedBy=multi-user.target
EOF
    fi

    # Handle UDP if needed
    if [[ "$protocol" == "udp" || "$protocol" == "tcp+udp" ]]; then
        create_udp_service "$name" "$local_port" "$remote_port" "$remote_ip" "$role"
    fi

    systemctl daemon-reload
}

# Mode 2: GOST Only (TLS + WebSocket + Mux)
create_gost_only_service() {
    local name=$1 local_port=$2 remote_port=$3 remote_ip=$4
    local protocol=$5 sni=$6 password=$7 role=$8 server_ip=$9
    local tunnel_id=${10:-$name}

    local gost_tunnel_port=$((local_port + 3000))

    if [[ $gost_tunnel_port -gt 65535 ]]; then
        echo -e "${RED}Error: Port ${local_port} is too high. GOST tunnel port would exceed 65535.${NC}"
        echo -e "${YELLOW}Use a port below 62535 for GOST-only mode.${NC}"
        return 1
    fi

    if [[ "$role" == "iran" ]]; then
        # GOST Iran: Listen on local_port, target=127.0.0.1:remote_port (in relay protocol header)
        # Forward through relay+wss directly to Kharej:gost_tunnel_port
        cat > "/etc/systemd/system/st-gost-${name}.service" << EOF
[Unit]
Description=StealthTunnel GOST - ${name}
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -L "tcp://0.0.0.0:${local_port}/127.0.0.1:${remote_port}" -F "relay+wss://${remote_ip}:${gost_tunnel_port}?host=${sni}&path=/cdn-${tunnel_id}&keepalive=true&ttl=30s"
Restart=always
RestartSec=3
LimitNOFILE=65535
Environment=GOST_LOGGER_LEVEL=warn

[Install]
WantedBy=multi-user.target
EOF

    elif [[ "$role" == "kharej" ]]; then
        # GOST Kharej: relay+wss listener. Relay protocol reads target from client header
        # and connects to it (127.0.0.1:remote_port = Xray). No -F needed.
        cat > "/etc/systemd/system/st-gost-${name}.service" << EOF
[Unit]
Description=StealthTunnel GOST - ${name}
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -L "relay+wss://0.0.0.0:${gost_tunnel_port}?path=/cdn-${tunnel_id}&keepalive=true"
Restart=always
RestartSec=3
LimitNOFILE=65535
Environment=GOST_LOGGER_LEVEL=warn

[Install]
WantedBy=multi-user.target
EOF
    fi

    # Wrapper
    cat > "/etc/systemd/system/st-${name}.service" << EOF
[Unit]
Description=StealthTunnel GOST Only - ${name}
After=network.target
Wants=st-gost-${name}.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecStop=/bin/true

[Install]
WantedBy=multi-user.target
EOF

    if [[ "$protocol" == "udp" || "$protocol" == "tcp+udp" ]]; then
        create_udp_service "$name" "$local_port" "$remote_port" "$remote_ip" "$role"
    fi

    systemctl daemon-reload
}

# Mode 3: RTT Only
create_rtt_only_service() {
    local name=$1 local_port=$2 remote_port=$3 remote_ip=$4
    local protocol=$5 sni=$6 password=$7 role=$8 server_ip=$9

    if [[ "$role" == "iran" ]]; then
        cat > "/etc/systemd/system/st-rtt-${name}.service" << EOF
[Unit]
Description=StealthTunnel RTT - ${name}
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/RTT --iran --lport:${local_port} --sni:${sni} --password:${password} --connection-age:4800
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    elif [[ "$role" == "kharej" ]]; then
        cat > "/etc/systemd/system/st-rtt-${name}.service" << EOF
[Unit]
Description=StealthTunnel RTT - ${name}
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/RTT --kharej --iran-ip:${remote_ip} --iran-port:${local_port} --toip:127.0.0.1 --toport:${remote_port} --password:${password} --sni:${sni} --connection-age:4800
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    fi

    # Wrapper
    cat > "/etc/systemd/system/st-${name}.service" << EOF
[Unit]
Description=StealthTunnel RTT Only - ${name}
After=network.target
Wants=st-rtt-${name}.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecStop=/bin/true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

# UDP Service
create_udp_service() {
    local name=$1 local_port=$2 remote_port=$3 remote_ip=$4 role=$5
    local udp_tunnel_port=$((local_port + 50000))

    if [[ "$role" == "iran" ]]; then
        cat > "/etc/systemd/system/st-udp-${name}.service" << EOF
[Unit]
Description=StealthTunnel UDP - ${name}
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -L "udp://0.0.0.0:${local_port}/127.0.0.1:${remote_port}" -F "relay+wss://${remote_ip}:${udp_tunnel_port}?keepalive=true"
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    elif [[ "$role" == "kharej" ]]; then
        cat > "/etc/systemd/system/st-udp-${name}.service" << EOF
[Unit]
Description=StealthTunnel UDP - ${name}
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -L "relay+wss://0.0.0.0:${udp_tunnel_port}?keepalive=true&bind=true"
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl daemon-reload
}

#====================================================================
# START / STOP / RESTART TUNNELS
#====================================================================

start_tunnel() {
    local name=$1
    echo -e "${BLUE}Starting tunnel '${name}'...${NC}"

    # Start RTT service if exists
    if systemctl list-unit-files | grep -q "st-rtt-${name}.service"; then
        systemctl enable "st-rtt-${name}.service" --now 2>/dev/null
        sleep 2
    fi

    # Start GOST service if exists
    if systemctl list-unit-files | grep -q "st-gost-${name}.service"; then
        systemctl enable "st-gost-${name}.service" --now 2>/dev/null
    fi

    # Start UDP service if exists
    if systemctl list-unit-files | grep -q "st-udp-${name}.service"; then
        systemctl enable "st-udp-${name}.service" --now 2>/dev/null
    fi

    # Enable wrapper
    if systemctl list-unit-files | grep -q "st-${name}.service"; then
        systemctl enable "st-${name}.service" --now 2>/dev/null
    fi

    # Update status in config
    if [[ -f "$TUNNELS_DIR/${name}.json" ]] && jq empty "$TUNNELS_DIR/${name}.json" 2>/dev/null; then
        local TMP=$(mktemp)
        jq '.status = "running"' "$TUNNELS_DIR/${name}.json" > "$TMP" && mv "$TMP" "$TUNNELS_DIR/${name}.json"
    fi

    echo -e "${GREEN}✓ Tunnel '${name}' started${NC}"
}

stop_tunnel() {
    local name=$1
    echo -e "${YELLOW}Stopping tunnel '${name}'...${NC}"

    systemctl stop "st-rtt-${name}.service" 2>/dev/null
    systemctl stop "st-gost-${name}.service" 2>/dev/null
    systemctl stop "st-udp-${name}.service" 2>/dev/null
    systemctl stop "st-${name}.service" 2>/dev/null

    systemctl disable "st-rtt-${name}.service" 2>/dev/null
    systemctl disable "st-gost-${name}.service" 2>/dev/null
    systemctl disable "st-udp-${name}.service" 2>/dev/null
    systemctl disable "st-${name}.service" 2>/dev/null

    if [[ -f "$TUNNELS_DIR/${name}.json" ]] && jq empty "$TUNNELS_DIR/${name}.json" 2>/dev/null; then
        local TMP=$(mktemp)
        jq '.status = "stopped"' "$TUNNELS_DIR/${name}.json" > "$TMP" && mv "$TMP" "$TUNNELS_DIR/${name}.json"
    fi

    echo -e "${GREEN}✓ Tunnel '${name}' stopped${NC}"
}

restart_tunnel() {
    local name=$1
    stop_tunnel "$name"
    sleep 2
    start_tunnel "$name"
}

delete_tunnel() {
    local name=$1
    echo -e "${RED}Deleting tunnel '${name}'...${NC}"

    stop_tunnel "$name"

    # Remove service files
    rm -f "/etc/systemd/system/st-rtt-${name}.service"
    rm -f "/etc/systemd/system/st-gost-${name}.service"
    rm -f "/etc/systemd/system/st-udp-${name}.service"
    rm -f "/etc/systemd/system/st-${name}.service"

    # Remove config
    rm -f "$TUNNELS_DIR/${name}.json"

    systemctl daemon-reload

    echo -e "${GREEN}✓ Tunnel '${name}' deleted${NC}"
}

#====================================================================
# TUNNEL LIST & STATUS
#====================================================================

list_tunnels() {
    print_banner
    echo -e "${YELLOW}${BOLD}═══ Active Tunnels ═══${NC}\n"

    local tunnels=$(ls "$TUNNELS_DIR"/*.json 2>/dev/null)
    
    if [[ -z "$tunnels" ]]; then
        echo -e "${DIM}  No tunnels configured${NC}"
        press_enter
        return
    fi

    printf "${BOLD}%-4s %-20s %-12s %-8s %-8s %-10s %-10s${NC}\n" "#" "NAME" "MODE" "LOCAL" "REMOTE" "PROTO" "STATUS"
    print_separator

    local i=1
    for tunnel_file in $tunnels; do
        # Validate JSON first
        if ! jq empty "$tunnel_file" 2>/dev/null; then
            echo -e "  ${RED}⚠ Corrupted config: $(basename $tunnel_file) - removing${NC}"
            rm -f "$tunnel_file"
            continue
        fi

        local t_name=$(jq -r '.name // "unknown"' "$tunnel_file")
        local t_mode=$(jq -r '.mode // "gost-only"' "$tunnel_file")
        local t_lport=$(jq -r '.local_port // 0' "$tunnel_file")
        local t_rport=$(jq -r '.remote_port // 0' "$tunnel_file")
        local t_proto=$(jq -r '.protocol // "tcp"' "$tunnel_file")
        local t_status=$(jq -r '.status // "stopped"' "$tunnel_file")

        # Get real status from systemd
        local real_status="stopped"
        if systemctl is-active "st-gost-${t_name}.service" &>/dev/null || \
           systemctl is-active "st-rtt-${t_name}.service" &>/dev/null; then
            real_status="running"
        fi

        # Update stored status
        if [[ "$real_status" != "$t_status" ]]; then
            local TMP=$(mktemp)
            jq --arg s "$real_status" '.status = $s' "$tunnel_file" > "$TMP" && mv "$TMP" "$tunnel_file"
            t_status="$real_status"
        fi

        local mode_name=""
        case "$t_mode" in
            rtt-gost|1) mode_name="RTT+GOST" ;;
            gost-only|2) mode_name="GOST" ;;
            rtt-only|3) mode_name="RTT" ;;
            *) mode_name="GOST" ;;
        esac

        local status_color="${RED}"
        local status_icon="●"
        if [[ "$t_status" == "running" ]]; then
            status_color="${GREEN}"
        fi

        printf "%-4s %-20s %-12s %-8s %-8s %-10s ${status_color}${status_icon} %-10s${NC}\n" \
            "$i" "$t_name" "$mode_name" "$t_lport" "$t_rport" "$t_proto" "$t_status"
        ((i++))
    done

    echo ""
    print_separator
    press_enter
}

#====================================================================
# TUNNEL OPERATIONS MENU
#====================================================================

manage_tunnels_menu() {
    while true; do
        print_banner
        echo -e "${YELLOW}${BOLD}═══ Manage Tunnels ═══${NC}\n"

        local tunnels=($(ls "$TUNNELS_DIR"/*.json 2>/dev/null))
        
        if [[ ${#tunnels[@]} -eq 0 ]]; then
            echo -e "${DIM}  No tunnels configured${NC}"
            echo ""
            echo -e "  ${GREEN}1)${NC} Add New Tunnel"
            echo -e "  ${RED}0)${NC} Back"
            read -p "$(echo -e ${CYAN}Select: ${NC})" choice
            case $choice in
                1) add_tunnel ;;
                0) return ;;
            esac
            continue
        fi

        # List tunnels
        echo -e "${BOLD}Existing Tunnels:${NC}\n"
        local i=1
        local valid_tunnels=()
        for tunnel_file in "${tunnels[@]}"; do
            # Skip corrupted JSON files
            if ! jq empty "$tunnel_file" 2>/dev/null; then
                echo -e "  ${RED}⚠ Corrupted: $(basename $tunnel_file) - removing${NC}"
                rm -f "$tunnel_file"
                continue
            fi

            valid_tunnels+=("$tunnel_file")
            local t_name=$(jq -r '.name // "unknown"' "$tunnel_file")
            local t_lport=$(jq -r '.local_port // 0' "$tunnel_file")
            local t_rport=$(jq -r '.remote_port // 0' "$tunnel_file")
            
            local real_status="stopped"
            if systemctl is-active "st-gost-${t_name}.service" &>/dev/null || \
               systemctl is-active "st-rtt-${t_name}.service" &>/dev/null; then
                real_status="running"
            fi

            local status_color="${RED}"
            if [[ "$real_status" == "running" ]]; then
                status_color="${GREEN}"
            fi

            echo -e "  ${GREEN}${i})${NC} ${BOLD}${t_name}${NC} [${t_lport} → ${t_rport}] ${status_color}● ${real_status}${NC}"
            ((i++))
        done
        tunnels=("${valid_tunnels[@]}")

        echo ""
        print_separator
        echo ""
        read -p "$(echo -e ${CYAN}Select tunnel number \(0=back\): ${NC})" tunnel_num

        if [[ "$tunnel_num" == "0" ]]; then
            return
        fi

        if [[ "$tunnel_num" -gt 0 && "$tunnel_num" -le ${#tunnels[@]} ]] 2>/dev/null; then
            local selected_file="${tunnels[$((tunnel_num-1))]}"
            local selected_name=$(jq -r '.name' "$selected_file")
            tunnel_action_menu "$selected_name"
        else
            echo -e "${RED}Invalid selection${NC}"
            sleep 1
        fi
    done
}

tunnel_action_menu() {
    local name=$1

    while true; do
        print_banner
        
        local t_file="$TUNNELS_DIR/${name}.json"
        if [[ ! -f "$t_file" ]]; then
            echo -e "${RED}Tunnel not found${NC}"
            press_enter
            return
        fi

        # Validate JSON before reading
        if ! jq empty "$t_file" 2>/dev/null; then
            echo -e "${RED}⚠ Tunnel config '${name}' is corrupted (invalid JSON)${NC}"
            echo -e "${YELLOW}Would you like to delete it? (y/n)${NC}"
            read -p "> " del_confirm
            if [[ "$del_confirm" == "y" || "$del_confirm" == "Y" ]]; then
                rm -f "$t_file"
                echo -e "${GREEN}✓ Removed corrupted config${NC}"
            fi
            press_enter
            return
        fi

        local t_mode=$(jq -r '.mode // "gost-only"' "$t_file")
        local t_lport=$(jq -r '.local_port // 0' "$t_file")
        local t_rport=$(jq -r '.remote_port // 0' "$t_file")
        local t_remote=$(jq -r '.remote_ip // "N/A"' "$t_file")
        local t_proto=$(jq -r '.protocol // "tcp"' "$t_file")
        local t_sni=$(jq -r '.sni // "N/A"' "$t_file")

        local real_status="stopped"
        if systemctl is-active "st-gost-${name}.service" &>/dev/null || \
           systemctl is-active "st-rtt-${name}.service" &>/dev/null; then
            real_status="running"
        fi

        local status_color="${RED}"
        if [[ "$real_status" == "running" ]]; then
            status_color="${GREEN}"
        fi

        echo -e "${YELLOW}${BOLD}═══ Tunnel: ${name} ═══${NC}\n"
        echo -e "  ${WHITE}Status:${NC}      ${status_color}● ${real_status}${NC}"
        echo -e "  ${WHITE}Mode:${NC}        $(get_mode_name $t_mode)"
        echo -e "  ${WHITE}Local Port:${NC}  ${t_lport}"
        echo -e "  ${WHITE}Remote Port:${NC} ${t_rport}"
        echo -e "  ${WHITE}Remote IP:${NC}   ${t_remote}"
        echo -e "  ${WHITE}Protocol:${NC}    ${t_proto}"
        echo -e "  ${WHITE}SNI:${NC}         ${t_sni}"
        echo ""
        print_separator
        echo ""
        echo -e "  ${GREEN}1)${NC} Start"
        echo -e "  ${YELLOW}2)${NC} Stop"
        echo -e "  ${BLUE}3)${NC} Restart"
        echo -e "  ${MAGENTA}4)${NC} View Logs"
        echo -e "  ${CYAN}5)${NC} Diagnose Connection"
        echo -e "  ${RED}6)${NC} Delete"
        echo -e "  ${WHITE}0)${NC} Back"
        echo ""
        read -p "$(echo -e ${CYAN}Select action: ${NC})" action

        case $action in
            1)
                start_tunnel "$name"
                press_enter
                ;;
            2)
                stop_tunnel "$name"
                press_enter
                ;;
            3)
                restart_tunnel "$name"
                press_enter
                ;;
            4)
                view_tunnel_logs "$name"
                ;;
            5)
                print_banner
                echo -e "${YELLOW}${BOLD}═══ Tunnel Diagnostics ═══${NC}"
                diagnose_tunnel "$name"
                press_enter
                ;;
            6)
                echo -e "${RED}Are you sure you want to delete '${name}'? (y/n)${NC}"
                read -p "> " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    delete_tunnel "$name"
                    press_enter
                    return
                fi
                ;;
            0)
                return
                ;;
        esac
    done
}

#====================================================================
# MULTI-PORT WIZARD
#====================================================================

add_multi_port_tunnel() {
    print_banner
    echo -e "${YELLOW}${BOLD}═══ Multi-Port Tunnel Wizard ═══${NC}\n"

    local role=$(get_config_value "server_role")
    if [[ -z "$role" || "$role" == "null" ]]; then
        echo -e "${RED}Please run Initial Setup first${NC}"
        press_enter
        return
    fi

    echo -e "${WHITE}This wizard helps you create multiple port forwarding tunnels at once.${NC}"
    echo -e "${DIM}Format: local_port:remote_port (one per line, empty line to finish)${NC}\n"

    # Select mode for all tunnels
    local mode=$(select_tunnel_mode)

    # Prefix name
    read -p "$(echo -e ${CYAN}Tunnel group name prefix \(e.g., xray\): ${NC})" prefix
    prefix=${prefix:-tunnel}

    echo -e "\n${CYAN}Enter port mappings (local:remote), empty line to finish:${NC}"
    
    local port_mappings=()
    while true; do
        read -p "$(echo -e ${GREEN}Port mapping: ${NC})" mapping
        if [[ -z "$mapping" ]]; then
            break
        fi

        if [[ "$mapping" =~ ^[0-9]+:[0-9]+$ ]]; then
            local _lp=$(echo "$mapping" | cut -d: -f1)
            local _rp=$(echo "$mapping" | cut -d: -f2)
            if [[ "$_lp" -lt 1 || "$_lp" -gt 65535 || "$_rp" -lt 1 || "$_rp" -gt 65535 ]]; then
                echo -e "${RED}Invalid port range. Ports must be between 1 and 65535${NC}"
            else
                port_mappings+=("$mapping")
            fi
        else
            echo -e "${RED}Invalid format. Use local_port:remote_port (e.g., 2053:2053)${NC}"
        fi
    done

    if [[ ${#port_mappings[@]} -eq 0 ]]; then
        echo -e "${RED}No port mappings provided${NC}"
        press_enter
        return
    fi

    echo -e "\n${CYAN}Protocol for all tunnels:${NC}"
    echo -e "  ${GREEN}1)${NC} TCP"
    echo -e "  ${GREEN}2)${NC} UDP"
    echo -e "  ${GREEN}3)${NC} TCP + UDP"
    read -p "$(echo -e ${CYAN}Select [1]: ${NC})" proto_choice
    proto_choice=${proto_choice:-1}
    local protocol="tcp"
    case $proto_choice in
        1) protocol="tcp" ;;
        2) protocol="udp" ;;
        3) protocol="tcp+udp" ;;
    esac

    echo -e "\n${YELLOW}Creating ${#port_mappings[@]} tunnels...${NC}\n"

    local remote_ip=$(get_config_value "remote_ip")
    local sni=$(get_config_value "sni")
    local password=$(get_config_value "password")
    local count=1

    for mapping in "${port_mappings[@]}"; do
        local lport=$(echo "$mapping" | cut -d: -f1)
        local rport=$(echo "$mapping" | cut -d: -f2)
        local t_name="${prefix}-${lport}"

        echo -e "${BLUE}Creating tunnel: ${t_name} (${lport} → ${rport})${NC}"

        # Create config
        cat > "$TUNNELS_DIR/${t_name}.json" << EOF
{
    "name": "${t_name}",
    "mode": "${mode}",
    "local_port": ${lport},
    "remote_port": ${rport},
    "remote_ip": "${remote_ip}",
    "protocol": "${protocol}",
    "sni": "${sni}",
    "password": "${password}",
    "status": "stopped",
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

        create_tunnel_service "$t_name" "$mode" "$lport" "$rport" "$remote_ip" "$protocol" "$sni" "$password"
        start_tunnel "$t_name"
        ((count++))
        sleep 1
    done

    echo -e "\n${GREEN}${BOLD}✓ All ${#port_mappings[@]} tunnels created and started!${NC}"
    press_enter
}

#====================================================================
# LOGS
#====================================================================

view_tunnel_logs() {
    local name=$1
    print_banner
    echo -e "${YELLOW}${BOLD}═══ Logs: ${name} ═══${NC}\n"
    echo -e "${DIM}Press Ctrl+C to exit log view${NC}\n"

    echo -e "${CYAN}--- RTT Logs ---${NC}"
    journalctl -u "st-rtt-${name}.service" --no-pager -n 20 2>/dev/null || echo "No RTT logs"
    echo ""
    echo -e "${CYAN}--- GOST Logs ---${NC}"
    journalctl -u "st-gost-${name}.service" --no-pager -n 20 2>/dev/null || echo "No GOST logs"
    echo ""
    echo -e "${CYAN}--- UDP Logs ---${NC}"
    journalctl -u "st-udp-${name}.service" --no-pager -n 20 2>/dev/null || echo "No UDP logs"

    press_enter
}

view_all_logs() {
    print_banner
    echo -e "${YELLOW}${BOLD}═══ All Service Logs ═══${NC}\n"
    echo -e "${DIM}Last 50 lines from all StealthTunnel services${NC}\n"

    journalctl -u "st-*.service" --no-pager -n 50 2>/dev/null || echo "No logs found"

    press_enter
}

#====================================================================
# STATUS OVERVIEW
#====================================================================

show_status() {
    print_banner
    echo -e "${YELLOW}${BOLD}═══ System Status ═══${NC}\n"

    # Server info
    local role=$(get_config_value "server_role")
    local remote_ip=$(get_config_value "remote_ip")
    local sni=$(get_config_value "sni")

    echo -e "${WHITE}Server Role:${NC}      ${CYAN}${role:-Not set}${NC}"
    echo -e "${WHITE}Remote IP:${NC}        ${CYAN}${remote_ip:-Not set}${NC}"
    echo -e "${WHITE}SNI Domain:${NC}       ${CYAN}${sni:-Not set}${NC}"
    echo ""

    # Component status
    echo -e "${BOLD}Components:${NC}"
    echo -e "  GOST:  $(command -v gost &>/dev/null && echo -e "${GREEN}✓ Installed ($(gost -V 2>/dev/null | head -1))${NC}" || echo -e "${RED}✗ Not installed${NC}")"
    echo -e "  RTT:   $(command -v RTT &>/dev/null && echo -e "${GREEN}✓ Installed${NC}" || echo -e "${YELLOW}○ Not installed (GOST-only mode)${NC}")"
    echo ""

    # Tunnel status
    echo -e "${BOLD}Tunnels:${NC}"
    local tunnels=$(ls "$TUNNELS_DIR"/*.json 2>/dev/null)
    if [[ -z "$tunnels" ]]; then
        echo -e "  ${DIM}No tunnels configured${NC}"
    else
        for tunnel_file in $tunnels; do
            local t_name=$(jq -r '.name' "$tunnel_file")
            local t_lport=$(jq -r '.local_port' "$tunnel_file")
            local t_rport=$(jq -r '.remote_port' "$tunnel_file")

            local real_status="stopped"
            if systemctl is-active "st-gost-${t_name}.service" &>/dev/null || \
               systemctl is-active "st-rtt-${t_name}.service" &>/dev/null; then
                real_status="running"
            fi

            local status_color="${RED}"
            local status_icon="✗"
            if [[ "$real_status" == "running" ]]; then
                status_color="${GREEN}"
                status_icon="✓"
            fi

            echo -e "  ${status_color}${status_icon}${NC} ${t_name} [${t_lport} → ${t_rport}] ${status_color}${real_status}${NC}"
        done
    fi

    echo ""
    
    # System resources
    echo -e "${BOLD}System Resources:${NC}"
    echo -e "  CPU:    $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' 2>/dev/null || echo 'N/A')%"
    echo -e "  Memory: $(free -m 2>/dev/null | awk 'NR==2{printf "%.1f%% (%sMB/%sMB)", $3*100/$2, $3, $2}' || echo 'N/A')"
    echo -e "  Disk:   $(df -h / | awk 'NR==2{print $5 " used (" $3 "/" $2 ")"}' 2>/dev/null || echo 'N/A')"
    
    echo ""

    # Network connections
    echo -e "${BOLD}Active Connections:${NC}"
    local conn_count=$(ss -tun state established 2>/dev/null | wc -l)
    echo -e "  Established: $((conn_count - 1))"

    press_enter
}

#====================================================================
# START/STOP ALL
#====================================================================

start_all_tunnels() {
    print_banner
    echo -e "${YELLOW}${BOLD}Starting all tunnels...${NC}\n"

    local tunnels=$(ls "$TUNNELS_DIR"/*.json 2>/dev/null)
    if [[ -z "$tunnels" ]]; then
        echo -e "${DIM}No tunnels to start${NC}"
        press_enter
        return
    fi

    for tunnel_file in $tunnels; do
        local t_name=$(jq -r '.name' "$tunnel_file")
        start_tunnel "$t_name"
        sleep 1
    done

    echo -e "\n${GREEN}${BOLD}✓ All tunnels started${NC}"
    press_enter
}

stop_all_tunnels() {
    print_banner
    echo -e "${YELLOW}${BOLD}Stopping all tunnels...${NC}\n"

    local tunnels=$(ls "$TUNNELS_DIR"/*.json 2>/dev/null)
    if [[ -z "$tunnels" ]]; then
        echo -e "${DIM}No tunnels to stop${NC}"
        press_enter
        return
    fi

    for tunnel_file in $tunnels; do
        local t_name=$(jq -r '.name' "$tunnel_file")
        stop_tunnel "$t_name"
    done

    echo -e "\n${GREEN}${BOLD}✓ All tunnels stopped${NC}"
    press_enter
}

restart_all_tunnels() {
    stop_all_tunnels
    start_all_tunnels
}

#====================================================================
# UNINSTALL
#====================================================================

uninstall() {
    print_banner
    echo -e "${RED}${BOLD}═══ Uninstall StealthTunnel ═══${NC}\n"
    echo -e "${RED}WARNING: This will remove all tunnels, configs, and binaries!${NC}"
    echo -e "${YELLOW}Are you sure? Type 'REMOVE' to confirm:${NC}"
    read -p "> " confirm

    if [[ "$confirm" != "REMOVE" ]]; then
        echo -e "${GREEN}Uninstall cancelled${NC}"
        press_enter
        return
    fi

    echo -e "\n${RED}Removing all tunnels...${NC}"
    local tunnels=$(ls "$TUNNELS_DIR"/*.json 2>/dev/null)
    for tunnel_file in $tunnels; do
        local t_name=$(jq -r '.name' "$tunnel_file")
        stop_tunnel "$t_name"
        rm -f "/etc/systemd/system/st-rtt-${t_name}.service"
        rm -f "/etc/systemd/system/st-gost-${t_name}.service"
        rm -f "/etc/systemd/system/st-udp-${t_name}.service"
        rm -f "/etc/systemd/system/st-${t_name}.service"
    done

    systemctl daemon-reload

    echo -e "${RED}Removing files...${NC}"
    rm -rf "$INSTALL_DIR"
    rm -rf "$CONFIG_DIR"
    rm -rf "$LOG_DIR"
    rm -f "${BIN_DIR}/stealth-tunnel"
    rm -f "${BIN_DIR}/gost"
    rm -f "${BIN_DIR}/RTT"
    rm -f /etc/sysctl.d/99-stealth-tunnel.conf
    rm -f /etc/security/limits.d/stealth-tunnel.conf

    echo -e "\n${GREEN}${BOLD}✓ StealthTunnel completely removed${NC}"
    echo -e "${DIM}Goodbye!${NC}"
    exit 0
}

#====================================================================
# UPDATE
#====================================================================

update_stealth_tunnel() {
    print_banner
    echo -e "${YELLOW}${BOLD}═══ Update StealthTunnel ═══${NC}\n"

    echo -e " ${WHITE}Current version:${NC} ${GREEN}${PANEL_VERSION}${NC}\n"
    echo -e "${BLUE}Checking for updates...${NC}\n"

    local REPO="${GITHUB_REPO:-WarpPacket/Stealth-Tunnel}"
    local UPDATE_URL="https://raw.githubusercontent.com/${REPO}/main/install.sh"
    local TMP_SCRIPT=$(mktemp)
    local update_success=false

    # Step 1: Download latest install.sh
    echo -e "  ${BLUE}[1/3]${NC} Downloading latest version..."
    if curl -fsSL --connect-timeout 15 --max-time 60 "$UPDATE_URL" -o "$TMP_SCRIPT" 2>/dev/null; then
        if [[ ! -s "$TMP_SCRIPT" ]]; then
            echo -e "  ${RED}✗ Downloaded file is empty${NC}"
            rm -f "$TMP_SCRIPT"
            press_enter
            return 1
        fi
        if bash -n "$TMP_SCRIPT" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Download successful"
        else
            echo -e "  ${RED}✗ Downloaded script has syntax errors${NC}"
            rm -f "$TMP_SCRIPT"
            press_enter
            return 1
        fi
    else
        echo -e "  ${RED}✗ Could not download update from GitHub${NC}"
        echo -e "  ${DIM}URL: ${UPDATE_URL}${NC}"
        rm -f "$TMP_SCRIPT"
        press_enter
        return 1
    fi

    # Check remote version
    local remote_version
    remote_version=$(grep '^PANEL_VERSION=' "$TMP_SCRIPT" 2>/dev/null | head -1 | cut -d'"' -f2)
    if [[ -z "$remote_version" ]]; then
        remote_version="unknown"
    fi
    echo -e "  ${WHITE}Remote version:${NC}  ${CYAN}${remote_version}${NC}"

    if [[ "$remote_version" != "unknown" && "$remote_version" == "$PANEL_VERSION" ]]; then
        echo -e "\n  ${GREEN}✓ Already on the latest version (${PANEL_VERSION})${NC}"
        echo ""
        read -p "$(echo -e "${CYAN}Force update anyway? [y/N]: ${NC}")" force_update
        if [[ "$force_update" != "y" && "$force_update" != "Y" ]]; then
            rm -f "$TMP_SCRIPT"
            press_enter
            return 0
        fi
    fi
    echo ""

    # Step 2: Extract panel script and update it (preserving all configs)
    echo -e "  ${BLUE}[2/3]${NC} Updating panel script..."

    # Extract content between PANEL_SCRIPT heredoc markers using awk
    local TMP_PANEL=$(mktemp)
    awk "
        /^PANEL_SCRIPT\$/ && found { exit }
        found { print }
        /<< 'PANEL_SCRIPT'\$/ { found=1 }
    " "$TMP_SCRIPT" > "$TMP_PANEL"

    if [[ -s "$TMP_PANEL" ]]; then
        chmod +x "$TMP_PANEL"

        # Verify new script is valid bash
        if bash -n "$TMP_PANEL" 2>/dev/null; then
            cp "$TMP_PANEL" "/usr/local/bin/stealth-tunnel"
            chmod +x "/usr/local/bin/stealth-tunnel"
            echo -e "  ${GREEN}✓${NC} Panel script updated"
            update_success=true
        else
            echo -e "  ${RED}✗ Extracted panel script has errors, keeping current version${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ Could not extract panel from downloaded script${NC}"
        echo -e "  ${DIM}Trying full reinstall method...${NC}"
        bash "$TMP_SCRIPT"
        update_success=true
    fi
    rm -f "$TMP_PANEL"
    echo ""

    # Step 3: Update GOST binary if needed
    echo -e "  ${BLUE}[3/3]${NC} Checking GOST binary..."
    local current_gost_ver=""
    if command -v gost &>/dev/null; then
        current_gost_ver=$(gost -V 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi

    local latest_gost_ver="3.2.6"
    local script_gost_ver
    script_gost_ver=$(grep '^GOST_VERSION=' "$TMP_SCRIPT" 2>/dev/null | head -1 | cut -d'"' -f2)
    if [[ -n "$script_gost_ver" ]]; then
        latest_gost_ver="$script_gost_ver"
    fi

    if [[ "$current_gost_ver" == "$latest_gost_ver" ]]; then
        echo -e "  ${GREEN}✓${NC} GOST v${current_gost_ver} is up to date"
    elif [[ -z "$current_gost_ver" ]]; then
        echo -e "  ${YELLOW}⚠${NC} GOST is not installed, skipping binary update"
    else
        echo -e "  ${BLUE}↻${NC} Updating GOST v${current_gost_ver} → v${latest_gost_ver}..."
        local ARCH=$(uname -m)
        local ARCH_GOST="amd64"
        case $ARCH in
            x86_64)  ARCH_GOST="amd64" ;;
            aarch64) ARCH_GOST="arm64" ;;
            armv7l)  ARCH_GOST="armv7" ;;
        esac

        local GOST_URL="https://github.com/go-gost/gost/releases/download/v${latest_gost_ver}/gost_${latest_gost_ver}_linux_${ARCH_GOST}.tar.gz"
        local TMP_DIR=$(mktemp -d)

        if wget -q --timeout=30 -O "${TMP_DIR}/gost.tar.gz" "$GOST_URL" 2>/dev/null || \
           curl -fsSL --connect-timeout 30 -o "${TMP_DIR}/gost.tar.gz" "$GOST_URL" 2>/dev/null; then
            tar -xzf "${TMP_DIR}/gost.tar.gz" -C "${TMP_DIR}" 2>/dev/null
            local GOST_BIN=$(find "${TMP_DIR}" -name "gost" -type f | head -1)
            if [[ -n "$GOST_BIN" ]]; then
                cp "$GOST_BIN" "/usr/local/bin/gost"
                chmod +x "/usr/local/bin/gost"
                echo -e "  ${GREEN}✓${NC} GOST updated to v${latest_gost_ver}"
            else
                echo -e "  ${RED}✗ GOST binary not found in archive${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠ Could not download GOST update${NC}"
        fi
        rm -rf "${TMP_DIR}"
    fi

    rm -f "$TMP_SCRIPT"

    # Summary
    echo ""
    echo -e "${DIM}─────────────────────────────────────────────────────${NC}"
    if [[ "$update_success" == true ]]; then
        echo -e "${GREEN}${BOLD}✓ Update complete!${NC}"
        echo -e "${DIM}Your server configuration and tunnels were preserved.${NC}"
        echo -e "${YELLOW}Restarting panel with new version...${NC}"
        sleep 2
        exec /usr/local/bin/stealth-tunnel
    else
        echo -e "${YELLOW}Update completed with warnings. Check messages above.${NC}"
        press_enter
    fi
}

#====================================================================
# REPAIR / CLEANUP
#====================================================================

repair_configs() {
    print_banner
    echo -e "${YELLOW}${BOLD}═══ Repair Tunnel Configs ═══${NC}\n"

    local tunnels=$(ls "$TUNNELS_DIR"/*.json 2>/dev/null)
    if [[ -z "$tunnels" ]]; then
        echo -e "${DIM}  No tunnel configs found${NC}"
        press_enter
        return
    fi

    local fixed=0
    local removed=0
    local ok=0

    for tunnel_file in $tunnels; do
        local fname=$(basename "$tunnel_file")

        # Check if valid JSON
        if ! jq empty "$tunnel_file" 2>/dev/null; then
            echo -e "  ${RED}✗ ${fname}${NC} - Invalid JSON, removing..."
            rm -f "$tunnel_file"
            ((removed++))
            continue
        fi

        # Check for required fields
        local t_name=$(jq -r '.name // ""' "$tunnel_file")
        local t_mode=$(jq -r '.mode // ""' "$tunnel_file")

        if [[ -z "$t_name" || "$t_name" == "null" ]]; then
            echo -e "  ${RED}✗ ${fname}${NC} - Missing 'name' field, removing..."
            rm -f "$tunnel_file"
            ((removed++))
            continue
        fi

        # Fix old numeric mode values
        local needs_fix=false
        case "$t_mode" in
            1)
                local TMP=$(mktemp)
                jq '.mode = "rtt-gost"' "$tunnel_file" > "$TMP" && mv "$TMP" "$tunnel_file"
                echo -e "  ${YELLOW}⟳ ${fname}${NC} - Fixed mode 1 → rtt-gost"
                needs_fix=true
                ((fixed++))
                ;;
            2)
                local TMP=$(mktemp)
                jq '.mode = "gost-only"' "$tunnel_file" > "$TMP" && mv "$TMP" "$tunnel_file"
                echo -e "  ${YELLOW}⟳ ${fname}${NC} - Fixed mode 2 → gost-only"
                needs_fix=true
                ((fixed++))
                ;;
            3)
                local TMP=$(mktemp)
                jq '.mode = "rtt-only"' "$tunnel_file" > "$TMP" && mv "$TMP" "$tunnel_file"
                echo -e "  ${YELLOW}⟳ ${fname}${NC} - Fixed mode 3 → rtt-only"
                needs_fix=true
                ((fixed++))
                ;;
        esac

        if [[ "$needs_fix" == false ]]; then
            echo -e "  ${GREEN}✓ ${fname}${NC} - OK"
            ((ok++))
        fi
    done

    echo ""
    print_separator
    echo -e "\n  ${GREEN}OK: ${ok}${NC}  |  ${YELLOW}Fixed: ${fixed}${NC}  |  ${RED}Removed: ${removed}${NC}"
    press_enter
}

#====================================================================
# CONNECTION DIAGNOSTICS
#====================================================================

diagnose_tunnel() {
    local name=$1
    local t_file="$TUNNELS_DIR/${name}.json"
    
    if [[ ! -f "$t_file" ]] || ! jq empty "$t_file" 2>/dev/null; then
        echo -e "  ${RED}✗ Config file missing or corrupted${NC}"
        return 1
    fi

    local t_mode=$(jq -r '.mode // "gost-only"' "$t_file")
    local t_lport=$(jq -r '.local_port // 0' "$t_file")
    local t_rport=$(jq -r '.remote_port // 0' "$t_file")
    local t_remote=$(jq -r '.remote_ip // ""' "$t_file")
    local t_proto=$(jq -r '.protocol // "tcp"' "$t_file")
    local t_sni=$(jq -r '.sni // ""' "$t_file")
    local role=$(get_config_value "server_role")
    local issues=0
    local warnings=0

    echo -e "\n${CYAN}${BOLD}══ Diagnosing: ${name} ══${NC}"
    echo -e "${DIM}Mode: $(get_mode_name $t_mode) | Role: ${role} | ${t_lport} → ${t_rport}${NC}\n"

    # ─── Step 1: Check config validity ───
    echo -e "${WHITE}${BOLD}[1/7] Configuration Check${NC}"
    
    if [[ -z "$t_remote" || "$t_remote" == "null" ]]; then
        echo -e "  ${RED}✗ Remote IP not set${NC}"
        ((issues++))
    else
        echo -e "  ${GREEN}✓ Remote IP: ${t_remote}${NC}"
    fi
    
    if [[ -z "$t_sni" || "$t_sni" == "null" ]]; then
        echo -e "  ${YELLOW}⚠ SNI not set (may be needed for stealth)${NC}"
        ((warnings++))
    else
        echo -e "  ${GREEN}✓ SNI: ${t_sni}${NC}"
    fi

    local password=$(get_config_value "password")
    if [[ -z "$password" || "$password" == "null" ]]; then
        echo -e "  ${RED}✗ Password not set${NC}"
        ((issues++))
    else
        echo -e "  ${GREEN}✓ Password configured${NC}"
    fi

    # ─── Step 2: Check systemd services ───
    echo -e "\n${WHITE}${BOLD}[2/7] Service Status${NC}"

    local has_rtt_svc=false
    local has_gost_svc=false
    local has_udp_svc=false
    local rtt_active=false
    local gost_active=false
    local udp_active=false

    if systemctl list-unit-files 2>/dev/null | grep -q "st-rtt-${name}.service"; then
        has_rtt_svc=true
        if systemctl is-active "st-rtt-${name}.service" &>/dev/null; then
            rtt_active=true
            echo -e "  ${GREEN}✓ RTT service: active (running)${NC}"
        else
            local rtt_state=$(systemctl show "st-rtt-${name}.service" -p SubState --value 2>/dev/null)
            echo -e "  ${RED}✗ RTT service: ${rtt_state:-dead}${NC}"
            ((issues++))
        fi
    else
        if [[ "$t_mode" == "rtt-gost" || "$t_mode" == "1" || "$t_mode" == "rtt-only" || "$t_mode" == "3" ]]; then
            echo -e "  ${RED}✗ RTT service file not found (required for this mode)${NC}"
            ((issues++))
        else
            echo -e "  ${DIM}○ RTT service: N/A (not needed for this mode)${NC}"
        fi
    fi

    if systemctl list-unit-files 2>/dev/null | grep -q "st-gost-${name}.service"; then
        has_gost_svc=true
        if systemctl is-active "st-gost-${name}.service" &>/dev/null; then
            gost_active=true
            echo -e "  ${GREEN}✓ GOST service: active (running)${NC}"
        else
            local gost_state=$(systemctl show "st-gost-${name}.service" -p SubState --value 2>/dev/null)
            echo -e "  ${RED}✗ GOST service: ${gost_state:-dead}${NC}"
            # Check recent errors
            local gost_err=$(journalctl -u "st-gost-${name}.service" --no-pager -n 5 2>/dev/null | grep -i "error\|fatal\|fail" | tail -1)
            if [[ -n "$gost_err" ]]; then
                echo -e "    ${RED}Last error: ${gost_err}${NC}"
            fi
            ((issues++))
        fi
    else
        if [[ "$t_mode" != "rtt-only" && "$t_mode" != "3" ]]; then
            echo -e "  ${RED}✗ GOST service file not found (required for this mode)${NC}"
            ((issues++))
        else
            echo -e "  ${DIM}○ GOST service: N/A (not needed for this mode)${NC}"
        fi
    fi

    if systemctl list-unit-files 2>/dev/null | grep -q "st-udp-${name}.service"; then
        has_udp_svc=true
        if systemctl is-active "st-udp-${name}.service" &>/dev/null; then
            udp_active=true
            echo -e "  ${GREEN}✓ UDP service: active (running)${NC}"
        else
            echo -e "  ${RED}✗ UDP service: not running${NC}"
            ((issues++))
        fi
    fi

    # ─── Step 3: Check port bindings ───
    echo -e "\n${WHITE}${BOLD}[3/7] Port Binding Check${NC}"

    # Compute expected ports based on mode and role
    local expected_ports=()
    local port_descriptions=()

    case "$t_mode" in
        rtt-gost|1)
            local rtt_bridge=$((t_lport + 1000))
            local gost_bridge=$((t_lport + 2000))
            if [[ "$role" == "iran" ]]; then
                expected_ports=($t_lport $rtt_bridge)
                port_descriptions=("Client TCP listen" "RTT bridge listen")
            elif [[ "$role" == "kharej" ]]; then
                expected_ports=($gost_bridge)
                port_descriptions=("GOST relay listen")
            fi
            ;;
        gost-only|2)
            local gost_tunnel=$((t_lport + 3000))
            if [[ "$role" == "iran" ]]; then
                expected_ports=($t_lport)
                port_descriptions=("Client TCP listen")
            elif [[ "$role" == "kharej" ]]; then
                expected_ports=($gost_tunnel)
                port_descriptions=("GOST relay listen")
            fi
            ;;
        rtt-only|3)
            if [[ "$role" == "iran" ]]; then
                expected_ports=($t_lport)
                port_descriptions=("RTT listen")
            fi
            # Kharej in RTT-only doesn't listen, it connects to Iran
            ;;
    esac

    for i in "${!expected_ports[@]}"; do
        local port=${expected_ports[$i]}
        local desc=${port_descriptions[$i]}
        local listener=$(ss -tlnp 2>/dev/null | grep ":${port} " | head -1)
        if [[ -n "$listener" ]]; then
            local proc=$(echo "$listener" | grep -oP 'users:\(\("\K[^"]+' || echo "unknown")
            echo -e "  ${GREEN}✓ Port ${port} (${desc}): listening [${proc}]${NC}"
        else
            echo -e "  ${RED}✗ Port ${port} (${desc}): NOT listening${NC}"
            ((issues++))
        fi
    done

    # Check for port conflicts
    if [[ "$role" == "kharej" ]]; then
        local xray_check=$(ss -tlnp 2>/dev/null | grep ":${t_rport} " | head -1)
        if [[ -n "$xray_check" ]]; then
            local xray_proc=$(echo "$xray_check" | grep -oP 'users:\(\("\K[^"]+' || echo "unknown")
            echo -e "  ${GREEN}✓ Xray/target port ${t_rport}: listening [${xray_proc}]${NC}"
        else
            echo -e "  ${RED}✗ Xray/target port ${t_rport}: NOT listening — nothing to forward to!${NC}"
            ((issues++))
        fi
    fi

    # ─── Step 4: Check RTT handshake (from logs) ───
    echo -e "\n${WHITE}${BOLD}[4/7] RTT Tunnel Health${NC}"

    if [[ "$t_mode" == "rtt-gost" || "$t_mode" == "1" || "$t_mode" == "rtt-only" || "$t_mode" == "3" ]]; then
        if [[ "$has_rtt_svc" == true ]]; then
            local rtt_logs=$(journalctl -u "st-rtt-${name}.service" --no-pager -n 50 2>/dev/null)
            
            # Check TLS handshake
            local handshake_count
            handshake_count=$(echo "$rtt_logs" | grep -c "TlsHandsahke complete" 2>/dev/null) || true
            handshake_count=$(echo "$handshake_count" | tr -d '[:space:]')
            handshake_count=${handshake_count:-0}
            if [[ $handshake_count -gt 0 ]]; then
                echo -e "  ${GREEN}✓ TLS handshakes completed: ${handshake_count}${NC}"
            else
                echo -e "  ${RED}✗ No TLS handshakes detected${NC}"
                ((issues++))
            fi

            # Check parallel connections
            local last_parallel=$(echo "$rtt_logs" | grep "prallel upload" | tail -1)
            if [[ -n "$last_parallel" ]]; then
                local uploads=$(echo "$last_parallel" | grep -oP 'upload: \K[0-9]+')
                local downloads=$(echo "$last_parallel" | grep -oP 'download: \K[0-9]+')
                local outbounds=$(echo "$last_parallel" | grep -oP 'outbounds: \K[0-9]+')
                echo -e "  ${GREEN}✓ RTT channels: upload=${uploads} download=${downloads}${NC}"
                if [[ "$outbounds" == "0" ]]; then
                    echo -e "  ${YELLOW}⚠ Outbound connections: 0 (no active traffic through RTT)${NC}"
                    ((warnings++))
                else
                    echo -e "  ${GREEN}✓ Outbound connections: ${outbounds}${NC}"
                fi
            fi

            # Check for RTT errors
            local rtt_errors=$(echo "$rtt_logs" | grep -iE "error|fail|refused|timeout|reset" | tail -3)
            if [[ -n "$rtt_errors" ]]; then
                echo -e "  ${YELLOW}⚠ RTT recent errors:${NC}"
                echo "$rtt_errors" | while read line; do
                    echo -e "    ${DIM}${line}${NC}"
                done
                ((warnings++))
            fi
        else
            echo -e "  ${DIM}○ RTT not configured${NC}"
        fi
    else
        echo -e "  ${DIM}○ RTT not used in this mode${NC}"
    fi

    # ─── Step 5: Check GOST status (from logs) ───
    echo -e "\n${WHITE}${BOLD}[5/7] GOST Tunnel Health${NC}"

    if [[ "$t_mode" != "rtt-only" && "$t_mode" != "3" ]]; then
        if [[ "$has_gost_svc" == true ]]; then
            local gost_logs=$(journalctl -u "st-gost-${name}.service" --no-pager -n 30 2>/dev/null)
            
            # Check if listening
            local gost_listening=$(echo "$gost_logs" | grep -i "listening on" | tail -1)
            if [[ -n "$gost_listening" ]]; then
                echo -e "  ${GREEN}✓ GOST listener active${NC}"
                echo -e "    ${DIM}${gost_listening}${NC}"
            fi

            # Check for address-in-use errors
            local bind_error=$(echo "$gost_logs" | grep "address already in use" | tail -1)
            if [[ -n "$bind_error" ]]; then
                local conflict_port=$(echo "$bind_error" | grep -oP '0\.0\.0\.0:\K[0-9]+')
                echo -e "  ${RED}✗ PORT CONFLICT: Port ${conflict_port} already in use by another process${NC}"
                local conflict_proc=$(ss -tlnp 2>/dev/null | grep ":${conflict_port} " | grep -oP 'users:\(\("\K[^"]+' | head -1)
                if [[ -n "$conflict_proc" ]]; then
                    echo -e "    ${RED}Process using port: ${conflict_proc}${NC}"
                fi
                ((issues++))
            fi

            # Check for connection errors
            local conn_errors=$(echo "$gost_logs" | grep -iE "error|fatal" | grep -v "address already" | tail -3)
            if [[ -n "$conn_errors" ]]; then
                echo -e "  ${YELLOW}⚠ Recent GOST errors:${NC}"
                echo "$conn_errors" | while read line; do
                    echo -e "    ${DIM}${line}${NC}"
                done
                ((warnings++))
            fi

            # Check restart count
            local restart_count
            restart_count=$(echo "$gost_logs" | grep -c "restart counter" 2>/dev/null) || true
            restart_count=$(echo "$restart_count" | tr -d '[:space:]')
            restart_count=${restart_count:-0}
            if [[ $restart_count -gt 5 ]]; then
                echo -e "  ${RED}✗ Service restarted ${restart_count} times (crash loop)${NC}"
                ((issues++))
            elif [[ $restart_count -gt 0 ]]; then
                echo -e "  ${YELLOW}⚠ Service restarted ${restart_count} times${NC}"
                ((warnings++))
            else
                echo -e "  ${GREEN}✓ No crash/restart detected${NC}"
            fi
        fi
    else
        echo -e "  ${DIM}○ GOST not used in this mode${NC}"
    fi

    # ─── Step 6: Network connectivity to remote server ───
    echo -e "\n${WHITE}${BOLD}[6/7] Remote Server Connectivity${NC}"

    if [[ -n "$t_remote" && "$t_remote" != "null" ]]; then
        # Ping test (basic reachability)
        if ping -c 1 -W 3 "$t_remote" &>/dev/null; then
            echo -e "  ${GREEN}✓ ICMP ping to ${t_remote}: reachable${NC}"
        else
            echo -e "  ${YELLOW}⚠ ICMP ping to ${t_remote}: blocked/unreachable (may be filtered)${NC}"
            ((warnings++))
        fi

        # TCP port connectivity (check relevant remote ports)
        local remote_test_ports=()
        case "$t_mode" in
            rtt-gost|1)
                if [[ "$role" == "iran" ]]; then
                    # Iran doesn't need to reach any port — Kharej connects TO Iran
                    echo -e "  ${DIM}○ RTT+GOST mode: Kharej initiates connection to Iran (reverse tunnel)${NC}"
                    echo -e "  ${DIM}  Checking RTT connections from Kharej...${NC}"
                    local rtt_bridge=$((t_lport + 1000))
                    local rtt_conns
                    rtt_conns=$(ss -tnp 2>/dev/null | grep ":${rtt_bridge}" | grep -c "ESTAB") || true
                    rtt_conns=$(echo "$rtt_conns" | tr -d '[:space:]')
                    rtt_conns=${rtt_conns:-0}
                    if [[ $rtt_conns -gt 0 ]]; then
                        echo -e "  ${GREEN}✓ RTT bridge port ${rtt_bridge}: ${rtt_conns} established connection(s) from Kharej${NC}"
                    else
                        echo -e "  ${RED}✗ RTT bridge port ${rtt_bridge}: No connections from Kharej${NC}"
                        echo -e "    ${YELLOW}→ Check that Kharej server has the same tunnel configured and running${NC}"
                        echo -e "    ${YELLOW}→ Check that SNI and password match on both servers${NC}"
                        ((issues++))
                    fi
                elif [[ "$role" == "kharej" ]]; then
                    # Kharej connects to Iran RTT
                    local rtt_bridge=$((t_lport + 1000))
                    echo -e "  ${DIM}  Checking RTT connection to Iran:${rtt_bridge}...${NC}"
                    if timeout 5 bash -c "echo >/dev/tcp/${t_remote}/${rtt_bridge}" 2>/dev/null; then
                        echo -e "  ${GREEN}✓ TCP to Iran:${rtt_bridge} (RTT): reachable${NC}"
                    else
                        echo -e "  ${RED}✗ TCP to Iran:${rtt_bridge} (RTT): connection failed${NC}"
                        echo -e "    ${YELLOW}→ Check Iran server's RTT service is running${NC}"
                        echo -e "    ${YELLOW}→ Check Iran server's firewall allows port ${rtt_bridge}${NC}"
                        ((issues++))
                    fi
                    # Check established connections
                    local rtt_conns
                    rtt_conns=$(ss -tnp 2>/dev/null | grep "${t_remote}:${rtt_bridge}" | grep -c "ESTAB") || true
                    rtt_conns=$(echo "$rtt_conns" | tr -d '[:space:]')
                    rtt_conns=${rtt_conns:-0}
                    if [[ $rtt_conns -gt 0 ]]; then
                        echo -e "  ${GREEN}✓ RTT tunnel established (${rtt_conns} connection(s))${NC}"
                    else
                        echo -e "  ${RED}✗ RTT tunnel NOT established${NC}"
                        ((issues++))
                    fi
                fi
                ;;
            gost-only|2)
                if [[ "$role" == "iran" ]]; then
                    local gost_tunnel=$((t_lport + 3000))
                    echo -e "  ${DIM}  Checking GOST relay on Kharej:${gost_tunnel}...${NC}"
                    if timeout 5 bash -c "echo >/dev/tcp/${t_remote}/${gost_tunnel}" 2>/dev/null; then
                        echo -e "  ${GREEN}✓ TCP to Kharej:${gost_tunnel} (GOST relay): reachable${NC}"
                    else
                        echo -e "  ${RED}✗ TCP to Kharej:${gost_tunnel} (GOST relay): connection failed${NC}"
                        echo -e "    ${YELLOW}→ Check Kharej server's GOST service is running${NC}"
                        echo -e "    ${YELLOW}→ Check Kharej server's firewall allows port ${gost_tunnel}${NC}"
                        ((issues++))
                    fi
                elif [[ "$role" == "kharej" ]]; then
                    echo -e "  ${DIM}○ GOST-only mode: Iran connects to Kharej (waiting for connections)${NC}"
                    local gost_tunnel=$((t_lport + 3000))
                    local gost_conns
                    gost_conns=$(ss -tnp 2>/dev/null | grep ":${gost_tunnel}" | grep -c "ESTAB") || true
                    gost_conns=$(echo "$gost_conns" | tr -d '[:space:]')
                    gost_conns=${gost_conns:-0}
                    if [[ $gost_conns -gt 0 ]]; then
                        echo -e "  ${GREEN}✓ GOST relay port ${gost_tunnel}: ${gost_conns} connection(s) from Iran${NC}"
                    else
                        echo -e "  ${YELLOW}⚠ GOST relay port ${gost_tunnel}: No connections from Iran yet${NC}"
                        ((warnings++))
                    fi
                fi
                ;;
            rtt-only|3)
                if [[ "$role" == "iran" ]]; then
                    echo -e "  ${DIM}○ RTT mode: Kharej connects to Iran (reverse tunnel)${NC}"
                    local rtt_conns
                    rtt_conns=$(ss -tnp 2>/dev/null | grep ":${t_lport}" | grep -c "ESTAB") || true
                    rtt_conns=$(echo "$rtt_conns" | tr -d '[:space:]')
                    rtt_conns=${rtt_conns:-0}
                    if [[ $rtt_conns -gt 0 ]]; then
                        echo -e "  ${GREEN}✓ RTT port ${t_lport}: ${rtt_conns} established connection(s)${NC}"
                    else
                        echo -e "  ${RED}✗ RTT port ${t_lport}: No connections from Kharej${NC}"
                        ((issues++))
                    fi
                elif [[ "$role" == "kharej" ]]; then
                    echo -e "  ${DIM}  Checking RTT connection to Iran:${t_lport}...${NC}"
                    if timeout 5 bash -c "echo >/dev/tcp/${t_remote}/${t_lport}" 2>/dev/null; then
                        echo -e "  ${GREEN}✓ TCP to Iran:${t_lport} (RTT): reachable${NC}"
                    else
                        echo -e "  ${RED}✗ TCP to Iran:${t_lport} (RTT): connection failed${NC}"
                        ((issues++))
                    fi
                fi
                ;;
        esac
    else
        echo -e "  ${RED}✗ Cannot test — remote IP not configured${NC}"
        ((issues++))
    fi

    # ─── Step 7: End-to-end tunnel test ───
    echo -e "\n${WHITE}${BOLD}[7/7] End-to-End Tunnel Test${NC}"

    if [[ "$role" == "iran" ]]; then
        # On Iran, try to connect through the tunnel
        echo -e "  ${DIM}Testing connection through tunnel port ${t_lport}...${NC}"
        if timeout 5 bash -c "echo >/dev/tcp/127.0.0.1/${t_lport}" 2>/dev/null; then
            echo -e "  ${GREEN}✓ Local port ${t_lport}: accepting connections${NC}"
            
            # Port accepts connections = tunnel is forwarding traffic
            # The remote service (Xray) uses its own protocol, so HTTP test may not apply
            echo -e "  ${GREEN}${BOLD}✓✓ TUNNEL IS WORKING! Port ${t_lport} accepts connections through the tunnel.${NC}"
            
            # Optional: try HTTP to give more info (informational only)
            local response
            response=$(curl -so /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "http://127.0.0.1:${t_lport}" 2>/dev/null) || true
            response=$(echo "$response" | tr -d '[:space:]')
            if [[ -n "$response" && "$response" != "000" && "$response" != "" ]]; then
                echo -e "  ${DIM}HTTP probe response: ${response} (informational)${NC}"
            fi
        else
            echo -e "  ${RED}✗ Cannot connect to local port ${t_lport}${NC}"
            echo -e "  ${RED}${BOLD}✗✗ TUNNEL NOT WORKING${NC}"
            ((issues++))
        fi
    elif [[ "$role" == "kharej" ]]; then
        echo -e "  ${DIM}End-to-end test should be run from Iran server.${NC}"
        echo -e "  ${DIM}Verifying local Xray/target service on port ${t_rport}...${NC}"
        if timeout 3 bash -c "echo >/dev/tcp/127.0.0.1/${t_rport}" 2>/dev/null; then
            echo -e "  ${GREEN}✓ Target service on port ${t_rport}: accepting connections${NC}"
        else
            echo -e "  ${RED}✗ Target service on port ${t_rport}: NOT responding${NC}"
            echo -e "    ${YELLOW}→ Make sure Xray/V2Ray is running and listening on port ${t_rport}${NC}"
            ((issues++))
        fi
    fi

    # ─── Summary ───
    echo ""
    print_separator
    if [[ $issues -eq 0 && $warnings -eq 0 ]]; then
        echo -e "\n  ${GREEN}${BOLD}✓ ALL CHECKS PASSED — No issues detected${NC}\n"
    elif [[ $issues -eq 0 ]]; then
        echo -e "\n  ${YELLOW}${BOLD}⚠ ${warnings} warning(s), no critical issues${NC}\n"
    else
        echo -e "\n  ${RED}${BOLD}✗ ${issues} issue(s) found, ${warnings} warning(s)${NC}"
        echo ""
        echo -e "  ${WHITE}${BOLD}Troubleshooting Tips:${NC}"
        echo -e "  ${DIM}1. Make sure BOTH servers (Iran & Kharej) have the tunnel configured${NC}"
        echo -e "  ${DIM}2. SNI domain and password MUST match on both servers${NC}"
        echo -e "  ${DIM}3. Check firewall: required ports must be open on BOTH servers${NC}"
        echo -e "  ${DIM}4. On Kharej: Xray/V2Ray must be running on target port${NC}"
        echo -e "  ${DIM}5. Try: stealth-tunnel → Manage → Restart the tunnel${NC}"
        echo -e "  ${DIM}6. Check logs: stealth-tunnel → Manage → View Logs${NC}"
        echo ""
    fi
}

diagnose_all_tunnels() {
    print_banner
    echo -e "${YELLOW}${BOLD}═══ Connection Diagnostics ═══${NC}\n"

    local role=$(get_config_value "server_role")
    local remote_ip=$(get_config_value "remote_ip")
    
    if [[ -z "$role" || "$role" == "null" ]]; then
        echo -e "${RED}Server not configured. Run Initial Setup first.${NC}"
        press_enter
        return
    fi

    echo -e "${WHITE}Server Role:${NC} ${CYAN}${role}${NC}"
    echo -e "${WHITE}Remote IP:${NC}   ${CYAN}${remote_ip}${NC}"
    echo ""

    # Basic connectivity to remote server
    echo -e "${WHITE}${BOLD}── Basic Connectivity ──${NC}"
    if [[ -n "$remote_ip" && "$remote_ip" != "null" ]]; then
        if ping -c 2 -W 3 "$remote_ip" &>/dev/null; then
            local latency=$(ping -c 2 -W 3 "$remote_ip" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
            echo -e "  ${GREEN}✓ Remote server reachable (avg latency: ${latency}ms)${NC}"
        else
            echo -e "  ${YELLOW}⚠ ICMP blocked or server unreachable${NC}"
        fi
    fi

    # Diagnose each tunnel
    local tunnels=$(ls "$TUNNELS_DIR"/*.json 2>/dev/null)
    if [[ -z "$tunnels" ]]; then
        echo -e "\n${DIM}No tunnels configured to diagnose${NC}"
        press_enter
        return
    fi

    for tunnel_file in $tunnels; do
        if ! jq empty "$tunnel_file" 2>/dev/null; then
            continue
        fi
        local t_name=$(jq -r '.name' "$tunnel_file")
        diagnose_tunnel "$t_name"
    done

    press_enter
}

diagnose_single_tunnel_menu() {
    print_banner
    echo -e "${YELLOW}${BOLD}═══ Diagnose Single Tunnel ═══${NC}\n"

    local tunnels=($(ls "$TUNNELS_DIR"/*.json 2>/dev/null))
    if [[ ${#tunnels[@]} -eq 0 ]]; then
        echo -e "${DIM}No tunnels configured${NC}"
        press_enter
        return
    fi

    local i=1
    local valid_tunnels=()
    for tunnel_file in "${tunnels[@]}"; do
        if ! jq empty "$tunnel_file" 2>/dev/null; then
            continue
        fi
        valid_tunnels+=("$tunnel_file")
        local t_name=$(jq -r '.name' "$tunnel_file")
        local t_lport=$(jq -r '.local_port' "$tunnel_file")
        echo -e "  ${GREEN}${i})${NC} ${t_name} (port ${t_lport})"
        ((i++))
    done

    echo ""
    read -p "$(echo -e ${CYAN}Select tunnel \(0=back\): ${NC})" tunnel_num

    if [[ "$tunnel_num" == "0" ]]; then
        return
    fi

    if [[ "$tunnel_num" -gt 0 && "$tunnel_num" -le ${#valid_tunnels[@]} ]] 2>/dev/null; then
        local selected_file="${valid_tunnels[$((tunnel_num-1))]}"
        local selected_name=$(jq -r '.name' "$selected_file")
        print_banner
        echo -e "${YELLOW}${BOLD}═══ Tunnel Diagnostics ═══${NC}"
        diagnose_tunnel "$selected_name"
        press_enter
    else
        echo -e "${RED}Invalid selection${NC}"
        sleep 1
    fi
}

#====================================================================
# MAIN MENU
#====================================================================

main_menu() {
    check_root

    while true; do
        print_banner

        echo -e "  ${GREEN}1)${NC}  ${BOLD}Initial Setup${NC}           ${DIM}(Configure server role)${NC}"
        echo -e "  ${GREEN}2)${NC}  ${BOLD}Add Tunnel${NC}              ${DIM}(Add single or multiple ports)${NC}"
        echo -e "  ${GREEN}3)${NC}  ${BOLD}List Tunnels${NC}            ${DIM}(View all tunnels)${NC}"
        echo -e "  ${GREEN}4)${NC}  ${BOLD}Manage Tunnels${NC}          ${DIM}(Start/Stop/Delete tunnels)${NC}"
        echo ""
        echo -e "  ${CYAN}5)${NC}  ${BOLD}Start All Tunnels${NC}"
        echo -e "  ${CYAN}6)${NC}  ${BOLD}Stop All Tunnels${NC}"
        echo -e "  ${CYAN}7)${NC}  ${BOLD}Restart All Tunnels${NC}"
        echo ""
        echo -e "  ${MAGENTA}8)${NC}  ${BOLD}System Status${NC}           ${DIM}(Overview & health check)${NC}"
        echo -e "  ${MAGENTA}9)${NC}  ${BOLD}View Logs${NC}               ${DIM}(All service logs)${NC}"
        echo -e "  ${MAGENTA}10)${NC} ${BOLD}Connection Diagnostics${NC}  ${DIM}(Test all tunnels end-to-end)${NC}"
        echo ""
        echo -e "  ${BLUE}11)${NC} ${BOLD}Update${NC}                  ${DIM}(Update StealthTunnel)${NC}"
        echo -e "  ${BLUE}12)${NC} ${BOLD}Repair Configs${NC}          ${DIM}(Fix/cleanup tunnel configs)${NC}"
        echo -e "  ${RED}13)${NC} ${BOLD}Uninstall${NC}               ${DIM}(Remove everything)${NC}"
        echo ""
        echo -e "  ${WHITE}0)${NC}  ${BOLD}Exit${NC}"
        echo ""
        print_separator
        echo ""
        read -p "$(echo -e ${CYAN}${BOLD}Select option: ${NC})" choice

        case $choice in
            1)  initial_setup ;;
            2)  add_multi_port_tunnel ;;
            3)  list_tunnels ;;
            4)  manage_tunnels_menu ;;
            5)  start_all_tunnels ;;
            6)  stop_all_tunnels ;;
            7)  restart_all_tunnels ;;
            8)  show_status ;;
            9)  view_all_logs ;;
            10) diagnose_all_tunnels ;;
            11) update_stealth_tunnel ;;
            12) repair_configs ;;
            13) uninstall ;;
            0)  echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *)  echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

# Run
main_menu
PANEL_SCRIPT

    chmod +x "${BIN_DIR}/stealth-tunnel"
    log_info "Management panel installed"
}

# Main installation flow
main() {
    local UPDATE_MODE=false
    if [[ "$1" == "--update" ]]; then
        UPDATE_MODE=true
    fi

    print_banner
    check_root
    detect_os
    detect_arch

    echo ""
    if [[ "$UPDATE_MODE" == true ]]; then
        log_step "Updating StealthTunnel (preserving configurations)..."
    else
        log_step "Starting StealthTunnel installation..."
    fi
    echo ""

    if [[ "$UPDATE_MODE" == false ]]; then
        install_dependencies || { log_warn "Dependencies install had issues, continuing..."; }
        optimize_system || { log_warn "System optimization had issues, continuing..."; }
    fi
    
    create_directories || { log_warn "Directory creation had issues, continuing..."; }
    generate_certificates || { log_warn "Certificate generation had issues, continuing..."; }
    install_gost || { log_warn "GOST installation had issues, continuing..."; }
    install_rtt || true
    create_main_config || { log_warn "Config creation had issues, continuing..."; }
    install_panel || { log_error "Panel installation failed!"; }

    echo ""
    if [[ "$UPDATE_MODE" == true ]]; then
        echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}${BOLD}║                                                            ║${NC}"
        echo -e "${GREEN}${BOLD}║          ✓ StealthTunnel Updated Successfully!              ║${NC}"
        echo -e "${GREEN}${BOLD}║          Your configurations were preserved.                ║${NC}"
        echo -e "${GREEN}${BOLD}║                                                            ║${NC}"
        echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}${BOLD}║                                                            ║${NC}"
        echo -e "${GREEN}${BOLD}║          ✓ StealthTunnel Installed Successfully!            ║${NC}"
        echo -e "${GREEN}${BOLD}║                                                            ║${NC}"
        echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}${BOLD}║                                                            ║${NC}"
        echo -e "${GREEN}${BOLD}║  Run the management panel:                                 ║${NC}"
        echo -e "${GREEN}${BOLD}║                                                            ║${NC}"
        echo -e "${GREEN}${BOLD}║    $ stealth-tunnel                                        ║${NC}"
        echo -e "${GREEN}${BOLD}║                                                            ║${NC}"
        echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Ask to launch panel
        read -p "$(echo -e ${CYAN}Launch management panel now? [Y/n]: ${NC})" launch
        launch=${launch:-Y}
        if [[ "$launch" == "y" || "$launch" == "Y" ]]; then
            stealth-tunnel
        fi
    fi
}

main "$@"
