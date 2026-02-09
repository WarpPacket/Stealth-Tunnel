<div align="center">

<img src="https://img.shields.io/badge/StealthTunnel-v1.0.0-blue?style=for-the-badge&logo=wireguard&logoColor=white" alt="version"/>

# StealthTunnel

### مدیریت تانل چند لایه‌ای مخفی

**ترکیب [RTT](https://github.com/radkesvat/ReverseTlsTunnel) + [GOST](https://github.com/go-gost/gost) با پنل مدیریتی تعاملی**

<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![OS](https://img.shields.io/badge/OS-Ubuntu%20|%20Debian-E95420?style=flat-square&logo=ubuntu&logoColor=white)]()
[![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)]()
[![GOST](https://img.shields.io/badge/GOST-v3.2.6-00ADD8?style=flat-square&logo=go&logoColor=white)]()
[![RTT](https://img.shields.io/badge/RTT-v7.1-purple?style=flat-square)]()

<br/>

**[🇬🇧 English](README.md)**

</div>

<br/>

---

## فهرست مطالب

- [معرفی](#معرفی)
- [ویژگی‌ها](#ویژگیها)
- [معماری](#معماری)
- [نصب سریع](#نصب-سریع)
- [راهنمای استفاده](#راهنمای-استفاده)
- [حالت‌های تانل](#حالتهای-تانل)
- [نمونه‌ها](#نمونهها)
- [عیب‌یابی](#عیبیابی)
- [ساختار فایل‌ها](#ساختار-فایلها)
- [امنیت](#امنیت)
- [منوی پنل](#منوی-پنل)

---

## معرفی

**StealthTunnel** یک سیستم تانلینگ پیشرفته و چند لایه‌ای است که با ترکیب دو تکنولوژی **RTT** و **GOST** یک تانل کاملاً مخفی و غیرقابل تشخیص از ترافیک عادی HTTPS ایجاد می‌کند.

### چرا RTT + GOST؟

هر کدام از این ابزارها به تنهایی قابلیت‌های خوبی دارند، اما ترکیب آن‌ها یک لایه امنیتی فوق‌العاده ایجاد می‌کند:

<div align="center">

| قابلیت | RTT | GOST | RTT + GOST |
|:---:|:---:|:---:|:---:|
| TLS Handshake + Fake SNI | ✅ | ❌ | ✅ |
| WebSocket Obfuscation | ❌ | ✅ | ✅ |
| Multiplexing | ✅ | ✅ | ✅ |
| Multi-Port Forwarding | ❌ | ✅ | ✅ |
| Reverse Tunnel | ✅ | ✅ | ✅ |
| HTTPS Simulation | ⭐ | ⭐ | ⭐⭐⭐ |

</div>

---

## ویژگی‌ها

| | قابلیت | توضیح |
|:---:|:---|:---|
| 🔒 | **رمزنگاری چند لایه** | TLS 1.3 + WebSocket + Multiplexing |
| 🎭 | **استتار SNI** | ترافیک شبیه بازدید از سایت‌های معتبر |
| 🔄 | **انتقال چند پورت** | فوروارد همزمان چندین پورت |
| 📊 | **پنل تعاملی** | مدیریت کامل از طریق منوی ترمینال |
| 🚀 | **نصب یک‌خطی** | نصب خودکار با یک دستور |
| ⚡ | **بهینه‌سازی خودکار** | BBR + TCP tuning |
| 🔧 | **systemd** | سرویس‌ها با ری‌استارت خودکار |
| 🩺 | **عیب‌یابی داخلی** | تست اتصال End-to-End |

---

## معماری

در حالت **RTT + GOST** (حداکثر مخفی‌سازی) ترافیک از چندین لایه عبور می‌کند:

```
  +---------------------+                    +---------------------+
  |    IRAN SERVER       |                    |   KHAREJ SERVER     |
  |    (Entry Point)     |                    |    (Exit Point)     |
  +---------------------+                    +---------------------+
  |                     |                    |                     |
  |  Client --> GOST    |    RTT Tunnel      |    GOST --> Xray    |
  |  :2086     (relay)  |<==================>|   (relay)    :2086  |
  |                     |  TLS + SNI Fake    |                     |
  |  Client --> GOST    |  + WebSocket       |    GOST --> Xray    |
  |  :443      (relay)  |  + Multiplexing    |   (relay)    :443   |
  |                     |                    |                     |
  +---------------------+                    +---------------------+

  Traffic Flow:
  Client --> Iran:Port --> [GOST Relay] --> [RTT Reverse TLS]
         --> Internet (looks like HTTPS to google.com)
         --> [RTT on Kharej] --> [GOST Relay] --> Xray/V2Ray
```

> **نکته مهم:** در این معماری سرور **خارج** به سرور **ایران** وصل می‌شود (Reverse Connection). یعنی حتی اگر IP سرور ایران تغییر کند، اتصال برقرار می‌ماند.

---

## نصب سریع

روی **هر دو سرور** (ایران و خارج) این دستور را اجرا کنید:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/WarpPacket/Stealth-Tunnel/main/install.sh)
```

### پیش‌نیازها

| مورد | حداقل نیاز |
|:---:|:---:|
| OS | Ubuntu 18.04+ / Debian 10+ |
| Access | root |
| RAM | 512 MB |
| Internet | Active |

### نصب‌کننده چه کارهایی انجام می‌دهد؟

- ✅ GOST v3.2.6
- ✅ RTT v7.1
- ✅ TLS Certificates (self-signed)
- ✅ TCP Optimization + BBR
- ✅ Management Panel (`stealth-tunnel`)
- ✅ Directory Structure

---

## راهنمای استفاده

### مرحله ۱ — تنظیم سرور ایران

```bash
stealth-tunnel
# Select: 1) Initial Setup
# Select: 1) IRAN Server
```

| Setting | Example |
|:---|:---|
| **Iran Server IP** | `1.2.3.4` (auto-detected) |
| **Kharej Server IP** | `5.6.7.8` |
| **SNI Domain** | `www.google.com` |
| **Password** | `mySecurePass123` |

> ⚠️ **مهم:** پسورد و SNI را یادداشت کنید. باید روی سرور خارج هم دقیقاً همین مقادیر را وارد کنید.

### مرحله ۲ — تنظیم سرور خارج

```bash
stealth-tunnel
# Select: 1) Initial Setup
# Select: 2) KHAREJ Server
```

| Setting | Value |
|:---|:---|
| **Kharej Server IP** | auto-detected |
| **Iran Server IP** | Iran server IP |
| **SNI Domain** | **Must match Iran** |
| **Password** | **Must match Iran** |

### مرحله ۳ — ایجاد تانل (روی هر دو سرور)

```bash
stealth-tunnel
# Select: 2) Add Tunnel
```

ویزارد از شما می‌پرسد:

1. **Tunnel mode** — RTT+GOST / GOST Only / RTT Only
2. **Group name** — e.g. `xray`
3. **Ports** — format `local:remote` e.g. `2086:2086`
4. **Protocol** — TCP / UDP

> 💡 می‌توانید چندین پورت را یکجا اضافه کنید. بعد از هر پورت، پورت بعدی را وارد کنید و در انتها Enter خالی بزنید.

### مرحله ۴ — بررسی اتصال

```bash
stealth-tunnel
# Select: 10) Connection Diagnostics
```

ابزار تشخیص ۷ مرحله‌ای اجرا می‌شود و وضعیت کامل تانل را نشان می‌دهد.

---

## حالت‌های تانل

### ⭐ حالت ۱: RTT + GOST — حداکثر مخفی‌سازی (پیشنهادی)

```
Client --> Iran:Port --> GOST (Relay) --> RTT (Reverse TLS + SNI)
       --> Kharej:RTT --> GOST (Relay) --> Xray/V2Ray
```

| مزیت | توضیح |
|:---|:---|
| 🔐 Two-layer encryption | TLS by RTT + Relay by GOST |
| 🎭 Fake SNI | Traffic looks like `www.google.com` |
| 📦 Multiplexing | Fewer real connections |
| 🔄 Reverse Connection | Kharej connects to Iran |

### حالت ۲: GOST Only — سادگی و سرعت

```
Client --> Iran:Port --> GOST (WSS + Relay + Mux + TLS) --> Kharej --> Xray
```

| مزیت | توضیح |
|:---|:---|
| ⚡ Faster | One less layer |
| 🔧 Simpler | No RTT needed |
| 🌐 WebSocket + TLS | Good obfuscation |

### حالت ۳: RTT Only — حداقل سربار

```
Client --> Iran:Port --> RTT (Reverse TLS + SNI Fake) --> Kharej --> Xray
```

| مزیت | توضیح |
|:---|:---|
| 🚀 Least overhead | Most direct path |
| 🎭 SNI Camouflage | TLS stealth |
| 🔄 Reverse Connection | Reverse tunnel |

---

## نمونه‌ها

### نمونه ۱: فوروارد پورت Xray (تک پورت)

روی **هر دو سرور** اجرا کنید:

```bash
stealth-tunnel
# 2) Add Tunnel
#    Mode: RTT+GOST
#    Name: xray
#    Port: 2086:2086
#    Protocol: TCP
```

### نمونه ۲: فوروارد چند پورت همزمان

روی **هر دو سرور** اجرا کنید:

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

### نمونه ۳: تانل UDP

```bash
stealth-tunnel
# 2) Add Tunnel
#    Mode: GOST Only
#    Name: reality
#    Port: 443:443
#    Protocol: UDP
```

---

## عیب‌یابی

### ابزار تشخیص داخلی

بهترین راه عیب‌یابی استفاده از ابزار داخلی است:

```bash
stealth-tunnel
# 10) Connection Diagnostics
```

این ابزار ۷ مرحله را بررسی می‌کند:

| Step | Check |
|:---|:---|
| [1/7] | Configuration Check |
| [2/7] | Service Status |
| [3/7] | Port Binding Check |
| [4/7] | RTT Tunnel Health |
| [5/7] | GOST Tunnel Health |
| [6/7] | Remote Server Connectivity |
| [7/7] | End-to-End Tunnel Test |

### دستورات دستی

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

### مشکلات رایج

| مشکل | علت | راه‌حل |
|:---|:---|:---|
| `TLS handshake failed` | SNI/password mismatch | SNI and password must match on both servers |
| `connection refused` | Service not running | Restart services on both servers |
| `No peer connected` | Kharej not connected | Create and start tunnel on Kharej too |
| Port not listening | Port occupied | Check: `ss -tlnp \| grep PORT` |
| High CPU | Too many connections | Reduce `connection-age` |
| SNI not working | Domain blocked | Try `www.google.com` or `splus.ir` |

---

## ساختار فایل‌ها

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

## امنیت

| | Feature | Description |
|:---:|:---|:---|
| 🔒 | **TLS 1.3** | All traffic encrypted with TLS 1.3 |
| 🎭 | **SNI Camouflage** | Traffic appears as visits to legitimate websites |
| 🌐 | **WebSocket** | Additional layer to bypass DPI |
| 📦 | **Multiplexing** | Reduces real connections to minimize fingerprint |
| 🔄 | **Reverse Connection** | Kharej connects to Iran, not the other way |
| 📜 | **Self-signed Certs** | TLS certificates with legitimate website CNs |

---

## منوی پنل

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

## لایسنس

MIT License — [LICENSE](LICENSE)

---

## سلب مسئولیت

> این ابزار صرفاً برای **اهداف آموزشی و تحقیقاتی** ارائه شده است.
> استفاده‌کنندگان مسئول رعایت قوانین و مقررات محلی خود هستند.
> توسعه‌دهندگان هیچ مسئولیتی در قبال سوءاستفاده از این ابزار ندارند.

---

<div align="center">

Made with ❤️ by [WarpPacket](https://github.com/WarpPacket)

</div>
