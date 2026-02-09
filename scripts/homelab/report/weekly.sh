#!/bin/bash
# Weekly Infrastructure Summary - Aggregated Dashboard Report
# Purpose: Combine data from all infrastructure dashboards into weekly executive summary
# Output: JSON state + Markdown report
# Cron: 0 9 * * 1 (Monday 9am - weekly)

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

# Paths (flat structure in memory/bank)
STATE_DIR="${STATE_DIR:-$HOME/memory/bank/$SCRIPT_NAME}"
CURRENT_MD="$STATE_DIR/latest.md"

# Dashboard data sources (using new simplified names after reorganization)
UNRAID_STATE_DIR="$HOME/memory/bank/unraid"
LINUX_STATE_DIR="$HOME/memory/bank/linux"
UNIFI_STATE_DIR="$HOME/memory/bank/unifi"
UNIFI_DASHBOARD="$HOME/workspace/homelab/skills/unifi/scripts/dashboard.sh"

# Timestamps
TIMESTAMP=$(date +%s)
JSON_FILE="$STATE_DIR/${TIMESTAMP}.json"
LATEST_LINK="$STATE_DIR/latest.json"

# Retention: 52 weeks (1 year of weekly reports)
STATE_RETENTION="${STATE_RETENTION:-52}"

# Optional agent integration
WEEKLY_SUMMARY_SEND_AGENT="${WEEKLY_SUMMARY_SEND_AGENT:-false}"

# Enable Gotify notifications by default (with graceful degradation)
export CRONJOB_NOTIFY_METHOD="${CRONJOB_NOTIFY_METHOD:-gotify}"

# Source shared libraries
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/notify.sh"
source "$REPO_ROOT/lib/state.sh"

# === Cleanup ===
trap 'echo "ERROR: Script failed on line $LINENO" >&2' ERR
trap 'cleanup' EXIT

cleanup() {
    # Clean up any temporary files
    rm -f /tmp/weekly-summary-*.tmp 2>/dev/null || true
}

# === Functions ===

# Calculate week boundaries
get_week_boundaries() {
    # Get Monday of current week
    local today
    today=$(date +%u)  # Day of week (1=Monday, 7=Sunday)
    local days_since_monday=$((today - 1))
    
    WEEK_START=$(date -d "$days_since_monday days ago" +%Y-%m-%d)
    WEEK_END=$(date +%Y-%m-%d)
    WEEK_START_TS=$(date -d "$WEEK_START" +%s)
}

# Read dashboard state with graceful fallback
read_dashboard_state() {
    local state_dir="$1"
    local dashboard_name="$2"
    local latest_file="$state_dir/latest.json"
    
    if [[ ! -f "$latest_file" ]]; then
        log_warn "$dashboard_name: No latest.json found"
        echo "{\"status\": \"missing\", \"error\": \"No data available\"}"
        return 1
    fi
    
    # Check if data is stale (older than 48 hours)
    local file_age
    file_age=$(( $(date +%s) - $(stat -c %Y "$latest_file" 2>/dev/null || echo "0") ))
    local stale_threshold=$((48 * 60 * 60))
    
    local status="success"
    if (( file_age > stale_threshold )); then
        status="stale"
        log_warn "$dashboard_name: Data is $(( file_age / 3600 )) hours old"
    fi
    
    # Read and return the data
    local data
    if data=$(cat "$latest_file" 2>/dev/null); then
        # Use temp file to avoid "Argument list too long" error
        local tmp_data=$(mktemp)
        echo "$data" > "$tmp_data"
        
        jq -n \
            --arg status "$status" \
            --slurpfile data "$tmp_data" \
            --arg age_hours "$(( file_age / 3600 ))" \
            '{status: $status, age_hours: ($age_hours | tonumber), data: $data[0]}'
        
        rm -f "$tmp_data"
    else
        echo "{\"status\": \"error\", \"error\": \"Failed to read file\"}"
        return 1
    fi
}

# Aggregate Unraid data summary
aggregate_unraid_summary() {
    local raw_data="$1"
    
    if [[ "$(echo "$raw_data" | jq -r '.status')" != "success" && "$(echo "$raw_data" | jq -r '.status')" != "stale" ]]; then
        echo "{\"available\": false}"
        return
    fi
    
    local data
    data=$(echo "$raw_data" | jq '.data')
    
    # Extract key metrics
    local server_count healthy_count total_storage_tb used_pct
    local total_containers running_containers total_vms running_vms
    local alert_count
    
    server_count=$(echo "$data" | jq -r '.data.servers | length // 0')
    alert_count=$(echo "$data" | jq -r '.data.alerts | length // 0')
    
    # Calculate totals across all servers
    total_containers=$(echo "$data" | jq -r '[.data.servers[]?.docker.containers[]?] | length // 0')
    running_containers=$(echo "$data" | jq -r '[.data.servers[]?.docker.containers[]? | select(.state == "RUNNING")] | length // 0')
    total_vms=$(echo "$data" | jq -r '[.data.servers[]?.vms.domains[]?] | length // 0')
    running_vms=$(echo "$data" | jq -r '[.data.servers[]?.vms.domains[]? | select(.state == "RUNNING")] | length // 0')
    
    # Storage totals (in KB, convert to TB)
    local total_storage_kb used_storage_kb
    total_storage_kb=$(echo "$data" | jq -r '[.data.servers[]?.array.capacity.kilobytes.total // 0] | add // 0')
    used_storage_kb=$(echo "$data" | jq -r '[.data.servers[]?.array.capacity.kilobytes.used // 0] | add // 0')
    
    total_storage_tb=$(echo "scale=2; $total_storage_kb / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "0")
    if (( total_storage_kb > 0 )); then
        used_pct=$((used_storage_kb * 100 / total_storage_kb))
    else
        used_pct=0
    fi
    
    # Check for disk issues
    local disk_errors hot_disks
    disk_errors=$(echo "$data" | jq -r '[.data.servers[]?.array.disks[]? | select(.numErrors > 0)] | length // 0')
    hot_disks=$(echo "$data" | jq -r '[.data.servers[]?.array.disks[]? | select(.temp > 45)] | length // 0')
    
    jq -n \
        --arg available "true" \
        --argjson server_count "$server_count" \
        --arg total_storage_tb "$total_storage_tb" \
        --argjson used_pct "$used_pct" \
        --argjson total_containers "$total_containers" \
        --argjson running_containers "$running_containers" \
        --argjson total_vms "$total_vms" \
        --argjson running_vms "$running_vms" \
        --argjson alert_count "$alert_count" \
        --argjson disk_errors "$disk_errors" \
        --argjson hot_disks "$hot_disks" \
        '{
            available: true,
            servers: $server_count,
            storage: {
                total_tb: ($total_storage_tb | tonumber),
                used_pct: $used_pct
            },
            docker: {
                total: $total_containers,
                running: $running_containers
            },
            vms: {
                total: $total_vms,
                running: $running_vms
            },
            issues: {
                alerts: $alert_count,
                disk_errors: $disk_errors,
                hot_disks: $hot_disks
            }
        }'
}

# Aggregate Linux data summary
aggregate_linux_summary() {
    local raw_data="$1"
    
    if [[ "$(echo "$raw_data" | jq -r '.status')" != "success" && "$(echo "$raw_data" | jq -r '.status')" != "stale" ]]; then
        echo "{\"available\": false}"
        return
    fi
    
    local data
    data=$(echo "$raw_data" | jq '.data.data')
    
    # Extract key metrics
    local hostname uptime_days cpu_model cpu_cores memory_total_gb memory_pct
    local disk_count container_count systemd_failed zfs_pools
    
    hostname=$(echo "$data" | jq -r '.hostname // "unknown"')
    uptime_days=$(echo "$data" | jq -r '(.uptime_seconds // 0) / 86400 | floor')
    cpu_model=$(echo "$data" | jq -r '.cpu.model // "unknown"')
    cpu_cores=$(echo "$data" | jq -r '.cpu.cores // 0')
    memory_total_gb=$(echo "$data" | jq -r '(.memory.total // 0) / 1024 / 1024 / 1024 | floor')
    memory_pct=$(echo "$data" | jq -r '.memory.percent // 0 | floor')
    disk_count=$(echo "$data" | jq -r '.disks | length // 0')
    container_count=$(echo "$data" | jq -r '.docker.containers | length // 0')
    systemd_failed=$(echo "$data" | jq -r '.systemd.failed_units | length // 0')
    zfs_pools=$(echo "$data" | jq -r '.zfs.pools | length // 0')
    
    # Check for issues
    local high_disk_usage docker_unhealthy
    high_disk_usage=$(echo "$data" | jq -r '[.disks[]? | select(.percent > 85)] | length // 0')
    docker_unhealthy=$(echo "$data" | jq -r '[.docker.containers[]? | select(.state != "running")] | length // 0')
    
    jq -n \
        --arg hostname "$hostname" \
        --argjson uptime_days "$uptime_days" \
        --arg cpu_model "$cpu_model" \
        --argjson cpu_cores "$cpu_cores" \
        --argjson memory_total_gb "$memory_total_gb" \
        --argjson memory_pct "$memory_pct" \
        --argjson disk_count "$disk_count" \
        --argjson container_count "$container_count" \
        --argjson systemd_failed "$systemd_failed" \
        --argjson zfs_pools "$zfs_pools" \
        --argjson high_disk_usage "$high_disk_usage" \
        --argjson docker_unhealthy "$docker_unhealthy" \
        '{
            available: true,
            hostname: $hostname,
            uptime_days: $uptime_days,
            cpu: {
                model: $cpu_model,
                cores: $cpu_cores
            },
            memory: {
                total_gb: $memory_total_gb,
                percent: $memory_pct
            },
            storage: {
                disks: $disk_count,
                zfs_pools: $zfs_pools
            },
            docker: {
                containers: $container_count,
                unhealthy: $docker_unhealthy
            },
            systemd: {
                failed_units: $systemd_failed
            },
            issues: {
                high_disk_usage: $high_disk_usage,
                docker_unhealthy: $docker_unhealthy,
                systemd_failed: $systemd_failed
            }
        }'
}

# Get UniFi summary (from running dashboard or reading inventory)
get_unifi_summary() {
    # Try to get JSON output from dashboard
    if [[ -x "$UNIFI_DASHBOARD" ]]; then
        local unifi_json
        if unifi_json=$("$UNIFI_DASHBOARD" json 2>/dev/null); then
            # Check for auth errors first
            local devices_error clients_error
            devices_error=$(echo "$unifi_json" | jq -r '.devices.error.message // empty' 2>/dev/null)
            clients_error=$(echo "$unifi_json" | jq -r '.clients.error.message // empty' 2>/dev/null)
            
            if [[ -n "$devices_error" || -n "$clients_error" ]]; then
                log_warn "UniFi: API returned error - $devices_error"
                # Fall through to markdown parsing
            else
                # Extract key metrics from JSON (handle both .data array and direct array)
                local device_count client_count
                
                device_count=$(echo "$unifi_json" | jq -r '(.devices.data // .devices) | if type == "array" then length else 0 end' 2>/dev/null || echo "0")
                client_count=$(echo "$unifi_json" | jq -r '(.clients.data // .clients) | if type == "array" then length else 0 end' 2>/dev/null || echo "0")
                
                if (( device_count > 0 || client_count > 0 )); then
                    jq -n \
                        --argjson device_count "$device_count" \
                        --argjson client_count "$client_count" \
                        '{
                            available: true,
                            source: "dashboard_json",
                            devices: $device_count,
                            clients: $client_count
                        }'
                    return
                fi
            fi
        fi
    fi
    
    # Fallback: Parse markdown inventory (more reliable when API is down)
    if [[ -f "$UNIFI_INVENTORY" ]]; then
        log_info "UniFi: Parsing markdown inventory"
        
        # Extract counts from markdown (look for summary sections)
        local device_count client_count
        
        # Look for device count patterns like "## Devices (15)"
        device_count=$(grep -oP '##.*Devices.*\((\d+)\)' "$UNIFI_INVENTORY" 2>/dev/null | grep -oP '\d+' | head -1 | tr -d '[:space:]' || echo "")
        # Or count individual device entries
        if [[ -z "$device_count" || "$device_count" == "0" ]]; then
            device_count=$(grep -cE '^\| (UAP|USW|UDM|USG|U6)' "$UNIFI_INVENTORY" 2>/dev/null | tr -d '[:space:]' || echo "0")
        fi
        [[ -z "$device_count" ]] && device_count=0
        
        # Look for client count patterns
        client_count=$(grep -oP '##.*Clients.*\((\d+)\)' "$UNIFI_INVENTORY" 2>/dev/null | grep -oP '\d+' | head -1 || echo "")
        # Or count table rows
        if [[ -z "$client_count" || "$client_count" == "0" ]]; then
            client_count=$(grep -cE '^\|.*\|.*\|.*\|' "$UNIFI_INVENTORY" 2>/dev/null | tr -d '[:space:]' || echo "0")
            # Subtract header rows (rough estimate)
            [[ -z "$client_count" ]] && client_count=0
            if (( client_count > 10 )); then
                client_count=$((client_count - 5))
            fi
        fi
        
        jq -n \
            --arg device_count "${device_count:-0}" \
            --arg client_count "${client_count:-0}" \
            '{
                available: true,
                source: "markdown_inventory",
                devices: ($device_count | tonumber),
                clients: ($client_count | tonumber)
            }'
        return
    fi
    
    echo '{"available": false, "error": "No UniFi data source found"}'
}

# Generate highlights based on collected data
generate_highlights() {
    local unraid_summary="$1"
    local linux_summary="$2"
    local unifi_summary="$3"
    
    local -a highlights=()
    
    # Unraid highlights
    if [[ "$(echo "$unraid_summary" | jq -r '.available')" == "true" ]]; then
        local servers storage_tb containers alerts
        servers=$(echo "$unraid_summary" | jq -r '.servers // 0')
        storage_tb=$(echo "$unraid_summary" | jq -r '.storage.total_tb // 0')
        containers=$(echo "$unraid_summary" | jq -r '.docker.running // 0')
        alerts=$(echo "$unraid_summary" | jq -r '.issues.alerts // 0')
        
        highlights+=("$servers Unraid server(s) with ${storage_tb}TB storage")
        highlights+=("$containers running Docker containers across Unraid fleet")
        
        if (( alerts > 0 )); then
            highlights+=("⚠️ $alerts Unraid alert(s) require attention")
        fi
    fi
    
    # Linux highlights
    if [[ "$(echo "$linux_summary" | jq -r '.available')" == "true" ]]; then
        local hostname uptime containers failed
        hostname=$(echo "$linux_summary" | jq -r '.hostname // "unknown"')
        uptime=$(echo "$linux_summary" | jq -r '.uptime_days // 0')
        containers=$(echo "$linux_summary" | jq -r '.docker.containers // 0')
        failed=$(echo "$linux_summary" | jq -r '.systemd.failed_units // 0')
        
        highlights+=("$hostname uptime: $uptime days")
        highlights+=("$containers Docker containers on Linux host")
        
        if (( failed > 0 )); then
            highlights+=("⚠️ $failed failed systemd unit(s)")
        fi
    fi
    
    # UniFi highlights
    if [[ "$(echo "$unifi_summary" | jq -r '.available')" == "true" ]]; then
        local devices clients
        devices=$(echo "$unifi_summary" | jq -r '.devices // 0')
        clients=$(echo "$unifi_summary" | jq -r '.clients // 0')
        
        # Only add highlights if we have actual data
        if [[ "$devices" != "null" ]] && (( devices > 0 )); then
            highlights+=("$devices UniFi devices managed")
        fi
        if [[ "$clients" != "null" ]] && (( clients > 0 )); then
            highlights+=("$clients clients on network")
        fi
    fi
    
    # Output as JSON array
    printf '%s\n' "${highlights[@]}" | jq -R . | jq -s .
}

# Generate markdown report
generate_markdown_report() {
    local unraid_summary="$1"
    local linux_summary="$2"
    local unifi_summary="$3"
    local highlights="$4"
    
    cat <<EOF
# Weekly Infrastructure Summary
**Week:** $WEEK_START to $WEEK_END
**Generated:** $(date '+%Y-%m-%d %H:%M %Z')

---

## 📋 Executive Summary

EOF
    
    # Print highlights
    echo "$highlights" | jq -r '.[] | "- \(.)"'
    echo ""
    
    # Unraid Section
    cat <<EOF

---

## 🖥️ Unraid Fleet

EOF
    
    if [[ "$(echo "$unraid_summary" | jq -r '.available')" == "true" ]]; then
        local servers storage_tb used_pct containers vms alerts disk_errors
        servers=$(echo "$unraid_summary" | jq -r '.servers // 0')
        storage_tb=$(echo "$unraid_summary" | jq -r '.storage.total_tb // 0')
        used_pct=$(echo "$unraid_summary" | jq -r '.storage.used_pct // 0')
        containers=$(echo "$unraid_summary" | jq -r '.docker.running // 0')
        total_containers=$(echo "$unraid_summary" | jq -r '.docker.total // 0')
        vms=$(echo "$unraid_summary" | jq -r '.vms.running // 0')
        total_vms=$(echo "$unraid_summary" | jq -r '.vms.total // 0')
        alerts=$(echo "$unraid_summary" | jq -r '.issues.alerts // 0')
        disk_errors=$(echo "$unraid_summary" | jq -r '.issues.disk_errors // 0')
        hot_disks=$(echo "$unraid_summary" | jq -r '.issues.hot_disks // 0')
        
        cat <<EOF
| Metric | Value |
|--------|-------|
| Servers | $servers |
| Total Storage | ${storage_tb}TB |
| Storage Used | ${used_pct}% |
| Docker Containers | $containers / $total_containers running |
| Virtual Machines | $vms / $total_vms running |
| Active Alerts | $alerts |
| Disk Errors | $disk_errors |
| Hot Disks (>45°C) | $hot_disks |

EOF
        
        if (( alerts > 0 || disk_errors > 0 || hot_disks > 0 )); then
            echo "### ⚠️ Issues Requiring Attention"
            (( alerts > 0 )) && echo "- $alerts active alert(s)"
            (( disk_errors > 0 )) && echo "- $disk_errors disk(s) with errors"
            (( hot_disks > 0 )) && echo "- $hot_disks disk(s) running hot"
            echo ""
        fi
    else
        echo "*Unraid data not available*"
        echo ""
    fi
    
    # Linux Section
    cat <<EOF

---

## 🐧 Linux Host

EOF
    
    if [[ "$(echo "$linux_summary" | jq -r '.available')" == "true" ]]; then
        local hostname uptime cpu_model cores mem_gb mem_pct disks containers failed
        hostname=$(echo "$linux_summary" | jq -r '.hostname // "unknown"')
        uptime=$(echo "$linux_summary" | jq -r '.uptime_days // 0')
        cpu_model=$(echo "$linux_summary" | jq -r '.cpu.model // "unknown"')
        cores=$(echo "$linux_summary" | jq -r '.cpu.cores // 0')
        mem_gb=$(echo "$linux_summary" | jq -r '.memory.total_gb // 0')
        mem_pct=$(echo "$linux_summary" | jq -r '.memory.percent // 0')
        disks=$(echo "$linux_summary" | jq -r '.storage.disks // 0')
        zfs=$(echo "$linux_summary" | jq -r '.storage.zfs_pools // 0')
        containers=$(echo "$linux_summary" | jq -r '.docker.containers // 0')
        failed=$(echo "$linux_summary" | jq -r '.systemd.failed_units // 0')
        high_disk=$(echo "$linux_summary" | jq -r '.issues.high_disk_usage // 0')
        
        cat <<EOF
| Metric | Value |
|--------|-------|
| Hostname | $hostname |
| Uptime | $uptime days |
| CPU | $cpu_model ($cores cores) |
| Memory | ${mem_gb}GB (${mem_pct}% used) |
| Disks | $disks |
| ZFS Pools | $zfs |
| Docker Containers | $containers |
| Failed Systemd Units | $failed |

EOF
        
        if (( failed > 0 || high_disk > 0 )); then
            echo "### ⚠️ Issues Requiring Attention"
            (( failed > 0 )) && echo "- $failed failed systemd unit(s)"
            (( high_disk > 0 )) && echo "- $high_disk disk(s) over 85% usage"
            echo ""
        fi
    else
        echo "*Linux host data not available*"
        echo ""
    fi
    
    # UniFi Section
    cat <<EOF

---

## 📡 UniFi Network

EOF
    
    if [[ "$(echo "$unifi_summary" | jq -r '.available')" == "true" ]]; then
        local source devices clients
        source=$(echo "$unifi_summary" | jq -r '.source // "unknown"')
        devices=$(echo "$unifi_summary" | jq -r '.devices // "N/A"')
        clients=$(echo "$unifi_summary" | jq -r '.clients // "N/A"')
        
        cat <<EOF
| Metric | Value |
|--------|-------|
| Data Source | $source |
| Managed Devices | $devices |
| Network Clients | $clients |

*Note: For detailed UniFi metrics, see \`memory/bank/unifi-inventory.md\`*

EOF
    else
        echo "*UniFi data not available*"
        echo ""
    fi
    
    # Recommendations
    cat <<EOF

---

## 💡 Recommendations

EOF
    
    local has_recommendations=false
    
    # Check for issues across all summaries
    if [[ "$(echo "$unraid_summary" | jq -r '.available')" == "true" ]]; then
        local used_pct
        used_pct=$(echo "$unraid_summary" | jq -r '.storage.used_pct // 0')
        
        if (( used_pct > 80 )); then
            echo "- 📦 **Storage capacity**: Unraid fleet at ${used_pct}% - consider expanding or archiving old data"
            has_recommendations=true
        fi
        
        if (( $(echo "$unraid_summary" | jq -r '.issues.disk_errors // 0') > 0 )); then
            echo "- 🔴 **Disk health**: Replace disks with errors ASAP"
            has_recommendations=true
        fi
    fi
    
    if [[ "$(echo "$linux_summary" | jq -r '.available')" == "true" ]]; then
        if (( $(echo "$linux_summary" | jq -r '.systemd.failed_units // 0') > 0 )); then
            echo "- 🔧 **Systemd units**: Investigate and fix failed services"
            has_recommendations=true
        fi
    fi
    
    if [[ "$has_recommendations" != "true" ]]; then
        echo "✅ **No immediate actions required** - All systems operating normally."
    fi
    
    cat <<EOF

---

*Report generated by system-summary-weekly.sh*
*Data sources: unraid-dashboard, linux-dashboard, unifi-dashboard*
EOF
}

# Collect all alerts from summaries
collect_alerts() {
    local unraid_summary="$1"
    local linux_summary="$2"
    
    local -a alerts=()
    
    # Unraid alerts
    if [[ "$(echo "$unraid_summary" | jq -r '.available')" == "true" ]]; then
        local disk_errors hot_disks storage_pct
        disk_errors=$(echo "$unraid_summary" | jq -r '.issues.disk_errors // 0')
        hot_disks=$(echo "$unraid_summary" | jq -r '.issues.hot_disks // 0')
        storage_pct=$(echo "$unraid_summary" | jq -r '.storage.used_pct // 0')
        
        (( disk_errors > 0 )) && alerts+=("{\"source\": \"unraid\", \"severity\": \"critical\", \"message\": \"$disk_errors disk(s) with errors\"}")
        (( hot_disks > 0 )) && alerts+=("{\"source\": \"unraid\", \"severity\": \"warning\", \"message\": \"$hot_disks disk(s) over 45°C\"}")
        (( storage_pct > 90 )) && alerts+=("{\"source\": \"unraid\", \"severity\": \"warning\", \"message\": \"Storage at ${storage_pct}%\"}")
    fi
    
    # Linux alerts
    if [[ "$(echo "$linux_summary" | jq -r '.available')" == "true" ]]; then
        local failed_units mem_pct
        failed_units=$(echo "$linux_summary" | jq -r '.systemd.failed_units // 0')
        mem_pct=$(echo "$linux_summary" | jq -r '.memory.percent // 0')
        
        (( failed_units > 0 )) && alerts+=("{\"source\": \"linux\", \"severity\": \"warning\", \"message\": \"$failed_units failed systemd unit(s)\"}")
        (( mem_pct > 90 )) && alerts+=("{\"source\": \"linux\", \"severity\": \"warning\", \"message\": \"Memory usage at ${mem_pct}%\"}")
    fi
    
    if (( ${#alerts[@]} > 0 )); then
        printf '%s\n' "${alerts[@]}" | jq -s .
    else
        echo "[]"
    fi
}

# === Main Script ===

main() {
    # Initialize logging (enables log rotation)
    init_logging "$SCRIPT_NAME"

    log_info "Starting $SCRIPT_NAME"
    
    # Ensure state directory exists
    ensure_state_dir "$STATE_DIR"
    
    # Calculate week boundaries
    get_week_boundaries
    log_info "Generating summary for week: $WEEK_START to $WEEK_END"
    
    # Collect data from each dashboard
    log_info "Reading Unraid dashboard state..."
    local unraid_raw
    unraid_raw=$(read_dashboard_state "$UNRAID_STATE_DIR" "Unraid")
    
    log_info "Reading Linux dashboard state..."
    local linux_raw
    linux_raw=$(read_dashboard_state "$LINUX_STATE_DIR" "Linux")
    
    log_info "Getting UniFi summary..."
    local unifi_raw
    unifi_raw=$(get_unifi_summary)
    
    # Aggregate summaries
    log_info "Aggregating dashboard data..."
    local unraid_summary linux_summary unifi_summary
    unraid_summary=$(aggregate_unraid_summary "$unraid_raw")
    linux_summary=$(aggregate_linux_summary "$linux_raw")
    unifi_summary="$unifi_raw"  # Already summarized
    
    # Generate highlights
    local highlights
    highlights=$(generate_highlights "$unraid_summary" "$linux_summary" "$unifi_summary")
    
    # Collect alerts
    local alerts
    alerts=$(collect_alerts "$unraid_summary" "$linux_summary")
    
    # Build final JSON
    log_info "Saving JSON state..."
    jq -n \
        --argjson timestamp "$TIMESTAMP" \
        --arg script "$SCRIPT_NAME" \
        --arg week_start "$WEEK_START" \
        --arg week_end "$WEEK_END" \
        --argjson unraid "$unraid_summary" \
        --argjson linux "$linux_summary" \
        --argjson unifi "$unifi_summary" \
        --argjson highlights "$highlights" \
        --argjson alerts "$alerts" \
        --arg hostname "$(hostname)" \
        --argjson exec_time "$(($(date +%s) - TIMESTAMP))" \
        '{
            timestamp: $timestamp,
            script: $script,
            data: {
                week_start: $week_start,
                week_end: $week_end,
                dashboards: {
                    unraid: $unraid,
                    linux: $linux,
                    unifi: $unifi
                },
                highlights: $highlights
            },
            alerts: $alerts,
            metadata: {
                hostname: $hostname,
                execution_time: "\($exec_time)s"
            }
        }' > "$JSON_FILE"
    
    log_info "JSON state saved to: $JSON_FILE"
    
    # Update 'latest' symlink
    ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"
    
    # Generate markdown report
    log_info "Generating markdown report..."
    generate_markdown_report "$unraid_summary" "$linux_summary" "$unifi_summary" "$highlights" > "$CURRENT_MD"
    log_info "Markdown report saved to: $CURRENT_MD"
    
    # Clean up old state files (keep 52 weeks)
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"
    
    # Check for critical alerts
    local alert_count
    alert_count=$(echo "$alerts" | jq 'length')
    
    if (( alert_count > 0 )); then
        local alert_summary
        alert_summary=$(echo "$alerts" | jq -r '.[] | "[\(.severity | ascii_upcase)] \(.source): \(.message)"')
        
        notify_alert "Weekly Infrastructure Summary - $alert_count Issue(s)" "$alert_summary" "normal"
        log_warn "$alert_count alerts in weekly summary"
    fi
    
    # Optional: Send to agent for analysis
    if [[ "$WEEKLY_SUMMARY_SEND_AGENT" == "true" ]]; then
        log_info "Agent integration enabled - sending summary..."
        # This would use the message tool or similar to send to the agent
        # For now, just log that it's enabled
        log_info "Summary available at: $CURRENT_MD"
    fi
    
    log_success "$SCRIPT_NAME completed successfully"
    log_info "Highlights: $(echo "$highlights" | jq -r '. | length') items"
    log_info "Alerts: $alert_count"
}

# Run main function
main "$@"
