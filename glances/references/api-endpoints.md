# Glances REST API v4 Endpoints Reference

Base URL: `http://localhost:61208/api/4`

## API Status & Discovery

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/status` | GET | API status check (returns 200 if OK) |
| `/pluginslist` | GET | List all available plugins |

## System Information

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/system` | GET | System info (hostname, OS, platform) |
| `/uptime` | GET | System uptime string |
| `/core` | GET | CPU core count (physical/logical) |
| `/version` | GET | Glances version |
| `/psutilversion` | GET | psutil library version |

## CPU & Load

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/cpu` | GET | Overall CPU usage stats |
| `/cpu/<field>` | GET | Specific CPU field (e.g., `/cpu/total`) |
| `/percpu` | GET | Per-core CPU usage |
| `/load` | GET | Load average (1/5/15 min) |
| `/quicklook` | GET | Quick CPU/mem/swap/load summary |

### CPU Fields
- `total` - Sum of all CPU percentages (except idle)
- `user` - Time in user space
- `system` - Time in kernel space
- `idle` - Idle time
- `iowait` - Waiting for I/O
- `irq` - Hardware interrupts
- `nice` - Nice'd processes
- `steal` - Time stolen by hypervisor
- `guest` - Running virtual CPUs
- `ctx_switches` - Context switches/sec
- `interrupts` - Interrupts/sec
- `cpucore` - Total CPU cores

## Memory

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/mem` | GET | Memory usage stats |
| `/mem/<field>` | GET | Specific memory field |
| `/memswap` | GET | Swap usage stats |

### Memory Fields
- `total` - Total physical memory (bytes)
- `available` - Available memory (bytes)
- `used` - Used memory (bytes)
- `free` - Free memory (bytes)
- `percent` - Memory usage percentage
- `active` - Active memory
- `inactive` - Inactive memory
- `buffers` - Buffer memory
- `cached` - Cached memory

## Disk

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/fs` | GET | Filesystem usage (mount points) |
| `/diskio` | GET | Disk I/O statistics |
| `/raid` | GET | RAID array status |
| `/smart` | GET | S.M.A.R.T. disk health |
| `/folders` | GET | Monitored folders |

### Filesystem Fields
- `device_name` - Device path
- `fs_type` - Filesystem type (ext4, xfs, etc.)
- `mnt_point` - Mount point
- `size` - Total size (bytes)
- `used` - Used space (bytes)
- `free` - Free space (bytes)
- `percent` - Usage percentage

### Disk I/O Fields
- `disk_name` - Disk name
- `read_bytes` - Total bytes read
- `write_bytes` - Total bytes written
- `read_count` - Read operations
- `write_count` - Write operations
- `read_bytes_rate_per_sec` - Read rate
- `write_bytes_rate_per_sec` - Write rate

## Network

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/network` | GET | Network interface statistics |
| `/ip` | GET | IP addresses |
| `/wifi` | GET | WiFi signal strength |
| `/connections` | GET | TCP connection states |
| `/ports` | GET | Monitored ports |

### Network Fields
- `interface_name` - Interface name
- `bytes_recv` - Total bytes received
- `bytes_sent` - Total bytes sent
- `bytes_recv_rate_per_sec` - RX rate
- `bytes_sent_rate_per_sec` - TX rate
- `speed` - Interface speed
- `is_up` - Interface status

### Connection States
- `LISTEN` - Listening connections
- `ESTABLISHED` - Established connections
- `SYN_SENT`, `SYN_RECV` - TCP handshake states
- `nf_conntrack_count` - Tracked connections (netfilter)

## Sensors

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/sensors` | GET | Temperature, fan, battery sensors |
| `/gpu` | GET | GPU statistics |

### Sensor Fields
- `label` - Sensor name
- `value` - Current value
- `unit` - Unit (°C, RPM, %, etc.)
- `type` - Sensor type (temperature_core, fan_speed, battery)
- `warning` - Warning threshold
- `critical` - Critical threshold

## Processes

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/processlist` | GET | Full process list (sorted by CPU) |
| `/processcount` | GET | Process counts by state |
| `/programlist` | GET | Grouped by program name |

### Process Fields
- `pid` - Process ID
- `name` - Process name
- `username` - Owner username
- `cpu_percent` - CPU usage %
- `memory_percent` - Memory usage %
- `status` - Process status (running, sleeping, etc.)
- `nice` - Nice value
- `num_threads` - Thread count
- `cmdline` - Full command line

### Process Counts
- `total` - Total processes
- `running` - Running
- `sleeping` - Sleeping
- `stopped` - Stopped
- `zombie` - Zombie processes
- `thread` - Total threads
- `pid_max` - Maximum PID

## Containers

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/containers` | GET | Docker/Podman container stats |
| `/containers/name` | GET | List container names |
| `/containers/name/value/<name>` | GET | Specific container by name |

### Container Fields
- `name` - Container name
- `id` - Container ID
- `status` - Status (running, paused, etc.)
- `image` - Image name
- `cpu_percent` - CPU usage
- `memory_usage` - Memory bytes used
- `memory_limit` - Memory limit
- `network_rx` - Network RX rate
- `network_tx` - Network TX rate
- `io_rx` - Disk read rate
- `io_wx` - Disk write rate
- `uptime` - Container uptime
- `engine` - Container engine (docker/podman)
- `ports` - Exposed ports

## Alerts & Events

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/alert` | GET | Active alerts/warnings |
| `/events/clear/all` | POST | Clear all alerts |
| `/events/clear/warning` | POST | Clear warning alerts |

### Alert Fields
- `begin` - Start timestamp
- `end` - End timestamp (-1 if ongoing)
- `state` - WARNING or CRITICAL
- `type` - CPU, LOAD, MEM, etc.
- `max`, `avg`, `min` - Values during event
- `desc` - Description
- `top` - Top 3 processes during event

## Application Monitoring (AMPs)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/amps` | GET | Application monitoring plugins |

### AMP Fields
- `name` - AMP name
- `result` - Result string
- `count` - Matching process count
- `countmin` - Minimum expected
- `countmax` - Maximum expected
- `refresh` - Refresh interval

## Virtual Machines

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/vms` | GET | Virtual machine stats (if available) |

## Field Access Pattern

Get specific field from any plugin:
```
GET /api/4/<plugin>/<field>
```

Example:
```bash
# Get just CPU total
curl http://localhost:61208/api/4/cpu/total
{"total": 12.5}

# Get all interface names
curl http://localhost:61208/api/4/network/interface_name
{"interface_name": ["eth0", "lo", "docker0"]}
```

## Item Filtering

Get specific item by field value:
```
GET /api/4/<plugin>/<field>/value/<value>
```

Example:
```bash
# Get specific container
curl http://localhost:61208/api/4/containers/name/value/nginx
```

## Authentication

If Glances is started with `--username` and `--password`, use HTTP Basic Auth:
```bash
curl -u username:password http://localhost:61208/api/4/cpu
```

## API Documentation

Glances includes built-in API docs at:
```
http://localhost:61208/docs#/
```

## OpenAPI Spec

Full OpenAPI specification:
```
https://raw.githubusercontent.com/nicolargo/glances/refs/heads/develop/docs/api/openapi.json
```
