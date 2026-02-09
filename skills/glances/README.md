# Glances Skill

Monitor system health and performance via the Glances REST API from Clawdbot.

## What It Does

- **System Stats** — CPU usage (total and per-core), load average
- **Memory** — RAM and swap usage with detailed breakdowns
- **Disk** — Filesystem space, disk I/O, RAID status, S.M.A.R.T. health
- **Network** — Interface traffic, IP addresses, connection states, WiFi signal
- **Sensors** — Temperature sensors, fan speeds, battery status
- **Containers** — Docker/Podman container stats (CPU, memory, I/O)
- **Processes** — Process list with CPU/memory usage
- **Alerts** — Active system warnings and alerts
- **GPU** — GPU stats if available

All operations are read-only GET requests and safe for monitoring.

## Setup

### 1. Start Glances in Server Mode

On the system you want to monitor:

```bash
# API only (no web UI)
glances -w --disable-webui

# API + Web UI (default port 61208)
glances -w

# Custom port
glances -w -p 61234

# With authentication
glances -w --username admin --password yourpass
```

### 2. Add Credentials to .env

Add the following to `~/claude-homelab/.env`:

```bash
GLANCES_URL="http://localhost:61208"
GLANCES_USERNAME=""  # Optional: leave empty if no auth
GLANCES_PASSWORD=""  # Optional: leave empty if no auth
```

**Configuration options:**
- `GLANCES_URL`: Glances server URL (default port: 61208)
- `GLANCES_USERNAME`: HTTP Basic auth username (leave empty if no auth)
- `GLANCES_PASSWORD`: HTTP Basic auth password (leave empty if no auth)

### 3. Test It

```bash
cd skills/glances
bash scripts/glances-api.sh quicklook
```

## Usage Examples

All commands output JSON. Use `jq` for formatting or filtering.

### Quick System Overview

Get a snapshot of CPU, memory, swap, and load:

```bash
bash scripts/glances-api.sh quicklook
```

### System Information

```bash
bash scripts/glances-api.sh system   # Hostname, OS, platform info
bash scripts/glances-api.sh uptime   # System uptime
bash scripts/glances-api.sh core     # CPU core count
```

### CPU Statistics

```bash
bash scripts/glances-api.sh cpu      # Overall CPU usage
bash scripts/glances-api.sh percpu   # Per-core CPU usage
bash scripts/glances-api.sh load     # Load average (1/5/15 min)
```

### Memory Statistics

```bash
bash scripts/glances-api.sh mem      # RAM usage (total/used/free/percent)
bash scripts/glances-api.sh memswap  # Swap usage
```

### Disk Statistics

```bash
bash scripts/glances-api.sh fs       # Filesystem usage (mount points, space)
bash scripts/glances-api.sh diskio   # Disk I/O (read/write bytes/s)
bash scripts/glances-api.sh raid     # RAID array status (if available)
bash scripts/glances-api.sh smart    # S.M.A.R.T. disk health (if available)
```

### Network Statistics

```bash
bash scripts/glances-api.sh network     # Network interface traffic
bash scripts/glances-api.sh ip          # IP addresses per interface
bash scripts/glances-api.sh wifi        # WiFi signal strength (if available)
bash scripts/glances-api.sh connections # TCP connection states
```

### Temperature and Sensors

```bash
bash scripts/glances-api.sh sensors  # CPU/board temps, fan speeds, battery
bash scripts/glances-api.sh gpu      # GPU stats (if available)
```

### Process Management

```bash
bash scripts/glances-api.sh processlist           # Full process list
bash scripts/glances-api.sh processlist --top 10  # Top 10 by CPU
bash scripts/glances-api.sh processcount          # Process counts by state
```

### Container Statistics

```bash
bash scripts/glances-api.sh containers            # All containers
bash scripts/glances-api.sh containers --running  # Running containers only
```

### System Health

```bash
bash scripts/glances-api.sh alert    # Active alerts and warnings
bash scripts/glances-api.sh status   # API status check
bash scripts/glances-api.sh plugins  # List available plugins
bash scripts/glances-api.sh amps     # Application monitoring (AMPs)
```

### Dashboard (All-in-One)

Comprehensive system overview with all major stats:

```bash
bash scripts/glances-api.sh dashboard
```

### Raw Plugin Access

Access any plugin directly:

```bash
bash scripts/glances-api.sh plugin cpu         # Get CPU plugin data
bash scripts/glances-api.sh plugin cpu total   # Get specific field
```

## Workflow

When a user asks about system health:

1. **"How's the server?"** → `dashboard`
2. **"CPU usage?"** → `cpu` or `percpu`
3. **"Memory?"** → `mem`
4. **"Disk space?"** → `fs`
5. **"What's using resources?"** → `processlist --top 10`
6. **"Container stats?"** → `containers`
7. **"Any problems?"** → `alert`
8. **"Temperatures?"** → `sensors`
9. **"Network traffic?"** → `network`

## Output Examples

### Quick Look
```json
{
  "cpu": 12.5,
  "cpu_name": "AMD Ryzen 9 5900X",
  "mem": 45.2,
  "swap": 0.0,
  "load": 2.15
}
```

### Memory
```json
{
  "total": 32212254720,
  "available": 17637244928,
  "percent": 45.2,
  "used": 14575009792,
  "free": 1234567890
}
```

### Filesystem
```json
[
  {
    "device_name": "/dev/nvme0n1p2",
    "fs_type": "ext4",
    "mnt_point": "/",
    "size": 500107862016,
    "used": 125026965504,
    "free": 375080896512,
    "percent": 25.0
  }
]
```

### Containers
```json
[
  {
    "name": "plex",
    "status": "running",
    "cpu_percent": 5.2,
    "memory_usage": 1073741824,
    "io_rx": 1048576,
    "io_wx": 524288
  }
]
```

## Multiple Servers

Monitor multiple Glances servers using numbered environment variables in `.env`:

```bash
# In ~/claude-homelab/.env
GLANCES1_URL="http://server1.local:61208"
GLANCES1_USERNAME=""
GLANCES1_PASSWORD=""

GLANCES2_URL="http://server2.local:61208"
GLANCES2_USERNAME=""
GLANCES2_PASSWORD=""
```

Then specify server number:
```bash
# Server 1 (default)
bash scripts/glances-api.sh cpu

# Server 2
SERVER_NUM=2 bash scripts/glances-api.sh cpu
```

**Note**: Multi-server support requires script updates (not yet implemented)

## Troubleshooting

**"Glances not configured"**
→ Check that GLANCES_URL is set in `~/claude-homelab/.env`

**"Connection refused"**
→ Ensure Glances is running with `-w` flag on the target system

**401 Unauthorized**
→ Check your username/password if authentication is enabled

**Empty plugin data**
→ Some plugins (gpu, raid, smart) may return empty if not applicable to your system

**"Port already in use"**
→ Default port 61208 may be taken — use custom port with `-p` flag

## Notes

- Uses Glances REST API v4 (Glances 4.x+)
- Default port is 61208
- All sizes are in bytes
- Temperatures are in Celsius
- Some plugins require additional dependencies (lm-sensors, hddtemp, etc.)
- Authentication is optional but recommended for remote access
- Requires `curl` and `jq` installed

## Glances Installation

If Glances is not installed:

```bash
# Ubuntu/Debian
sudo apt install glances

# Python pip (latest version)
pip install glances

# With optional dependencies
pip install 'glances[web,docker]'
```

## Security

- Use authentication for remote monitoring
- Run Glances on localhost and access via SSH tunnel for security
- Never expose Glances API to the public internet without authentication
- Consider using reverse proxy with TLS for remote access

## Reference

- [API Endpoints Documentation](references/api-endpoints.md) — Full endpoint reference
- [Glances Official Docs](https://glances.readthedocs.io/en/latest/api/restful.html)

## License

MIT
