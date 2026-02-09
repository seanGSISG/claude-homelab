# Homelab Scripts - Development Guidelines

## ⚠️ CRITICAL TOOL USAGE RULES (READ FIRST)

### zsh-tool: ALWAYS Use PTY Mode

**MANDATORY:** When executing commands that produce output (API calls, JSON responses, formatted data), ALWAYS include \`pty: true\`.

**Why:** The zsh-tool may silently drop stdout/stderr without PTY mode, even when commands succeed.

**Required for:**
- All skill script executions (\`./skills/*/scripts/*.sh\`)
- API calls returning JSON (qBittorrent, Firecrawl, Unraid, etc.)
- Commands with formatted output
- Any command where you need to see results

**Pattern:**
\`\`\`typescript
<invoke name="mcp__plugin_zsh-tool_zsh-tool__zsh">
<parameter name="command">./skills/qbittorrent/scripts/qbit-api.sh list</parameter>
<parameter name="pty">true</parameter>  ← REQUIRED
</invoke>
\`\`\`

**Exception:** Only omit PTY when you only care about exit code, not output.

---


This repository contains homelab monitoring and automation scripts designed for cron execution. Scripts are organized by function category for better maintainability, code reuse, and temporal data tracking.

## Repository Structure

```
homelab/
├── orchestrator.sh           # Main entry point for coordinated execution
├── dashboard/                # System monitoring dashboards
│   ├── linux.sh             # Linux system monitoring (SMART, hardware, services)
│   ├── unraid.sh            # Unraid fleet monitoring (GraphQL API)
│   ├── unifi.sh             # UniFi network infrastructure
│   └── overseerr.sh         # Overseerr media request monitoring
├── inventory/               # Static inventory collection
│   ├── docker.sh            # Docker container inventory
│   ├── ssh.sh               # SSH server inventory
│   ├── swag.sh              # SWAG reverse proxy configuration
│   └── tailscale.sh         # Tailscale network inventory
├── monitor/                 # Resource monitoring and anomaly detection
│   ├── docker-cache.sh      # Docker bloat monitoring and auto-pruning
│   └── unifi-anomaly.sh     # UniFi network anomaly detection
├── report/                  # Aggregated reporting
│   └── weekly.sh            # Weekly summary report (multi-script aggregation)
├── lib/                     # Shared libraries (NEVER run directly)
│   ├── logging.sh           # Structured logging with rotation
│   ├── notify.sh            # Notification system (Gotify, file)
│   ├── state.sh             # State file management
│   ├── json.sh              # JSON output helpers
│   ├── load-env.sh          # Environment variable loading
│   ├── remote-exec.sh       # SSH execution wrapper
│   └── linux-collector.sh   # Linux-specific data collectors
├── scripts/                 # Utility scripts (development, testing)
│   ├── verify-env-migration.sh
│   └── validate-api-docs.sh
└── .env                     # Credentials (gitignored, NEVER commit)
```

### Directory Naming Convention

**Singular directory names** for clarity and consistency:
- `dashboard/` (not `dashboards/`)
- `inventory/` (not `inventories/`)
- `monitor/` (not `monitors/`)
- `report/` (not `reports/`)

**Non-redundant script names** - category is already in path:
- `dashboard/linux.sh` (not `dashboard/linux-dashboard.sh`)
- `inventory/docker.sh` (not `inventory/docker-inventory.sh`)
- `monitor/docker-cache.sh` (descriptive within category)
- `report/weekly.sh` (not `report/weekly-summary.sh`)

**Why this organization:**
- Clear separation of concerns (monitoring vs inventory vs reporting)
- Shorter, cleaner script names (category provides context)
- Easier to find related functionality
- Scales better as more scripts are added

## Script Execution

### Running Scripts

All scripts can be executed directly from the repository root or their category directory:

```bash
# From repository root
./dashboard/linux.sh
./inventory/docker.sh
./monitor/docker-cache.sh

# From category directory
cd dashboard && ./linux.sh
cd inventory && ./docker.sh
```

### Orchestrator

The `orchestrator.sh` script at the repository root provides coordinated execution of multiple scripts:

```bash
# Run all dashboards
./orchestrator.sh --category dashboard

# Run specific scripts
./orchestrator.sh --scripts "dashboard/linux.sh,inventory/docker.sh"

# Run with custom environment
WARN_THRESHOLD=75 ./orchestrator.sh --category dashboard
```

**Why use orchestrator:**
- Parallel execution for faster runs
- Centralized logging and error handling
- Consistent execution order
- Easy to schedule multiple related scripts

### Library Sourcing Pattern

All categorized scripts MUST use the `REPO_ROOT` pattern for library sourcing:

```bash
# Correct: Works from any category directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/notify.sh"

# Incorrect: Only works if script is in repository root
source "$SCRIPT_DIR/lib/logging.sh"  # ❌ Breaks for categorized scripts
```

**Why this matters:**
- Scripts in subdirectories need to traverse up to find `lib/`
- Consistent pattern works regardless of script location
- Makes scripts portable and testable

## Core Principles

### 1. Code Sharing via lib/
All shared functionality lives in `lib/` subdirectory. Scripts MUST source shared libraries rather than duplicating code.

**Shared libraries:**
- `lib/load-env.sh` - Environment variable loading and validation
- `lib/notify.sh` - Notification system (Gotify, file, message tool)
- `lib/logging.sh` - Structured logging functions
- `lib/json.sh` - JSON output helpers
- `lib/state.sh` - State file management

### 2. Dual-Format Output Pattern
Scripts output data in TWO formats for different use cases:

#### Structure
**Location:** `~/memory/bank/<script-name>/`

```
~/memory/bank/
  └── script-name/
      ├── current.md              ← Human-readable, always current
      ├── latest.json             ← Symlink to most recent JSON
      ├── 1706472000.json        ← Historical state (2 hours ago)
      ├── 1706475600.json        ← Historical state (1 hour ago)
      └── 1706479200.json        ← Historical state (just now, latest points here)
```

**Benefits:**
- All monitoring data in one place
- Git tracked for backup/history
- Claude Code can read files directly
- Ready for future semantic indexing
- Markdown for humans, JSON for machines
- Temporal analysis via timestamped files

#### Retention Policy (Configurable)
```bash
# Default: Keep last 168 files (7 days of hourly runs)
STATE_RETENTION="${STATE_RETENTION:-168}"
```

Adjust retention based on run frequency:
- Hourly runs: `168` = 7 days
- Daily runs: `90` = 90 days
- Weekly runs: `52` = 1 year

### 3. Defensive Bash Patterns
All scripts follow defensive programming practices:
- `set -euo pipefail` (strict mode)
- Quoted variables: `"$var"`
- Error trapping and cleanup
- Input validation
- Timeout protection for external commands

### 4. Dashboard Parity (dashboard/unraid.sh ↔ dashboard/linux.sh)
**CRITICAL:** When adding new data collection to one dashboard, ALWAYS add comparable data to the other.

**Philosophy:**
- These are the two primary system dashboards
- `dashboard/unraid.sh` - Monitors Unraid servers via GraphQL API
- `dashboard/linux.sh` - Monitors Ubuntu/Linux systems via shell commands
- They should collect **equivalent data** from their respective platforms

**Parity Requirements:**

When adding a new data source to either dashboard, ask:
1. **Does this data exist on both platforms?** (e.g., disk temps, containers, memory)
   - ✅ If yes → Add to BOTH dashboards
   - ❌ If no → Add only to relevant dashboard (e.g., ZFS pools on Linux, array status on Unraid)

2. **Can we collect it via different methods?**
   - Unraid: GraphQL API queries
   - Linux: Shell commands (smartctl, dmidecode, docker, etc.)

3. **Should it trigger alerts on both?**
   - Keep threshold logic consistent where applicable

**Examples of Parity:**

| Data Category | Unraid Dashboard | Linux Dashboard | Status |
|---------------|------------------|-----------------|--------|
| System Info | ✅ GraphQL `info{...}` | ✅ `/etc/os-release`, `dmidecode` | ✅ Parity |
| CPU Details | ✅ GraphQL `cpu{...}` | ✅ `lscpu`, `/proc/cpuinfo` | ✅ Parity |
| Memory Modules | ✅ GraphQL `memory{...}` | ✅ `dmidecode -t memory` | ✅ Parity |
| Disk Temps | ✅ GraphQL disk temps | ✅ `smartctl -A` | ✅ Parity |
| Disk Health | ✅ GraphQL disk status | ✅ `smartctl -H` | ✅ Parity |
| Docker Containers | ✅ GraphQL `docker{...}` | ✅ `docker ps -a` | ✅ Parity |
| **Container Details** | ✅ **Lists exited containers** | ✅ **Lists exited containers** | ✅ **Parity** |
| USB Devices | ✅ GraphQL `devices{...}` | ✅ `lsusb` | ✅ Parity |
| PCI Devices | ✅ GraphQL `devices{...}` | ✅ `lspci` | ✅ Parity |
| Network Interfaces | ✅ GraphQL `devices.network` | ✅ `ip addr`, `ethtool` | ✅ Parity |
| Network Model/Vendor | ✅ GraphQL NIC details | ✅ `ethtool -i` (driver/model) | ✅ Parity |
| CPU Voltage | ❌ Not in API | ✅ `/sys/class/hwmon/*/in*_input` | ⚠️ Linux-only |
| Virtual Machines | ✅ GraphQL `vms{...}` | ✅ `virsh list --all` (libvirt) | ✅ Parity |
| Systemd Services | ❌ N/A (Unraid uses Slackware init) | ✅ `systemctl --failed` | ✅ Platform-specific |
| Tailscale Status | ❌ Not exposed via API | ✅ `tailscale status --json` | ⚠️ API limitation |
| ZFS Pools | ❌ N/A (Unraid uses array) | ✅ `zpool status` | ✅ Platform-specific |
| Unraid Array | ✅ GraphQL `array{...}` | ❌ N/A (Linux has ZFS/LVM) | ✅ Platform-specific |

**Workflow When Adding Features:**

```bash
# Adding new feature to dashboard/unraid.sh:
1. Implement the feature
2. Check: "Can Linux collect similar data?"
3. If yes → Update dashboard/linux.sh with equivalent collection
4. Update this parity table in CLAUDE.md

# Adding new feature to dashboard/linux.sh:
1. Implement the feature
2. Check: "Does Unraid expose this via GraphQL?"
3. If yes → Update dashboard/unraid.sh with equivalent query
4. Update this parity table in CLAUDE.md
```

**Recent Parity Updates:**
- 2026-02-01: Added VM detection (libvirt), network model/vendor (ethtool -i), CPU voltage to dashboard/linux.sh
- 2026-02-01: Added version tracking to both dashboards
- 2026-01-25: Added exited container listing to both dashboards
- 2026-01-25: Added full hardware parity (SMART, DMI, USB/PCI devices)

### 5. Credential Management

All scripts MUST use centralized environment variable loading from `.env` file.

**Pattern:**
```bash
# Find repository root (handles categorized scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/lib/load-env.sh"

# Load service credentials from .env
load_service_credentials "service" "SERVICE_URL" "SERVICE_API_KEY"
```

**Credential Loading Order:**
1. Environment variables (if already set in shell)
2. `.env` file (required at homelab root: `~/workspace/homelab/.env`)
3. ERROR if .env missing or variables not set

**Security:**
- ✅ `.env` file is gitignored (NEVER commit credentials)
- ✅ Set .env permissions: `chmod 600 .env`
- ✅ NEVER log credentials (even in debug mode)
- ✅ Single-file credential rotation (edit `.env`, done)

**Required for ALL scripts:**
- Use `load_service_credentials()` for credential loading
- Validate credentials with `validate_env_vars()` if needed
- Scripts MUST fail with clear error if `.env` missing
- NO config.json files - `.env` only

**Example - Multi-server (Unraid):**
```bash
source "$REPO_ROOT/lib/load-env.sh"
load_env_file || exit 1

# Validate all servers
for server in "TOOTIE" "SHART"; do
    url_var="UNRAID_${server}_URL"
    key_var="UNRAID_${server}_API_KEY"
    validate_env_vars "$url_var" "$key_var" || exit 1
done
```

**Credential Rotation:**
1. Edit `.env` with new credentials
2. Test: `./scripts/verify-env-migration.sh`
3. If successful, all scripts use new credentials immediately
4. Monitor logs for errors

## Script Template

Use this template for all new monitoring scripts:

```bash
#!/bin/bash
# Script Name: script-name.sh
# Purpose: Brief description of what this monitors/does
# Output: JSON state file to ~/memory/bank/script-name/
# Cron: Suggested schedule (e.g., "0 * * * *" for hourly)

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_VERSION="1.0.0"  # Script version for tracking changes

# Repository root (handles categorized scripts in subdirectories)
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Paths (flat structure in memory/bank)
STATE_DIR="${STATE_DIR:-$HOME/memory/bank/$SCRIPT_NAME}"
CURRENT_MD="$STATE_DIR/current.md"  # Standard: use 'current.md' (not 'latest.md')

# Timestamps
TIMESTAMP=$(date +%s)
JSON_FILE="$STATE_DIR/${TIMESTAMP}.json"
LATEST_LINK="$STATE_DIR/latest.json"

# Retention (configurable via environment)
STATE_RETENTION="${STATE_RETENTION:-168}"  # Keep last 168 files (7 days hourly)

# Enable Gotify notifications by default (with graceful degradation)
export CRONJOB_NOTIFY_METHOD="${CRONJOB_NOTIFY_METHOD:-gotify}"

# Source shared libraries (using REPO_ROOT for categorized scripts)
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/json.sh"
source "$REPO_ROOT/lib/notify.sh"
source "$REPO_ROOT/lib/state.sh"

# Configurable thresholds (via environment variables)
WARN_THRESHOLD="${WARN_THRESHOLD:-80}"
CRIT_THRESHOLD="${CRIT_THRESHOLD:-95}"

# === Cleanup ===
trap 'log_error "Script failed on line $LINENO"' ERR
trap 'cleanup' EXIT

cleanup() {
    # Cleanup temporary files, etc.
    :
}

# === Functions ===

# Main data collection function
collect_data() {
    local -a results=()
    
    # Collect monitoring data
    # ... implementation ...
    
    # Return as JSON array
    json_array "${results[@]}"
}

# Check thresholds and generate alerts
check_thresholds() {
    local value="$1"
    local threshold="$2"
    
    if (( value > threshold )); then
        return 1
    fi
    return 0
}

# === Main Script ===

main() {
    # ⚠️  REQUIRED: Initialize logging (enables log rotation)
    # This MUST be the first line in main() - see "Common Pitfalls" section
    init_logging "$SCRIPT_NAME"
    
    log_info "Starting $SCRIPT_NAME"
    
    # Ensure state directory exists
    ensure_state_dir "$STATE_DIR"
    
    # Collect data
    log_info "Collecting data..."
    DATA=$(collect_data)
    
    # 1. Write JSON state file (timestamped)
    cat > "$JSON_FILE" <<EOF
{
  "timestamp": $TIMESTAMP,
  "script": "$SCRIPT_NAME",
  "version": "$SCRIPT_VERSION",
  "data": $DATA,
  "metadata": {
    "hostname": "$(hostname)",
    "execution_time": "$(($(date +%s) - TIMESTAMP))s"
  }
}
EOF
    log_info "JSON state saved to: $JSON_FILE"
    
    # 2. Update 'latest' symlink
    ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"
    
    # 3. Convert to markdown inventory (human-readable)
    generate_markdown_inventory "$DATA" > "$CURRENT_MD"
    log_info "Markdown inventory saved to: $CURRENT_MD"
    
    # 4. Clean up old state files (keep per retention policy)
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"
    
    # Check for alerts
    ALERTS=$(check_for_alerts "$DATA")
    
    if [[ -n "$ALERTS" ]]; then
        notify_alert "$SCRIPT_NAME Alert" "$ALERTS" "normal"
    fi
    
    log_info "$SCRIPT_NAME completed successfully"
}

# Generate markdown inventory from JSON data
generate_markdown_inventory() {
    local data="$1"
    
    cat <<EOF
# $SCRIPT_NAME Inventory
Generated: $(date)

## Summary
$data

<!-- Add your markdown formatting here -->
EOF
}

# Run main function
main "$@"
```

## JSON Output Schema

All scripts should produce consistent JSON structure:

```json
{
  "timestamp": 1706472000,
  "script": "script-name",
  "version": "1.0.0",
  "data": {
    "// Script-specific data here": {}
  },
  "alerts": [
    {
      "severity": "warning|critical",
      "message": "Human readable message",
      "value": 85,
      "threshold": 80
    }
  ],
  "metadata": {
    "hostname": "server-name",
    "execution_time": "2.5s"
  }
}
```

## State File Management

### Retention Policy (Configurable)
Set via `STATE_RETENTION` environment variable:

```bash
# Default in script
STATE_RETENTION="${STATE_RETENTION:-168}"  # 7 days of hourly runs

# Override for specific script
STATE_RETENTION=336 ./my-script.sh  # 14 days

# In crontab
0 * * * * STATE_RETENTION=720 /path/to/script.sh  # 30 days
```

**Recommended retention by frequency:**
- Hourly runs: `168` (7 days) - default
- Daily runs: `90` (90 days)
- Weekly runs: `52` (1 year)

### File Lifecycle
```
1. Script runs → Creates timestamped.json
2. Updates latest.json symlink
3. Generates markdown inventory
4. Cleans up old files beyond retention
```

### Using lib/state.sh
```bash
source "$REPO_ROOT/lib/state.sh"

# Clean up old state files (respects $STATE_RETENTION)
cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"

# Get most recent state
get_last_state "$STATE_DIR"

# Compare two states (for change detection)
compare_states "$STATE_DIR/1706472000.json" "$STATE_DIR/latest.json"
```

## Shared Library Reference

### lib/notify.sh
```bash
# ALWAYS logs to file + optionally sends push notification
notify_alert "Title" "Message" "priority"
# priority: low, normal, high
# Default: gotify (falls back to file-only if unavailable)
# Logs to: ~/workspace/homelab/logs/cronjob-alerts.log (auto-rotates at 10MB)
```

### lib/logging.sh
```bash
# Initialize logging with rotation
init_logging "script-name"  # Call once at start, sets up log rotation

# Structured logging (writes to file + stderr)
log_info "message"     # Info level
log_warn "message"     # Warning level
log_error "message"    # Error level
log_debug "message"    # Debug (if DEBUG=1)
log_success "message"  # Success level

# Log utilities
get_log_stats          # JSON stats about log file
log_tail 50            # Show last 50 lines
log_search "pattern"   # Search log for pattern
cleanup_old_logs "script" 7  # Delete logs older than 7 days

# Log location: ~/workspace/homelab/logs/<script-name>.log
# Auto-rotates: Max 10MB, keeps current + 1 rotated (.log.1)
```

### lib/json.sh
```bash
# Build JSON objects and arrays
json_object "key1" "value1" "key2" "value2"
json_array "item1" "item2" "item3"
json_escape "string with quotes"
```

### lib/state.sh
```bash
# State file utilities
get_last_state "$STATE_DIR"                    # Get most recent state file
cleanup_old_state "$STATE_DIR" "$max_files"   # Remove old state files
compare_states "$old_file" "$new_file"         # Diff two states
```

## Naming Conventions

### Scripts
- Use kebab-case: `docker-cache.sh`
- Descriptive names: what it monitors
- End with `.sh` extension
- Executable: `chmod +x script.sh`

### Variables
- UPPERCASE for constants: `MAX_RETRIES=3`
- lowercase for local variables: `local host="localhost"`
- Prefix with `readonly` if immutable: `readonly SCRIPT_DIR=...`

### Functions
- Lowercase with underscores: `check_docker_status()`
- Prefix by purpose:
  - `check_*` - validation/testing
  - `get_*` - retrieval
  - `process_*` - data transformation
  - `cleanup_*` - resource cleanup

## Error Handling

All scripts must handle errors gracefully:

```bash
# Command with error handling
if ! result=$(command 2>&1); then
    log_error "Command failed: $result"
    return 1
fi

# Timeout protection for external commands
if ! output=$(timeout 30 ssh host 'command' 2>&1); then
    log_warn "Command timed out or failed"
    return 0  # Non-fatal
fi

# Validate required commands
for cmd in jq curl ssh; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: $cmd"
        exit 1
    fi
done
```

## Testing New Scripts

Before adding to cron:

1. **Dry run:** Execute manually and verify JSON output
2. **Check permissions:** Ensure script is executable
3. **Validate JSON:** `jq . < output.json`
4. **Test notifications:** Verify alerts work
5. **Check cleanup:** Verify trap handlers work (Ctrl+C)

```bash
# Test execution from repository root
./dashboard/linux.sh
./inventory/docker.sh
./monitor/docker-cache.sh

# Validate JSON output (script name without category prefix)
cat ~/memory/bank/linux/*.json | jq .
cat ~/memory/bank/docker/*.json | jq .

# Test with debug logging
DEBUG=1 ./dashboard/linux.sh
```

## Integration with Cron

### Standard Cron Entry
```cron
# Dashboard script - runs every hour
0 * * * * /home/user/workspace/homelab/dashboard/linux.sh

# Inventory script - runs daily at midnight
0 0 * * * /home/user/workspace/homelab/inventory/docker.sh

# Monitor script - runs daily at 2 AM
0 2 * * * /home/user/workspace/homelab/monitor/docker-cache.sh

# Report script - runs weekly on Sunday at midnight
0 0 * * 0 /home/user/workspace/homelab/report/weekly.sh
```

### With Environment Variables
```cron
# With custom thresholds for monitoring scripts
0 * * * * WARN_THRESHOLD=75 CRIT_THRESHOLD=90 /home/user/workspace/homelab/dashboard/linux.sh
```

### Cron Logging
Scripts should NOT use cron output. Use:
- JSON state files for data
- `lib/notify.sh` for alerts
- Redirect cron output: `>/dev/null 2>&1`

## Current Scripts

### Dashboard Scripts (dashboard/)
System monitoring dashboards that collect comprehensive metrics.

#### dashboard/linux.sh
Comprehensive Linux system monitoring (Ubuntu/Debian).
- **Path:** `dashboard/linux.sh`
- **Output:** `~/memory/bank/linux/`
- **Schedule:** Hourly (recommended)
- **Libraries:** Full pattern implementation (`lib/logging.sh`, `lib/notify.sh`, `lib/state.sh`, `lib/json.sh`)
- **Features:** SMART monitoring, hardware inventory, containers, ZFS, network, systemd services
- **Status:** ✅ Fully implemented, production ready

#### dashboard/unraid.sh
Comprehensive Unraid fleet monitoring (multiple servers).
- **Path:** `dashboard/unraid.sh`
- **Output:** `~/memory/bank/unraid/`
- **Schedule:** Hourly (recommended)
- **Libraries:** Full pattern implementation (`lib/logging.sh`, `lib/notify.sh`, `lib/state.sh`, `lib/json.sh`)
- **Features:** Disk temps, errors, storage, containers, VMs, parity check, hardware inventory
- **Status:** ✅ Fully implemented, production ready

#### dashboard/unifi.sh
Monitors UniFi network infrastructure (controllers, devices, clients).
- **Path:** `dashboard/unifi.sh`
- **Output:** `~/memory/bank/unifi/`
- **Schedule:** Hourly (recommended)
- **Libraries:** Full pattern implementation
- **Features:** Device status, client tracking, bandwidth, alerts
- **Status:** ✅ Fully implemented, uses temp files for large JSON data

#### dashboard/overseerr.sh
Monitors Overseerr media request system.
- **Path:** `dashboard/overseerr.sh`
- **Output:** `~/memory/bank/overseerr/`
- **Schedule:** Hourly (recommended)
- **Libraries:** Full pattern implementation
- **Features:** Request tracking, user stats, media availability
- **Status:** ✅ Fully implemented, production ready

### Inventory Scripts (inventory/)
Static inventory collection for infrastructure documentation.

#### inventory/docker.sh
Collects Docker container inventory across all hosts.
- **Path:** `inventory/docker.sh`
- **Output:** `~/memory/bank/docker/`
- **Schedule:** Daily or on-demand
- **Libraries:** `lib/logging.sh`, `lib/notify.sh`, `lib/state.sh`
- **Status:** ✅ Production ready

#### inventory/ssh.sh
Inventories SSH servers and configurations.
- **Path:** `inventory/ssh.sh`
- **Output:** `~/memory/bank/ssh/`
- **Schedule:** Daily or on-demand
- **Libraries:** `lib/logging.sh`, `lib/notify.sh`, `lib/state.sh`
- **Status:** ✅ Production ready

#### inventory/swag.sh
Collects SWAG reverse proxy configurations.
- **Path:** `inventory/swag.sh`
- **Output:** `~/memory/bank/swag/`
- **Schedule:** Daily or on-demand
- **Libraries:** `lib/logging.sh`, `lib/notify.sh`, `lib/state.sh`
- **Status:** ✅ Production ready

#### inventory/tailscale.sh
Inventories Tailscale network members and routes.
- **Path:** `inventory/tailscale.sh`
- **Output:** `~/memory/bank/tailscale/`
- **Schedule:** Daily or on-demand
- **Libraries:** `lib/logging.sh`, `lib/notify.sh`, `lib/state.sh`
- **Status:** ✅ Production ready

### Monitor Scripts (monitor/)
Resource monitoring and anomaly detection with automated actions.

#### monitor/docker-cache.sh
Monitors Docker bloat across multiple hosts. Auto-prunes when threshold exceeded.
- **Path:** `monitor/docker-cache.sh`
- **Output:** `~/memory/bank/docker-cache/`
- **Schedule:** Daily at 2 AM
- **Libraries:** `lib/logging.sh`, `lib/notify.sh`, `lib/state.sh`
- **Features:** Cache size tracking, auto-prune, multi-host support
- **Status:** ✅ Production ready

#### monitor/unifi-anomaly.sh
Detects network anomalies in UniFi infrastructure.
- **Path:** `monitor/unifi-anomaly.sh`
- **Output:** `~/memory/bank/unifi-anomaly/`
- **Schedule:** Hourly (recommended)
- **Libraries:** Full pattern implementation
- **Features:** Anomaly detection, alerting, trend analysis
- **Status:** ✅ Production ready

### Report Scripts (report/)
Aggregated reporting from multiple data sources.

#### report/weekly.sh
Generates weekly summary reports aggregating data from all monitoring scripts.
- **Path:** `report/weekly.sh`
- **Output:** `~/memory/bank/weekly/`
- **Schedule:** Weekly (Sunday at midnight)
- **Libraries:** `lib/logging.sh`, `lib/notify.sh`, `lib/state.sh`
- **Features:** Multi-script aggregation, trend analysis, alert summary
- **Status:** ✅ Production ready

## Migration Checklist

For existing scripts that need updating:

- [ ] Categorize script (move to dashboard/, inventory/, monitor/, or report/)
- [ ] Rename script to remove redundant suffix (if applicable)
- [ ] Update library sourcing to use `REPO_ROOT` pattern
- [ ] Add JSON output to state files
- [ ] Move shared code to `lib/` libraries
- [ ] Add defensive error handling
- [ ] Implement state file cleanup
- [ ] **If modifying a dashboard:** Check and maintain parity with companion dashboard (see Core Principles #4)
- [ ] Update cron jobs with new paths
- [ ] Update CLAUDE.md "Current Scripts" section
- [ ] Update README.md with new patterns
- [ ] Test JSON output schema
- [ ] Validate notification integration

## Adding New Monitoring Scripts

1. **Choose the right category:**
   - `dashboard/` - Comprehensive system monitoring (use SCRIPT_NAME for state dir)
   - `inventory/` - Static infrastructure inventory
   - `monitor/` - Resource monitoring with automated actions
   - `report/` - Aggregated reporting from multiple sources

2. Copy the template above into the chosen directory
3. Name the script descriptively (category provides context):
   - `dashboard/postgres.sh` not `dashboard/postgres-dashboard.sh`
   - `inventory/kubernetes.sh` not `inventory/k8s-inventory.sh`

4. Implement `collect_data()` function
5. Define threshold checks (if applicable)
6. **Check dashboard parity:** If modifying `dashboard/unraid.sh` or `dashboard/linux.sh`, update the other if applicable (see Core Principles #4)
7. Add to this CLAUDE.md under "Current Scripts" in the appropriate category
8. Test manually before adding to cron
9. Document in main README.md

**Example:**
```bash
# Creating a new PostgreSQL dashboard
cd dashboard/
cp ../template.sh postgres.sh  # Use template as base
# Edit postgres.sh, implement data collection
chmod +x postgres.sh
./postgres.sh  # Test execution
# State files created in ~/memory/bank/postgres/
```

## Common Pitfalls & Lessons Learned

### 🚨 Critical: Always Call init_logging()
**REQUIRED** as the first line of `main()`:

```bash
main() {
    init_logging "$SCRIPT_NAME"  # ← DO THIS FIRST!
    log_info "Starting..."
    # ... rest of script
}
```

**Why:** Without `init_logging()`:
- No log rotation (files grow forever)
- `$LOG_FILE` variable not set
- Log functions won't work properly

### ⚖️ Critical: Maintain Dashboard Parity
**REQUIRED:** When adding new data collection to `dashboard/unraid.sh` OR `dashboard/linux.sh`, check if the other dashboard should collect equivalent data.

**Common Mistake:**
```bash
# Adding container health to dashboard/linux.sh
# ❌ Forgetting to add it to dashboard/unraid.sh too!
```

**Correct Approach:**
```bash
# 1. Add feature to one dashboard
# 2. Ask: "Can the other platform collect this data?"
# 3. If yes → Update BOTH dashboards
# 4. Update parity table in CLAUDE.md (see "Core Principles #4")
```

**Why:** Users expect consistent data across all infrastructure dashboards. Missing data from one platform creates blind spots.

**Recent Example (2026-01-25):**
- Added exited container listing to `dashboard/linux.sh`
- ✅ Also added to `dashboard/unraid.sh` immediately
- Result: Both dashboards now show which containers are stopped

### 🐛 Variable Namespace Collisions
**Problem:** Using global variable names in library functions can cause collisions.

**Bad Example:**
```bash
# In lib/notify.sh
notify_alert() {
    LOG_FILE="/path/to/alerts.log"  # ❌ Overwrites global $LOG_FILE
}
```

**Good Example:**
```bash
# In lib/notify.sh
notify_alert() {
    local ALERT_LOG_FILE="/path/to/alerts.log"  # ✅ Local scope
}
```

**Lesson:** Always use `local` for function variables, especially in libraries.

### 🔄 Alert Flattening in jq
**Problem:** When collecting alerts from multiple sources, you may end up with nested arrays.

**Solution:** Use `jq flatten` to combine nested alert arrays:

```bash
# Bad: [[{alert1}, {alert2}], {alert3}]
alerts_json=$(printf '%s\n' "${alerts[@]}" | jq -s '.')

# Good: [{alert1}, {alert2}, {alert3}]
alerts_json=$(printf '%s\n' "${alerts[@]}" | jq -s 'flatten')
```

### 📁 Relative Symlinks
**Problem:** Absolute paths in symlinks break when moving directories.

**Bad:**
```bash
ln -sf "$JSON_FILE" "$LATEST_LINK"  # Absolute path
```

**Good:**
```bash
ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"  # Relative path
```

### 📊 State File Organization
**Evolution:** We tried three patterns before settling on the current one:

1. ❌ **Separate locations** - Split between multiple directories
2. ❌ **Nested structure** - `memory/bank/state/script/` (too deep)
3. ✅ **Flat structure** - `memory/bank/script/` (current, works best)

**Why flat wins:**
- Simple paths
- Easy to find files
- Git-trackable in one place
- Ready for semantic indexing

### 🔔 Notification vs Logging
**Important:** `notify_alert()` ALWAYS logs to file, regardless of notification method.

```bash
# This ALWAYS writes to cronjob-alerts.log
notify_alert "Title" "Message" "priority"

# Even if CRONJOB_NOTIFY_METHOD=none
# Even if Gotify is unavailable
# File logging is the fallback guarantee
```

### 📝 Markdown Output Variable Naming (Code Style Issue)
**Issue:** Inconsistent variable naming between documentation and implementation.

**Documentation standard (CLAUDE.md template):**
```bash
CURRENT_MD="$STATE_DIR/current.md"  # Template shows this
```

**Current implementation in scripts:**
```bash
CURRENT_MD="$STATE_DIR/latest.md"   # Most scripts use this
```

**Status:**
- ⚠️ **Non-breaking inconsistency** - Variable names don't match docs, but actual output is unclear
- 📋 **Code style issue** - Not a functional bug
- 🎯 **Recommendation:** Standardize all scripts to use `CURRENT_MD="$STATE_DIR/current.md"` as documented

**Scripts affected:** (Use `latest.md` instead of `current.md`)
- `dashboard/linux.sh`
- `dashboard/unraid.sh`
- `dashboard/unifi.sh`
- `dashboard/overseerr.sh`
- `inventory/ssh.sh`
- `inventory/swag.sh`
- `inventory/tailscale.sh`
- `inventory/docker.sh`
- `monitor/docker-cache.sh`
- `monitor/unifi-anomaly.sh`
- `report/weekly.sh`

**Future action:**
- When refactoring these scripts, update variable definition to match template
- No urgency - this is cosmetic consistency, not a functional issue

## Best Practices

### Handling Large JSON Data
**Problem:** When processing large JSON datasets (thousands of objects), you may encounter "Argument list too long" errors when passing data through command-line arguments.

**Solution:** Use temporary files to pass data between commands:

```bash
# Bad: Argument list too long error
large_json=$(collect_massive_data)  # 100,000+ chars
result=$(echo "$large_json" | jq '.[] | select(.status == "error")')

# Good: Use temp files for large data
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT  # Clean up on exit

# Write large JSON to temp file
collect_massive_data > "$TEMP_FILE"

# Process with jq from file
result=$(jq '.[] | select(.status == "error")' < "$TEMP_FILE")

# Temp file automatically deleted by trap
```

**When to use:**
- Data > 50KB (safe threshold)
- Processing arrays with 1000+ items
- Multiple jq operations on same dataset
- Aggregating data from multiple sources

**Used in:** `dashboard/unifi.sh`, `report/weekly.sh`

### General Guidelines

- ✅ **DO:** Call `init_logging()` first in `main()`
- ✅ **DO:** Use `local` for all function variables
- ✅ **DO:** Use shared libraries from `lib/`
- ✅ **DO:** Output JSON for all monitoring data
- ✅ **DO:** Include timestamps in all output
- ✅ **DO:** Use timeouts for external commands
- ✅ **DO:** Clean up old state files
- ✅ **DO:** Quote all variables
- ✅ **DO:** Use relative symlinks
- ✅ **DO:** Use temp files for large JSON data (>50KB)
- ❌ **DON'T:** Forget to call `init_logging()`
- ❌ **DON'T:** Use global variables in library functions
- ❌ **DON'T:** Duplicate code across scripts
- ❌ **DON'T:** Use echo for structured data (use JSON)
- ❌ **DON'T:** Skip error handling
- ❌ **DON'T:** Rely on cron output for logging
- ❌ **DON'T:** Hard-code paths or thresholds
- ❌ **DON'T:** Pass large JSON through command-line arguments

## Maintenance

### Weekly Tasks
- Review state file disk usage
- Check for failed cron executions
- Validate notification delivery

### Monthly Tasks
- Archive old state files if needed
- Review and update thresholds
- Update shared libraries if needed

---

**Remember:** Consistency and code reuse make maintenance easier. Follow these patterns for all scripts in this directory.
