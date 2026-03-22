# UniFi Quick Reference

Common operations for quick copy-paste usage. All scripts use credentials from `~/.claude-homelab/.env`.

## Setup

Configure credentials in `.env`:

```bash
UNIFI_URL="https://10.1.0.1"
UNIFI_USERNAME="api"
UNIFI_PASSWORD="your_password"
UNIFI_SITE="default"
```

## Network Dashboard

### Full Network Dashboard

Comprehensive view of all network stats (health, devices, clients, networks, DPI, etc.):

```bash
cd ~/claude-homelab/skills/unifi
bash scripts/dashboard.sh
```

**Output:** ASCII dashboard with all metrics

### JSON Output

Get raw JSON for programmatic access:

```bash
bash scripts/dashboard.sh json
```

## Devices

### List All Devices

Shows all UniFi devices (APs, switches, gateway):

```bash
cd ~/claude-homelab/skills/unifi
bash scripts/devices.sh
```

**Output:**
```
NAME                MODEL       IP           STATE  UPTIME  CLIENTS
----                -----       --           -----  ------  -------
Living Room AP      U6-Pro      10.1.1.10    1      120h    8
Bedroom AP          U6-Lite     10.1.1.11    1      120h    4
Main Switch         USW-24-PoE  10.1.1.5     1      240h    15
Gateway             UCG-Max     10.1.0.1     1      720h    0
```

### Get Raw Device JSON

```bash
bash scripts/devices.sh json | jq
```

### Filter Devices by Type

```bash
# Access Points only
bash scripts/devices.sh json | jq '.data[] | select(.type == "uap")'

# Switches only
bash scripts/devices.sh json | jq '.data[] | select(.type == "usw")'

# Gateway only
bash scripts/devices.sh json | jq '.data[] | select(.type == "ugw")'
```

### Check Device Uptime

```bash
bash scripts/devices.sh json | jq -r '.data[] | "\(.name): \((.uptime / 86400 | floor)) days"'
```

## Clients

### List Active Clients

Shows who's currently connected to the network:

```bash
cd ~/claude-homelab/skills/unifi
bash scripts/clients.sh
```

**Output:**
```
HOSTNAME      IP           MAC                AP              SIGNAL  RX/TX (Mbps)
--------      --           ---                --              ------  ------------
phone-john    10.1.10.50   aa:bb:cc:dd:ee:ff  Living Room AP  -45 dBm 200/50
laptop-jane   10.1.10.51   11:22:33:44:55:66  Bedroom AP      -52 dBm 150/100
```

### Get Raw Client JSON

```bash
bash scripts/clients.sh json | jq
```

### Filter Clients by Signal Strength

```bash
# Clients with poor signal (< -65 dBm)
bash scripts/clients.sh json | jq '.data[] | select(.signal < -65) | {hostname, ip, signal, ap_mac}'
```

### Count Clients per AP

```bash
bash scripts/clients.sh json | jq -r '.data | group_by(.ap_mac) | .[] | "\(.[0].ap_mac): \(length) clients"'
```

### List Wired Clients Only

```bash
bash scripts/clients.sh json | jq '.data[] | select(.is_wired == true)'
```

### List Wireless Clients Only

```bash
bash scripts/clients.sh json | jq '.data[] | select(.is_wired != true)'
```

## Health & Status

### Network Health Summary

Site-wide health status:

```bash
cd ~/claude-homelab/skills/unifi
bash scripts/health.sh
```

**Output:**
```
SUBSYSTEM  STATUS  # UP  # ADOPTED  # DISCONNECTED
---------  ------  ----  ---------  --------------
wan        ok      1     1          0
lan        ok      1     1          0
wlan       ok      3     3          0
```

### Get Raw Health JSON

```bash
bash scripts/health.sh json | jq
```

### Check for Unhealthy Subsystems

```bash
bash scripts/health.sh json | jq '.data[] | select(.status != "ok")'
```

## Bandwidth & DPI

### Top Applications by Traffic

Shows top bandwidth consumers by application (via Deep Packet Inspection):

```bash
cd ~/claude-homelab/skills/unifi
bash scripts/top-apps.sh
```

**Output:**
```
APP           CATEGORY        RX (GB)  TX (GB)  TOTAL (GB)
---           --------        -------  -------  ----------
YouTube       Video           145.23   12.45    157.68
Netflix       Video           98.34    8.21     106.55
Plex          Video           87.12    2.34     89.46
```

### Show Top 15 Applications

```bash
bash scripts/top-apps.sh 15
```

### Get Raw DPI JSON

```bash
# Site-wide DPI
source scripts/unifi-api.sh && unifi_get stat/sitedpi | jq

# Per-client DPI
source scripts/unifi-api.sh && unifi_get stat/stadpi | jq
```

### Top Applications by Category

```bash
source scripts/unifi-api.sh
unifi_get stat/sitedpi | jq -r '.data[0].by_cat[] | "\(.cat): \(((.rx_bytes + .tx_bytes) / 1073741824 | floor))GB"' | sort -t: -k2 -n -r | head -10
```

## Alerts & Events

### Recent Alerts

Shows recent alarms and events:

```bash
cd ~/claude-homelab/skills/unifi
bash scripts/alerts.sh
```

**Output:**
```
TIMESTAMP           KEY                        MESSAGE                         DEVICE
---------           ---                        -------                         ------
2026-02-02 10:30    EVT_AP_Disconnected        AP disconnected                 Living Room AP
2026-02-02 09:15    EVT_AP_Connected           AP connected                    Living Room AP
```

### Show Last 50 Alerts

```bash
bash scripts/alerts.sh 50
```

### Get Raw Alerts JSON

```bash
source scripts/unifi-api.sh && unifi_get stat/alarm | jq
```

### Filter Critical Alerts Only

```bash
source scripts/unifi-api.sh
unifi_get stat/alarm | jq '.data[] | select(.key | contains("Disconnected") or contains("Down") or contains("Failed"))'
```

## Advanced Queries

### Network Configuration

```bash
cd ~/claude-homelab/skills/unifi
source scripts/unifi-api.sh

# List all networks
unifi_get rest/networkconf | jq '.data[] | {name, vlan, purpose}'

# List all WLANs
unifi_get rest/wlanconf | jq '.data[] | {name, security, enabled}'
```

### Port Forwards

```bash
source scripts/unifi-api.sh
unifi_get rest/portforward | jq '.data[] | {name, dst_port, fwd_port, enabled}'
```

### Firewall Rules

```bash
source scripts/unifi-api.sh

# List firewall rules
unifi_get rest/firewallrule | jq '.data[] | {name, action, enabled}'

# List firewall groups
unifi_get rest/firewallgroup | jq '.data[] | {name, group_type, group_members}'
```

### Routing Information

```bash
source scripts/unifi-api.sh

# Active routes
unifi_get stat/routing | jq

# Configured static routes
unifi_get rest/routing | jq '.data[] | {name, static_route_network, static_route_nexthop}'
```

### Dynamic DNS Status

```bash
source scripts/unifi-api.sh
unifi_get stat/dynamicdns | jq
```

### Rogue Access Points

```bash
source scripts/unifi-api.sh
unifi_get stat/rogueap | jq '.data[] | {ssid, bssid, channel, signal}'
```

## Workflows

### Workflow: Full Network Health Check

```bash
cd ~/claude-homelab/skills/unifi

echo "=== Health Status ==="
bash scripts/health.sh

echo -e "\n=== Active Devices ==="
bash scripts/devices.sh

echo -e "\n=== Recent Alerts ==="
bash scripts/alerts.sh 10
```

### Workflow: Client Troubleshooting

```bash
cd ~/claude-homelab/skills/unifi

# Find client by hostname/IP
CLIENT_NAME="phone-john"
bash scripts/clients.sh json | jq --arg name "$CLIENT_NAME" '.data[] | select(.hostname | contains($name))'

# Check signal strength
bash scripts/clients.sh json | jq --arg name "$CLIENT_NAME" '.data[] | select(.hostname | contains($name)) | {hostname, signal, ap_mac, tx_rate, rx_rate}'
```

### Workflow: Bandwidth Analysis

```bash
cd ~/claude-homelab/skills/unifi

echo "=== Top Applications ==="
bash scripts/top-apps.sh 10

echo -e "\n=== Top Clients ==="
source scripts/unifi-api.sh
unifi_get stat/stadpi | jq -r '.data | sort_by(-.tx_bytes + -.rx_bytes) | .[:10][] | "\(.hostname // .mac): \(((.rx_bytes + .tx_bytes) / 1073741824 | floor))GB"'
```

### Workflow: Device Adoption Check

```bash
cd ~/claude-homelab/skills/unifi

# Check for unadopted devices
bash scripts/devices.sh json | jq '.data[] | select(.state != 1) | {name, mac, state, state_name}'

# Check device adoption counts
bash scripts/health.sh json | jq '.data[] | {subsystem, adopted: .num_adopted, disconnected: .num_disconnected}'
```

### Workflow: Export Network Configuration

```bash
cd ~/claude-homelab/skills/unifi
source scripts/unifi-api.sh

# Export all configuration to JSON files
unifi_get rest/networkconf > /tmp/unifi-networks.json
unifi_get rest/wlanconf > /tmp/unifi-wlans.json
unifi_get rest/firewallrule > /tmp/unifi-firewall-rules.json
unifi_get rest/portforward > /tmp/unifi-port-forwards.json

echo "Configuration exported to /tmp/"
```

## Direct API Calls

For operations not covered by existing scripts, use the `unifi-api.sh` helper:

```bash
cd ~/claude-homelab/skills/unifi
source scripts/unifi-api.sh

# Generic GET request (automatically handles login and site path)
unifi_get "stat/sta"  # Active clients
unifi_get "stat/device"  # All devices
unifi_get "rest/user"  # Known users
unifi_get "stat/sysinfo"  # System info

# Check if UniFi is running
if unifi_check_status; then
    echo "UniFi Network application is running: $UNIFI_STATUS_MESSAGE"
else
    echo "UniFi Network application error: $UNIFI_STATUS_MESSAGE"
fi
```

## Output Formats

All main scripts support two output formats:

- **Default (table)**: Human-readable formatted table
- **JSON**: Raw JSON for programmatic access

```bash
# Human-readable table
bash scripts/devices.sh

# Raw JSON
bash scripts/devices.sh json
```

## Common JQ Patterns

### Extract Specific Fields

```bash
bash scripts/devices.sh json | jq '.data[] | {name, ip, model, state}'
```

### Filter and Count

```bash
# Count online devices
bash scripts/devices.sh json | jq '[.data[] | select(.state == 1)] | length'

# Count wireless clients
bash scripts/clients.sh json | jq '[.data[] | select(.is_wired != true)] | length'
```

### Sort by Field

```bash
# Devices by uptime (ascending)
bash scripts/devices.sh json | jq '.data | sort_by(.uptime) | .[] | {name, uptime}'

# Clients by signal strength (weakest first)
bash scripts/clients.sh json | jq '.data | sort_by(.signal) | .[] | {hostname, signal}'
```

## Notes

- All scripts use credentials from `~/.claude-homelab/.env`
- UniFi OS login is handled automatically by `unifi-api.sh`
- All API calls are **read-only GET requests** (safe for monitoring)
- Cookie-based authentication with automatic login
- Tested on UniFi Cloud Gateway Max (UCG-Max) running UniFi OS
