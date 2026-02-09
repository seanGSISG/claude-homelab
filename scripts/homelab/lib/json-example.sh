#!/bin/bash
# Example usage of lib/json.sh
# This demonstrates how to use the JSON helper library in actual scripts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/json.sh"

echo "=== JSON Helper Library Usage Examples ==="
echo

# Example 1: Building a simple object
echo "Example 1: Simple object"
server_info=$(json_object \
    "hostname" "web-server-01" \
    "ip" "192.168.1.100" \
    "status" "running")
echo "$server_info" | jq '.'
echo

# Example 2: Building an array of strings
echo "Example 2: Array of strings"
tags=$(json_array "production" "web" "critical")
echo "$tags" | jq '.'
echo

# Example 3: Building objects in a loop (like disk monitoring)
echo "Example 3: Array of disk objects"
disk_array=()
for disk in sda sdb sdc; do
    disk_obj=$(json_object \
        "name" "$disk" \
        "temp" "42" \
        "status" "healthy")
    disk_array+=("$disk_obj")
done

disks_json=$(json_array_of_json "${disk_array[@]}")
echo "$disks_json" | jq '.'
echo

# Example 4: Nested structure (like linux-dashboard.sh does)
echo "Example 4: Nested structure with hardware info"

# Build memory modules array
mem_modules=$(json_array_of_json \
    "$(json_object "size" "16GB" "type" "DDR4" "speed" "3200")" \
    "$(json_object "size" "16GB" "type" "DDR4" "speed" "3200")")

# Build hardware object with nested arrays
hardware=$(json_object_with_json \
    "manufacturer" '"Dell Inc."' \
    "model" '"PowerEdge R740"' \
    "memory_modules" "$mem_modules")

echo "$hardware" | jq '.'
echo

# Example 5: Complete dashboard-style output
echo "Example 5: Complete dashboard output"

# Collect system info
system_info=$(json_object \
    "hostname" "$(hostname)" \
    "uptime" "$(uptime -p 2>/dev/null || echo 'unknown')" \
    "kernel" "$(uname -r)")

# Build alerts array
alerts=$(json_array_of_json \
    "$(json_object "severity" "warning" "message" "High CPU usage" "value" "85")" \
    "$(json_object "severity" "info" "message" "Backup completed" "value" "0")")

# Build final JSON document
dashboard=$(json_object_with_json \
    "timestamp" "$(date +%s)" \
    "version" '"1.0.0"' \
    "system" "$system_info" \
    "alerts" "$alerts")

echo "$dashboard" | jq '.'
echo

# Example 6: String escaping for values with special characters
echo "Example 6: Escaping special characters"
message=$(json_object \
    "log" 'Error: "file not found" at /path/to/file' \
    "path" '/usr/local/bin' \
    "status" 'failed with code 1')
echo "$message" | jq '.'
echo

echo "=== All examples completed successfully ==="
