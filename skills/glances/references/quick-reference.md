# Glances Quick Reference

Common operations for quick copy-paste usage.

## Setup

Add credentials to `~/.homelab-skills/.env`:

```bash
GLANCES_URL="http://localhost:61208"
GLANCES_USERNAME=""  # Optional: leave empty if no auth
GLANCES_PASSWORD=""  # Optional: leave empty if no auth
```

Then load in your shell:
```bash
source ~/.homelab-skills/.env
```

## Authentication

If Glances requires authentication, include credentials in curl:

```bash
# With authentication
curl -s -u "$GLANCES_USERNAME:$GLANCES_PASSWORD" "$GLANCES_URL/api/4/cpu" | jq

# Without authentication (default)
curl -s "$GLANCES_URL/api/4/cpu" | jq
```

## Quick Health Checks

### Overall System Status

```bash
# Quick overview (CPU, memory, swap, load)
curl -s "$GLANCES_URL/api/4/quicklook" | jq

# Pretty format with key metrics
curl -s "$GLANCES_URL/api/4/quicklook" | jq '{
  cpu: .cpu,
  memory: .mem,
  swap: .swap,
  load_1min: .load
}'
```

### CPU Quick Checks

```bash
# Current CPU usage
curl -s "$GLANCES_URL/api/4/cpu/total" | jq '.total'

# Per-core usage
curl -s "$GLANCES_URL/api/4/percpu" | jq '.[] | {core: .cpu_number, usage: .total}'

# Load average
curl -s "$GLANCES_URL/api/4/load" | jq '{load_1m: .min1, load_5m: .min5, load_15m: .min15}'
```

### Memory Quick Checks

```bash
# Memory usage percentage
curl -s "$GLANCES_URL/api/4/mem/percent" | jq '.percent'

# Memory details (human-readable GB)
curl -s "$GLANCES_URL/api/4/mem" | jq '{
  total_gb: (.total / 1073741824 | round),
  used_gb: (.used / 1073741824 | round),
  available_gb: (.available / 1073741824 | round),
  percent: .percent
}'

# Swap usage
curl -s "$GLANCES_URL/api/4/memswap" | jq '{
  total_gb: (.total / 1073741824 | round),
  used_gb: (.used / 1073741824 | round),
  percent: .percent
}'
```

### Disk Quick Checks

```bash
# Filesystem usage (all mount points)
curl -s "$GLANCES_URL/api/4/fs" | jq '.[] | {
  mount: .mnt_point,
  percent: .percent,
  free_gb: (.free / 1073741824 | round),
  total_gb: (.size / 1073741824 | round)
}'

# Find filesystems over 80% full
curl -s "$GLANCES_URL/api/4/fs" | jq '.[] | select(.percent > 80) | {
  mount: .mnt_point,
  percent: .percent,
  free_gb: (.free / 1073741824 | round)
}'

# Disk I/O rates
curl -s "$GLANCES_URL/api/4/diskio" | jq '.[] | {
  disk: .disk_name,
  read_mb_s: (.read_bytes_rate_per_sec / 1048576 | round),
  write_mb_s: (.write_bytes_rate_per_sec / 1048576 | round)
}'
```

## Network Monitoring

### Network Interface Stats

```bash
# All interfaces with traffic
curl -s "$GLANCES_URL/api/4/network" | jq '.[] | {
  interface: .interface_name,
  rx_mb_s: (.bytes_recv_rate_per_sec / 1048576 | round),
  tx_mb_s: (.bytes_sent_rate_per_sec / 1048576 | round),
  is_up: .is_up
}'

# Find interfaces with high traffic (> 10 MB/s)
curl -s "$GLANCES_URL/api/4/network" | jq '.[] |
  select(.bytes_recv_rate_per_sec > 10485760 or .bytes_sent_rate_per_sec > 10485760) | {
  interface: .interface_name,
  rx_mb_s: (.bytes_recv_rate_per_sec / 1048576 | round),
  tx_mb_s: (.bytes_sent_rate_per_sec / 1048576 | round)
}'

# List all IP addresses
curl -s "$GLANCES_URL/api/4/ip" | jq
```

### Network Connections

```bash
# Connection states summary
curl -s "$GLANCES_URL/api/4/connections" | jq

# Count established connections
curl -s "$GLANCES_URL/api/4/connections" | jq '.ESTABLISHED'
```

## Process Monitoring

### Top Processes by CPU

```bash
# Top 10 CPU consumers
curl -s "$GLANCES_URL/api/4/processlist" | jq '.[0:10] | .[] | {
  pid: .pid,
  name: .name,
  cpu: .cpu_percent,
  memory: .memory_percent
}'

# Find processes using > 50% CPU
curl -s "$GLANCES_URL/api/4/processlist" | jq '.[] |
  select(.cpu_percent > 50) | {
  pid: .pid,
  name: .name,
  cpu: .cpu_percent,
  user: .username
}'
```

### Top Processes by Memory

```bash
# Top 10 memory consumers
curl -s "$GLANCES_URL/api/4/processlist" | jq 'sort_by(-.memory_percent) | .[0:10] | .[] | {
  pid: .pid,
  name: .name,
  memory: .memory_percent,
  memory_mb: (.memory_info.rss / 1048576 | round)
}'
```

### Process Count by State

```bash
# Process statistics
curl -s "$GLANCES_URL/api/4/processcount" | jq '{
  total: .total,
  running: .running,
  sleeping: .sleeping,
  threads: .thread
}'
```

## Sensor Monitoring

### Temperature Checks

```bash
# All temperature sensors
curl -s "$GLANCES_URL/api/4/sensors" | jq '.[] |
  select(.type == "temperature_core") | {
  sensor: .label,
  temp: .value,
  unit: .unit,
  warning: .warning,
  critical: .critical
}'

# Find sensors above warning threshold
curl -s "$GLANCES_URL/api/4/sensors" | jq '.[] |
  select(.type == "temperature_core" and .value > .warning) | {
  sensor: .label,
  temp: .value,
  warning: .warning,
  critical: .critical
}'
```

### Fan and Battery Status

```bash
# Fan speeds
curl -s "$GLANCES_URL/api/4/sensors" | jq '.[] |
  select(.type == "fan_speed") | {
  fan: .label,
  rpm: .value
}'

# Battery status
curl -s "$GLANCES_URL/api/4/sensors" | jq '.[] |
  select(.type == "battery") | {
  battery: .label,
  percent: .value
}'
```

## Docker Container Monitoring

### Container Overview

```bash
# All containers with status
curl -s "$GLANCES_URL/api/4/containers" | jq '.[] | {
  name: .name,
  status: .status,
  cpu: .cpu_percent,
  memory_mb: (.memory_usage / 1048576 | round),
  image: .image
}'

# Running containers only
curl -s "$GLANCES_URL/api/4/containers" | jq '.[] |
  select(.status == "running") | {
  name: .name,
  cpu: .cpu_percent,
  memory_mb: (.memory_usage / 1048576 | round)
}'

# Find containers using > 50% CPU
curl -s "$GLANCES_URL/api/4/containers" | jq '.[] |
  select(.cpu_percent > 50) | {
  name: .name,
  status: .status,
  cpu: .cpu_percent
}'
```

### Container Network and I/O

```bash
# Container network traffic
curl -s "$GLANCES_URL/api/4/containers" | jq '.[] | {
  name: .name,
  network_rx_mb_s: (.network_rx / 1048576 | round),
  network_tx_mb_s: (.network_tx / 1048576 | round)
}'

# Container disk I/O
curl -s "$GLANCES_URL/api/4/containers" | jq '.[] | {
  name: .name,
  io_read_mb_s: (.io_rx / 1048576 | round),
  io_write_mb_s: (.io_wx / 1048576 | round)
}'
```

## Multi-Server Dashboard Queries

### Query Multiple Glances Servers

```bash
# Define servers
servers=(
  "server1:http://server1.local:61208"
  "server2:http://server2.local:61208"
  "server3:http://server3.local:61208"
)

# Check CPU across all servers
for server in "${servers[@]}"; do
  name="${server%%:*}"
  url="${server#*:}"
  echo "=== $name ==="
  curl -s "$url/api/4/cpu/total" | jq '{server: "'$name'", cpu: .total}'
done
```

### Aggregate Memory Usage

```bash
# Memory usage across fleet
for server in "${servers[@]}"; do
  name="${server%%:*}"
  url="${server#*:}"
  curl -s "$url/api/4/mem" | jq '{
    server: "'$name'",
    memory_used_percent: .percent,
    memory_available_gb: (.available / 1073741824 | round)
  }'
done
```

### Find Hottest Server

```bash
# Check temperatures across fleet
for server in "${servers[@]}"; do
  name="${server%%:*}"
  url="${server#*:}"
  max_temp=$(curl -s "$url/api/4/sensors" | jq '[.[] | select(.type == "temperature_core") | .value] | max')
  echo "$name: ${max_temp}°C"
done | sort -t: -k2 -n -r
```

## Alerts and Monitoring

### Check Active Alerts

```bash
# All active alerts
curl -s "$GLANCES_URL/api/4/alert" | jq '.[] | {
  type: .type,
  state: .state,
  begin: (.begin | strftime("%Y-%m-%d %H:%M:%S")),
  max: .max,
  desc: .desc
}'

# Critical alerts only
curl -s "$GLANCES_URL/api/4/alert" | jq '.[] |
  select(.state == "CRITICAL") | {
  type: .type,
  max: .max,
  desc: .desc
}'
```

### List Available Plugins

```bash
# All enabled plugins
curl -s "$GLANCES_URL/api/4/pluginslist" | jq
```

### API Status Check

```bash
# Health check
curl -s "$GLANCES_URL/api/4/status" && echo "API is UP"

# Get Glances version
curl -s "$GLANCES_URL/api/4/version" | jq
```

## System Information

### Hardware Details

```bash
# System info
curl -s "$GLANCES_URL/api/4/system" | jq

# CPU core count
curl -s "$GLANCES_URL/api/4/core" | jq

# System uptime
curl -s "$GLANCES_URL/api/4/uptime" | jq
```

## Workflows

### Workflow: Comprehensive Health Check

```bash
#!/bin/bash
GLANCES_URL="http://localhost:61208"

echo "=== System Health Check ==="
echo ""

echo "1. CPU Usage:"
curl -s "$GLANCES_URL/api/4/cpu/total" | jq '.total'

echo "2. Memory Usage:"
curl -s "$GLANCES_URL/api/4/mem/percent" | jq '.percent'

echo "3. Disk Usage:"
curl -s "$GLANCES_URL/api/4/fs" | jq '.[] | select(.percent > 70) | {mount: .mnt_point, percent: .percent}'

echo "4. Active Alerts:"
curl -s "$GLANCES_URL/api/4/alert" | jq 'length'

echo "5. Top 5 Processes:"
curl -s "$GLANCES_URL/api/4/processlist" | jq '.[0:5] | .[] | {name: .name, cpu: .cpu_percent}'
```

### Workflow: Container Resource Report

```bash
#!/bin/bash
GLANCES_URL="http://localhost:61208"

echo "=== Docker Container Resource Report ==="
curl -s "$GLANCES_URL/api/4/containers" | jq '.[] | {
  name: .name,
  status: .status,
  cpu: .cpu_percent,
  memory_mb: (.memory_usage / 1048576 | round),
  network_rx_mb: (.network_rx / 1048576 | round),
  network_tx_mb: (.network_tx / 1048576 | round)
}' | jq -s 'sort_by(-.cpu)'
```

### Workflow: Temperature Monitoring Loop

```bash
#!/bin/bash
GLANCES_URL="http://localhost:61208"

while true; do
  clear
  echo "=== Temperature Monitor (updates every 5s) ==="
  date
  curl -s "$GLANCES_URL/api/4/sensors" | jq '.[] |
    select(.type == "temperature_core") | {
    sensor: .label,
    temp: .value,
    warning: .warning,
    status: (if .value > .critical then "CRITICAL" elif .value > .warning then "WARNING" else "OK" end)
  }'
  sleep 5
done
```

### Workflow: Disk Space Alert

```bash
#!/bin/bash
GLANCES_URL="http://localhost:61208"
THRESHOLD=80

curl -s "$GLANCES_URL/api/4/fs" | jq --arg threshold "$THRESHOLD" '.[] |
  select(.percent > ($threshold | tonumber)) | {
  mount: .mnt_point,
  percent: .percent,
  free_gb: (.free / 1073741824 | round),
  total_gb: (.size / 1073741824 | round)
}'
```

## Tips and Tricks

### Watch Mode for Real-Time Updates

```bash
# Monitor CPU usage in real-time (updates every 2s)
watch -n 2 "curl -s $GLANCES_URL/api/4/cpu/total | jq '.total'"

# Monitor memory usage
watch -n 2 "curl -s $GLANCES_URL/api/4/mem/percent | jq '.percent'"
```

### Export to JSON File

```bash
# Capture full system state
curl -s "$GLANCES_URL/api/4/quicklook" > /tmp/glances-$(date +%Y%m%d-%H%M%S).json
```

### Compare States Over Time

```bash
# Take snapshots
curl -s "$GLANCES_URL/api/4/mem" > /tmp/mem-before.json
# ... wait or do work ...
curl -s "$GLANCES_URL/api/4/mem" > /tmp/mem-after.json

# Compare
diff <(jq . /tmp/mem-before.json) <(jq . /tmp/mem-after.json)
```

### Filter Processes by Name

```bash
# Find specific process (e.g., "nginx")
curl -s "$GLANCES_URL/api/4/processlist" | jq '.[] |
  select(.name | contains("nginx")) | {
  pid: .pid,
  name: .name,
  cpu: .cpu_percent,
  memory: .memory_percent
}'
```

## Common jq Patterns

```bash
# Round floating point numbers
jq '.value | round'

# Convert bytes to GB
jq '.bytes / 1073741824 | round'

# Convert bytes to MB
jq '.bytes / 1048576 | round'

# Format timestamp
jq '.timestamp | strftime("%Y-%m-%d %H:%M:%S")'

# Sort by field (descending)
jq 'sort_by(-.cpu_percent)'

# Filter array by condition
jq '.[] | select(.percent > 80)'

# Extract specific fields
jq '{name: .name, value: .value}'

# Array of specific field
jq '[.[] | .name]'

# Count array elements
jq 'length'

# Sum array values
jq '[.[] | .value] | add'

# Average array values
jq '[.[] | .value] | add / length'
```
