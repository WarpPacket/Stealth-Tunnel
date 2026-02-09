<div align="center">

<img src="https://img.shields.io/badge/StealthTunnel-v1.0.0-blue?style=for-the-badge&logo=wireguard&logoColor=white" alt="version"/>

# StealthTunnel

### Multi-Layer Stealth Tunnel Manager

**[RTT](https://github.com/radkesvat/ReverseTlsTunnel) + [GOST](https://github.com/go-gost/gost) Combined with Interactive Management Panel**

<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![OS](https://img.shields.io/badge/OS-Ubuntu%20|%20Debian-E95420?style=flat-square&logo=ubuntu&logoColor=white)]()
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)]()
[![GOST](https://img.shields.io/badge/GOST-v3.2.6-00ADD8?style=flat-square&logo=go&logoColor=white)]()
[![RTT](https://img.shields.io/badge/RTT-v7.1-purple?style=flat-square)]()

<br/>

**[🇮🇷 فارسی](README.fa.md)**

[Quick Install](#-quick-install) &nbsp;&bull;&nbsp;
[Guide](#-step-by-step-guide) &nbsp;&bull;&nbsp;
[Tunnel Modes](#-tunnel-modes) &nbsp;&bull;&nbsp;
[Troubleshooting](#-troubleshooting)

</div>

<br/>

---

## 📋 Table of Contents

- [Introduction](#-introduction)
- [Key Features](#-key-features)
- [Architecture](#-architecture)
- [Quick Install](#-quick-install)
- [Step-by-Step Guide](#-step-by-step-guide)
- [Tunnel Modes](#-tunnel-modes)
- [Examples](#-examples)
- [Troubleshooting](#-troubleshooting)
- [File Structure](#-file-structure)
- [Security](#-security)
- [Panel Menu](#-panel-menu)

---

## 🔍 Introduction

**StealthTunnel** is an advanced multi-layer tunneling system that combines **RTT (Reverse TLS Tunnel)** and **GOST (GO Simple Tunnel)** to create a fully stealth, undetectable tunnel that looks like regular HTTPS traffic.

### Why RTT + GOST?

Each tool has its own strengths. Combining them creates an extremely robust stealth layer:

<div align="center">

| Feature | RTT | GOST | RTT + GOST |
|:---:|:---:|:---:|:---:|
| TLS Handshake + Fake SNI | ✅ | ❌ | ✅ |
| WebSocket Obfuscation | ❌ | ✅ | ✅ |
| Multiplexing | ✅ | ✅ | ✅ |
| Multi-Port Forwarding | ❌ | ✅ | ✅ |
| Reverse Tunnel | ✅ | ✅ | ✅ |
| Real HTTPS Simulation | ⭐ | ⭐ | ⭐⭐⭐ |

</div>

---

## ✨ Key Features

| | Feature | Description |
|:---:|:---|:---|
| 🔒 | **Multi-Layer Encryption** | TLS 1.3 + WebSocket + Multiplexing |
| 🎭 | **SNI Camouflage** | Traffic looks like visiting legitimate websites |
| 🔄 | **Multi-Port Forwarding** | Forward multiple ports simultaneously |
| 📊 | **Interactive Panel** | Full management via terminal menu |
| 🚀 | **One-Line Install** | Automatic setup with a single command |
| ⚡ | **Auto Optimization** | BBR + TCP tuning enabled automatically |
| 🔧 | **systemd Integration** | Services with auto-restart |
| 🩺 | **Built-in Diagnostics** | End-to-End connection testing tool |

---

## 🏗 Architecture

In **RTT + GOST** mode (maximum stealth), traffic passes through multiple layers:

```
  ┌─────────────────────┐                    ┌─────────────────────┐
  │    IRAN SERVER       │                    │   KHAREJ SERVER     │
  │    (Entry Point)     │                    │    (Exit Point)     │
  ├─────────────────────┤                    ├─────────────────────┤
  │                     │                    │                     │
  │  Client --> GOST    │    RTT Tunnel      │    GOST --> Xray    │
  │  :2086     (relay)  │<==================>│   (relay)    :2086  │
  │                     │  TLS + SNI Fake    │                     │
  │  Client --> GOST    │  + WebSocket       │    GOST --> Xray    │
  │  :443      (relay)  │  + Multiplexing    │   (relay)    :443   │
  │                     │                    │                     │
  └─────────────────────┘                    └─────────────────────┘

  Traffic Flow:
  Client --> Iran:Port --> [GOST Relay] --> [RTT Reverse TLS]
         --> Internet (looks like HTTPS to google.com)
         --> [RTT on Kharej] --> [GOST Relay] --> Xray/V2Ray
```

> **Note:** In this architecture, the **Kharej** server connects **to** the **Iran** server (Reverse Connection). This means even if the Iran server's IP changes, the connection persists.

---

## 🚀 Quick Install

Run this command on **both servers** (Iran and Kharej):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/WarpPacket/Stealth-Tunnel/main/install.sh)
```

### Prerequisites

| Requirement | Minimum |
|:---:|:---:|
| OS | Ubuntu 18.04+ / Debian 10+ |
| Access | root |
| RAM | 512 MB |
| Internet | Active (for downloading binaries) |

### What does the installer do?

- ✅ Download and install GOST v3.2.6
- ✅ Download and install RTT v7.1
- ✅ Generate self-signed TLS certificates
- ✅ Optimize TCP and enable BBR
- ✅ Install management panel (`stealth-tunnel`)
- ✅ Create directory structure

---

## 📖 Step-by-Step Guide

### Step 1 — Setup Iran Server

```bash
stealth-tunnel
# Select: 1) Initial Setup
# Select: 1) IRAN Server
```

| Setting | Description | Example |
|:---|:---|:---|
| **Iran Server IP** | Auto-detected | `1.2.3.4` |
| **Kharej Server IP** | Remote server IP | `5.6.7.8` |
| **SNI Domain** | Fake domain for TLS | `www.google.com` |
| **Password** | Shared tunnel password | `mySecurePass123` |

> ⚠️ **Important:** Write down the password and SNI. You must enter the exact same values on the Kharej server.

### Step 2 — Setup Kharej Server

```bash
stealth-tunnel
# Select: 1) Initial Setup
# Select: 2) KHAREJ Server
```

| Setting | Description |
|:---|:---|
| **Kharej Server IP** | Auto-detected |
| **Iran Server IP** | Iran server IP |
| **SNI Domain** | **Must match Iran server** |
| **Password** | **Must match Iran server** |

### Step 3 — Create Tunnel (on both servers)

```bash
stealth-tunnel
# Select: 2) Add Tunnel
```

The wizard will ask:
1. **Tunnel mode** — RTT+GOST (recommended) / GOST Only / RTT Only
2. **Group name** — e.g. `xray`
3. **Ports** — format `local:remote` e.g. `2086:2086`
4. **Protocol** — TCP or UDP

> 💡 You can add multiple ports at once. Enter each port mapping, then press Enter on an empty line to finish.

### Step 4 — Verify Connection

```bash
stealth-tunnel
# Select: 10) Connection Diagnostics
```

The 7-step diagnostic tool will check the full tunnel health.

---

## 🔧 Tunnel Modes

### ⭐ Mode 1: RTT + GOST — Maximum Stealth (Recommended)

```
Client --> Iran:Port --> GOST (Relay) --> RTT (Reverse TLS + SNI)
       --> Kharej:RTT --> GOST (Relay) --> Xray/V2Ray
```

| Advantage | Description |
|:---|:---|
| 🔐 Dual encryption | TLS by RTT + Relay by GOST |
| 🎭 Fake SNI | Traffic looks like visiting `www.google.com` |
| 📦 Multiplexing | Reduces real connection count |
| 🔄 Reverse Connection | Kharej connects to Iran |

### Mode 2: GOST Only — Simple & Fast

```
Client --> Iran:Port --> GOST (WSS + Relay + Mux + TLS) --> Kharej --> Xray
```

| Advantage | Description |
|:---|:---|
| ⚡ Faster | One less layer |
| 🔧 Simpler | No RTT needed |
| 🌐 WebSocket + TLS | Good obfuscation |

### Mode 3: RTT Only — Minimal Overhead

```
Client --> Iran:Port --> RTT (Reverse TLS + SNI Fake) --> Kharej --> Xray
```

| Advantage | Description |
|:---|:---|
| 🚀 Least overhead | Most direct path |
| 🎭 SNI Camouflage | TLS stealth |
| 🔄 Reverse Connection | Reverse tunnel |

---

## 💡 Examples

### Example 1: Forward Xray Port (Single Port)

**Run on both servers:**

```bash
stealth-tunnel
# 2) Add Tunnel
#    Mode: RTT+GOST
#    Name: xray
#    Port: 2086:2086
#    Protocol: TCP
```

### Example 2: Forward Multiple Ports

**Run on both servers:**

```bash
stealth-tunnel
# 2) Add Tunnel
#    Mode: RTT+GOST
#    Name: multi
#    Ports:
#      443:443
#      2053:2053
#      2083:2083
#      8443:8443
#      (empty Enter to finish)
#    Protocol: TCP
```

### Example 3: UDP Tunnel for VLESS Reality

```bash
stealth-tunnel
# 2) Add Tunnel
#    Mode: GOST Only
#    Name: reality
#    Port: 443:443
#    Protocol: UDP
```

---

## 🔍 Troubleshooting

### Built-in Diagnostic Tool

The best way to troubleshoot is using the built-in tool:

```bash
stealth-tunnel
# 10) Connection Diagnostics
```

This tool checks 7 stages:

| Step | Check |
|:---|:---|
| [1/7] | Configuration Check |
| [2/7] | Service Status |
| [3/7] | Port Binding Check |
| [4/7] | RTT Tunnel Health |
| [5/7] | GOST Tunnel Health |
| [6/7] | Remote Server Connectivity |
| [7/7] | End-to-End Tunnel Test |

### Manual Commands

```bash
# Service status
systemctl status st-rtt-TUNNEL_NAME.service
systemctl status st-gost-TUNNEL_NAME.service

# Live logs
journalctl -u st-rtt-TUNNEL_NAME -f --no-pager
journalctl -u st-gost-TUNNEL_NAME -f --no-pager

# Check ports
ss -tlnp | grep -E "gost|RTT"

# Test connection
curl -v telnet://localhost:PORT
```

### Common Issues

| Issue | Cause | Solution |
|:---|:---|:---|
| `TLS handshake failed` | SNI or password mismatch | Ensure SNI and password match on both servers |
| `connection refused` | Service not running on remote | Restart services on both servers |
| `No peer connected` | Kharej not connected to Iran | Create and start tunnel on Kharej server too |
| Port not listening | Port occupied by another process | Check with `ss -tlnp \| grep PORT` |
| High CPU | Too many connections | Reduce `connection-age` value |
| SNI not working | Domain blocked | Try `www.google.com` or `splus.ir` |

---

## 📁 File Structure

```
/opt/stealth-tunnel/
└── certs/
    ├── cert.pem                  # TLS certificate
    └── key.pem                   # TLS private key

/etc/stealth-tunnel/
├── config.json                   # Main config (role, IP, SNI, password)
└── tunnels/
    ├── xray.json                 # Per-tunnel config
    └── multi-p1.json

/var/log/stealth-tunnel/          # Logs

/usr/local/bin/
├── stealth-tunnel                # Management panel
├── gost                          # GOST v3.2.6 binary
└── RTT                           # RTT v7.1 binary

/etc/systemd/system/
├── st-rtt-{name}.service         # RTT service per tunnel
├── st-gost-{name}.service        # GOST service per tunnel
└── st-{name}.service             # Combined wrapper service
```

---

## 🔐 Security

| | Feature | Description |
|:---:|:---|:---|
| 🔒 | **TLS 1.3** | All traffic encrypted with TLS 1.3 |
| 🎭 | **SNI Camouflage** | Traffic appears as visits to legitimate websites |
| 🌐 | **WebSocket** | Additional layer to bypass DPI |
| 📦 | **Multiplexing** | Reduces real connections to minimize fingerprint |
| 🔄 | **Reverse Connection** | Kharej connects to Iran, not the other way |
| 📜 | **Self-signed Certs** | TLS certificates with legitimate website CNs |

---

## 🗺 Panel Menu

```
 1)  Initial Setup             Configure server role
 2)  Add Tunnel                Create tunnel (single or multi-port)
 3)  List Tunnels              View all tunnels
 4)  Manage Tunnels            Start/Stop/Delete tunnels
 5)  Start All Tunnels
 6)  Stop All Tunnels
 7)  Restart All Tunnels
 8)  System Status             Overview & health check
 9)  View Logs                 All service logs
10)  Connection Diagnostics    Test all tunnels end-to-end
11)  Update                    Update StealthTunnel
12)  Repair Configs            Fix/cleanup tunnel configs
13)  Uninstall                 Remove everything
 0)  Exit
```

---

## 📝 License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

---

## ⚠️ Disclaimer

> This tool is provided solely for **educational and research purposes**.
> Users are responsible for complying with their local laws and regulations.
> The developers assume no liability for misuse of this tool.

---

<div align="center">

Made with ❤️ by [WarpPacket](https://github.com/WarpPacket)

</div>
