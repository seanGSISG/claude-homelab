# lib/json.sh - JSON Helper Library

Pure bash + jq helper functions for building JSON objects and arrays in shell scripts.

## Overview

This library provides standardized functions for constructing JSON data structures, eliminating the need for manual JSON string construction or repetitive `jq -n` invocations.

## Dependencies

- `jq` - Command-line JSON processor

## Functions

### json_escape()

Escape special characters in strings for safe JSON inclusion.

```bash
# Usage
json_escape "string with \"quotes\" and \n newlines"

# Returns
"string with \"quotes\" and \n newlines"
```

**Use cases:**
- Escaping user input
- Handling strings with quotes, newlines, or backslashes
- Preparing strings for manual JSON construction

### json_object()

Build JSON objects from key-value pairs.

```bash
# Usage
json_object "key1" "value1" "key2" "value2" ...

# Example
server_info=$(json_object \
    "hostname" "web-server-01" \
    "ip" "192.168.1.100" \
    "status" "running")

# Returns
{"hostname":"web-server-01","ip":"192.168.1.100","status":"running"}
```

**Notes:**
- All values are treated as **strings**
- For complex values (objects, arrays, numbers, booleans), use `json_object_with_json()`
- Empty arguments return `{}`

### json_array()

Build JSON arrays from string items.

```bash
# Usage
json_array "item1" "item2" "item3" ...

# Example
tags=$(json_array "production" "web" "critical")

# Returns
["production","web","critical"]
```

**Notes:**
- All items are treated as **strings**
- For arrays of objects/complex types, use `json_array_of_json()`
- Empty arguments return `[]`

### json_array_of_json()

Build JSON arrays from pre-formatted JSON objects or arrays.

```bash
# Usage
json_array_of_json "json_item1" "json_item2" ...

# Example - Array of disk objects
disk_array=()
for disk in sda sdb sdc; do
    disk_obj=$(json_object "name" "$disk" "temp" "42" "status" "healthy")
    disk_array+=("$disk_obj")
done
disks_json=$(json_array_of_json "${disk_array[@]}")

# Returns
[{"name":"sda","temp":"42","status":"healthy"},{"name":"sdb",...},...]
```

**Use cases:**
- Building arrays in loops
- Collecting multiple JSON objects into an array
- Combining pre-built JSON structures

### json_object_with_json()

Build JSON objects with complex (non-string) values.

```bash
# Usage
json_object_with_json "key1" '{"nested": "object"}' "key2" '[1,2,3]'

# Example - Nested hardware structure
mem_modules=$(json_array_of_json \
    "$(json_object "size" "16GB" "type" "DDR4")" \
    "$(json_object "size" "16GB" "type" "DDR4")")

hardware=$(json_object_with_json \
    "manufacturer" '"Dell Inc."' \
    "model" '"PowerEdge R740"' \
    "memory_modules" "$mem_modules")

# Returns
{
  "manufacturer": "Dell Inc.",
  "model": "PowerEdge R740",
  "memory_modules": [
    {"size": "16GB", "type": "DDR4"},
    {"size": "16GB", "type": "DDR4"}
  ]
}
```

**Notes:**
- String values must be quoted: `"manufacturer" '"Dell Inc."'` (notice double quoting)
- Numeric/boolean values: `"count" '42'` or `"enabled" 'true'`
- Object/array values: Pass pre-built JSON from other functions

## Common Patterns

### Pattern 1: Building objects in loops

```bash
source lib/json.sh

# Collect disk information
disk_array=()
for disk in /dev/sd[a-z]; do
    name=$(basename "$disk")
    temp=$(smartctl -A "$disk" | awk '/Temperature/ {print $10}')
    health=$(smartctl -H "$disk" | awk '/SMART overall-health/ {print $6}')

    disk_obj=$(json_object \
        "name" "$name" \
        "temp" "$temp" \
        "health" "$health")

    disk_array+=("$disk_obj")
done

# Combine into final array
disks_json=$(json_array_of_json "${disk_array[@]}")
echo "$disks_json" | jq '.'
```

### Pattern 2: Nested dashboard structure

```bash
source lib/json.sh

# Build system info
system_info=$(json_object \
    "hostname" "$(hostname)" \
    "kernel" "$(uname -r)" \
    "uptime" "$(uptime -p)")

# Build alerts array
alerts=$(json_array_of_json \
    "$(json_object "severity" "warning" "message" "High CPU")" \
    "$(json_object "severity" "info" "message" "Backup OK")")

# Build final document
dashboard=$(json_object_with_json \
    "timestamp" "$(date +%s)" \
    "version" '"1.0.0"' \
    "system" "$system_info" \
    "alerts" "$alerts")

echo "$dashboard" | jq '.'
```

### Pattern 3: Replacing manual jq construction

**Before** (manual jq):
```bash
hw_json=$(jq -n \
    --arg sys_mfg "$sys_manufacturer" \
    --arg sys_prod "$sys_product" \
    --arg sys_serial "$sys_serial" \
    '{
        system: {
            manufacturer: $sys_mfg,
            product: $sys_prod,
            serial: $sys_serial
        }
    }')
```

**After** (using library):
```bash
system=$(json_object \
    "manufacturer" "$sys_manufacturer" \
    "product" "$sys_product" \
    "serial" "$sys_serial")

hw_json=$(json_object_with_json "system" "$system")
```

## Testing

Run the test suite:

```bash
bash lib/test-json.sh
```

See usage examples:

```bash
bash lib/json-example.sh
```

## Integration

Source the library at the top of your script:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/json.sh"

# Now use json_* functions
result=$(json_object "status" "ok")
```

## Performance Notes

- All functions use `jq` for JSON processing (reliable and fast)
- For large loops (1000+ items), consider using `jq` streaming directly
- String escaping via `jq -R -s` is safer than manual escaping

## Troubleshooting

### "jq: command not found"

Install jq:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq
```

### Values appearing as strings instead of numbers/booleans

Use `json_object_with_json()` instead of `json_object()`:

```bash
# Wrong - "count" will be string "42"
json_object "count" "42"

# Correct - "count" will be number 42
json_object_with_json "count" '42'
```

### Nested quotes getting escaped

For string values in `json_object_with_json()`, double-quote them:

```bash
# Correct
json_object_with_json "name" '"John"'

# Wrong (will fail)
json_object_with_json "name" 'John'
```

## Related Libraries

- `lib/logging.sh` - Structured logging
- `lib/state.sh` - State file management
- `lib/notify.sh` - Alert notifications

## Version History

- **1.0.0** (2026-02-01) - Initial implementation
  - json_escape, json_object, json_array
  - json_array_of_json, json_object_with_json
  - Full test suite
