#!/bin/bash
# UniFi Network Dashboard - Comprehensive Network Monitoring
# Purpose: Monitor UniFi network health, devices, clients, alerts, and DPI data
# Output: JSON state + Markdown inventory
# Cron: 0 * * * * (hourly)

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

# Shared directory with other UniFi monitoring scripts
STATE_DIR="${STATE_DIR:-$HOME/memory/bank/unifi}"
FILE_PREFIX="dashboard"  # Prefix to avoid collisions with unifi-anomaly-detector
UNIFI_API_SCRIPT="${UNIFI_API_SCRIPT:-$HOME/workspace/homelab/skills/unifi/scripts/unifi-api.sh}"

# Timestamps
TIMESTAMP=$(date +%s)
JSON_FILE="$STATE_DIR/${FILE_PREFIX}-${TIMESTAMP}.json"
LATEST_LINK="$STATE_DIR/${FILE_PREFIX}-latest.json"
CURRENT_MD="$STATE_DIR/${FILE_PREFIX}-latest.md"

# Retention (configurable via environment)
STATE_RETENTION="${STATE_RETENTION:-168}"  # Keep last 168 files (7 days hourly)

# Enable Gotify notifications by default (with graceful degradation)
export CRONJOB_NOTIFY_METHOD="${CRONJOB_NOTIFY_METHOD:-gotify}"

# Source shared libraries
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/notify.sh"
source "$REPO_ROOT/lib/state.sh"

# Source UniFi API helper
if [[ ! -f "$UNIFI_API_SCRIPT" ]]; then
    echo "ERROR: UniFi API script not found: $UNIFI_API_SCRIPT" >&2
    exit 1
fi
source "$UNIFI_API_SCRIPT"

# Thresholds (configurable via environment)
CLIENT_SIGNAL_WARN="${CLIENT_SIGNAL_WARN:--70}"   # Warn if signal < -70 dBm
CLIENT_SIGNAL_CRIT="${CLIENT_SIGNAL_CRIT:--80}"   # Critical if signal < -80 dBm
DEVICE_UPTIME_WARN="${DEVICE_UPTIME_WARN:-86400}" # Warn if uptime < 1 day (unexpected reboot)

# === Cleanup ===
trap 'echo "ERROR: Script failed on line $LINENO" >&2' ERR
trap 'cleanup' EXIT

cleanup() {
    # Clean up any temporary files
    rm -f /tmp/unifi-dashboard-*.json 2>/dev/null || true
    # Clean up cookie file if it was created
    [[ -n "${UNIFI_COOKIE_FILE:-}" ]] && rm -f "$UNIFI_COOKIE_FILE" 2>/dev/null || true
}

# === Helper Functions ===

# Format bytes to human readable
format_bytes() {
    local bytes="$1"
    if (( bytes >= 1099511627776 )); then
        echo "$(echo "scale=2; $bytes / 1099511627776" | bc)TB"
    elif (( bytes >= 1073741824 )); then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc)GB"
    elif (( bytes >= 1048576 )); then
        echo "$(echo "scale=2; $bytes / 1048576" | bc)MB"
    elif (( bytes >= 1024 )); then
        echo "$(echo "scale=2; $bytes / 1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# Format uptime seconds to human readable
format_uptime() {
    local seconds="$1"
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))
    
    if (( days > 0 )); then
        echo "${days}d ${hours}h"
    elif (( hours > 0 )); then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

# Safe API call with fallback
safe_unifi_get() {
    local endpoint="$1"
    local fallback="${2:-{\"data\":[]}}"
    
    local response
    if response=$(unifi_get "$endpoint" 2>/dev/null); then
        # Validate JSON
        if echo "$response" | jq -e '.' >/dev/null 2>&1; then
            echo "$response"
        else
            log_warn "Invalid JSON from $endpoint"
            echo "$fallback"
        fi
    else
        log_warn "API call failed for $endpoint"
        echo "$fallback"
    fi
}

# === Data Collection Functions ===

# Collect health status
collect_health() {
    log_info "Collecting health status..."
    local response
    response=$(safe_unifi_get "stat/health")
    echo "$response" | jq '.data // []'
}

# Collect device information
collect_devices() {
    log_info "Collecting device information..."
    local response
    response=$(safe_unifi_get "stat/device")
    echo "$response" | jq '.data // []'
}

# Collect active clients
collect_clients() {
    log_info "Collecting active clients..."
    local response
    response=$(safe_unifi_get "stat/sta")
    echo "$response" | jq '.data // []'
}

# Collect alarms
collect_alarms() {
    log_info "Collecting alarms..."
    local response
    response=$(safe_unifi_get "stat/alarm")
    echo "$response" | jq '.data // []'
}

# Collect DPI data
collect_dpi() {
    log_info "Collecting DPI data..."
    local response
    response=$(safe_unifi_get "stat/sitedpi")
    echo "$response" | jq '.data // []'
}

# Collect rogue APs
collect_rogueap() {
    log_info "Collecting rogue AP data..."
    local response
    response=$(safe_unifi_get "stat/rogueap")
    echo "$response" | jq '.data // []'
}

# Collect WLAN configurations
collect_wlans() {
    log_info "Collecting WLAN configurations..."
    local response
    response=$(safe_unifi_get "rest/wlanconf")
    echo "$response" | jq '.data // []'
}

# Collect network configurations
collect_networks() {
    log_info "Collecting network configurations..."
    local response
    response=$(safe_unifi_get "rest/networkconf")
    echo "$response" | jq '.data // []'
}

# === Alert Generation ===

# Check health and generate alerts
check_health_alerts() {
    local health="$1"
    local -a alerts=()
    
    while IFS= read -r subsystem; do
        [[ -z "$subsystem" ]] && continue
        
        local name status
        name=$(echo "$subsystem" | jq -r '.subsystem // "unknown"')
        status=$(echo "$subsystem" | jq -r '.status // "unknown"')
        
        if [[ "$status" != "ok" ]]; then
            alerts+=("{\"severity\": \"warning\", \"type\": \"health\", \"message\": \"$name subsystem: $status\"}")
        fi
    done < <(echo "$health" | jq -c '.[]')
    
    printf '%s\n' "${alerts[@]}"
}

# Check devices and generate alerts
check_device_alerts() {
    local devices="$1"
    local -a alerts=()
    
    while IFS= read -r device; do
        [[ -z "$device" ]] && continue
        
        local name state uptime adopted
        name=$(echo "$device" | jq -r '.name // .mac // "unknown"')
        state=$(echo "$device" | jq -r '.state // 0')
        uptime=$(echo "$device" | jq -r '.uptime // 0')
        adopted=$(echo "$device" | jq -r '.adopted // false')
        
        # Check for offline devices (state != 1 means not connected)
        if [[ "$adopted" == "true" ]] && [[ "$state" != "1" ]]; then
            alerts+=("{\"severity\": \"critical\", \"type\": \"device\", \"message\": \"Device '$name' is offline\"}")
        fi
        
        # Check for recent reboots
        if [[ "$uptime" != "null" ]] && (( uptime > 0 && uptime < DEVICE_UPTIME_WARN )); then
            local uptime_str
            uptime_str=$(format_uptime "$uptime")
            alerts+=("{\"severity\": \"warning\", \"type\": \"device\", \"message\": \"Device '$name' recently rebooted (uptime: $uptime_str)\"}")
        fi
    done < <(echo "$devices" | jq -c '.[]')
    
    printf '%s\n' "${alerts[@]}"
}

# Check clients and generate alerts
check_client_alerts() {
    local clients="$1"
    local -a alerts=()
    
    while IFS= read -r client; do
        [[ -z "$client" ]] && continue
        
        local name signal is_wired
        name=$(echo "$client" | jq -r '.hostname // .name // .mac // "unknown"')
        signal=$(echo "$client" | jq -r '.rssi // .signal // 0')
        is_wired=$(echo "$client" | jq -r '.is_wired // false')
        
        # Only check wireless clients
        if [[ "$is_wired" == "false" ]] && [[ "$signal" != "null" ]] && [[ "$signal" != "0" ]]; then
            # RSSI is typically negative, so we compare with our thresholds
            if (( signal < CLIENT_SIGNAL_CRIT )); then
                alerts+=("{\"severity\": \"critical\", \"type\": \"client\", \"message\": \"Client '$name' has critical signal: ${signal} dBm\"}")
            elif (( signal < CLIENT_SIGNAL_WARN )); then
                alerts+=("{\"severity\": \"warning\", \"type\": \"client\", \"message\": \"Client '$name' has poor signal: ${signal} dBm\"}")
            fi
        fi
    done < <(echo "$clients" | jq -c '.[]')
    
    printf '%s\n' "${alerts[@]}"
}

# Check alarms and generate alerts
check_alarm_alerts() {
    local alarms="$1"
    local -a alerts=()
    
    # Only alert on recent alarms (last 24 hours)
    local cutoff=$((TIMESTAMP - 86400))
    
    while IFS= read -r alarm; do
        [[ -z "$alarm" ]] && continue
        
        local msg time archived
        msg=$(echo "$alarm" | jq -r '.msg // .key // "unknown alarm"')
        time=$(echo "$alarm" | jq -r '.time // .datetime // 0')
        archived=$(echo "$alarm" | jq -r '.archived // false')
        
        # Skip archived alarms
        [[ "$archived" == "true" ]] && continue
        
        # Convert time to epoch if needed (handle milliseconds)
        if [[ "$time" =~ ^[0-9]{13}$ ]]; then
            time=$((time / 1000))
        fi
        
        if (( time > cutoff )); then
            alerts+=("{\"severity\": \"warning\", \"type\": \"alarm\", \"message\": \"$msg\"}")
        fi
    done < <(echo "$alarms" | jq -c '.[]')
    
    printf '%s\n' "${alerts[@]}"
}

# Check rogue APs and generate alerts
check_rogueap_alerts() {
    local rogueaps="$1"
    local -a alerts=()
    
    local rogue_count
    rogue_count=$(echo "$rogueaps" | jq 'length')
    
    if (( rogue_count > 10 )); then
        alerts+=("{\"severity\": \"info\", \"type\": \"rogueap\", \"message\": \"$rogue_count neighboring APs detected\"}")
    fi
    
    printf '%s\n' "${alerts[@]}"
}

# === Main Data Collection ===

collect_all_data() {
    local -a all_alerts=()
    
    # Login to UniFi (creates cookie for subsequent calls)
    log_info "Authenticating with UniFi controller..."
    if ! unifi_login; then
        log_error "Failed to authenticate with UniFi controller"
        echo '{"error": "Authentication failed"}'
        return 1
    fi
    
    # Check if Network application is available
    log_info "Checking UniFi Network application status..."
    if ! unifi_check_status; then
        log_error "UniFi Network unavailable: ${UNIFI_STATUS_MESSAGE:-Unknown}"
        echo "{\"error\": \"UniFi Network unavailable: ${UNIFI_STATUS_MESSAGE:-Unknown}\"}"
        return 1
    fi
    log_info "UniFi Network status: ${UNIFI_STATUS_MESSAGE:-OK}"
    
    # Collect all data
    local health devices clients alarms dpi rogueap wlans networks
    
    health=$(collect_health)
    devices=$(collect_devices)
    clients=$(collect_clients)
    alarms=$(collect_alarms)
    dpi=$(collect_dpi)
    rogueap=$(collect_rogueap)
    wlans=$(collect_wlans)
    networks=$(collect_networks)
    
    # Generate alerts
    log_info "Checking for alerts..."
    
    while IFS= read -r alert; do
        [[ -n "$alert" ]] && all_alerts+=("$alert")
    done < <(check_health_alerts "$health")
    
    while IFS= read -r alert; do
        [[ -n "$alert" ]] && all_alerts+=("$alert")
    done < <(check_device_alerts "$devices")
    
    while IFS= read -r alert; do
        [[ -n "$alert" ]] && all_alerts+=("$alert")
    done < <(check_client_alerts "$clients")
    
    while IFS= read -r alert; do
        [[ -n "$alert" ]] && all_alerts+=("$alert")
    done < <(check_alarm_alerts "$alarms")
    
    while IFS= read -r alert; do
        [[ -n "$alert" ]] && all_alerts+=("$alert")
    done < <(check_rogueap_alerts "$rogueap")
    
    # Build alerts JSON
    local alerts_json
    if (( ${#all_alerts[@]} > 0 )); then
        alerts_json=$(printf '%s\n' "${all_alerts[@]}" | jq -s '.')
    else
        alerts_json="[]"
    fi
    
    # Use temp files to avoid "Argument list too long" error
    local tmp_health=$(mktemp)
    local tmp_devices=$(mktemp)
    local tmp_clients=$(mktemp)
    local tmp_alarms=$(mktemp)
    local tmp_dpi=$(mktemp)
    local tmp_rogueap=$(mktemp)
    local tmp_wlans=$(mktemp)
    local tmp_networks=$(mktemp)
    local tmp_alerts=$(mktemp)
    
    echo "$health" > "$tmp_health"
    echo "$devices" > "$tmp_devices"
    echo "$clients" > "$tmp_clients"
    echo "$alarms" > "$tmp_alarms"
    echo "$dpi" > "$tmp_dpi"
    echo "$rogueap" > "$tmp_rogueap"
    echo "$wlans" > "$tmp_wlans"
    echo "$networks" > "$tmp_networks"
    echo "$alerts_json" > "$tmp_alerts"
    
    # Build final data structure
    jq -n \
        --slurpfile health "$tmp_health" \
        --slurpfile devices "$tmp_devices" \
        --slurpfile clients "$tmp_clients" \
        --slurpfile alarms "$tmp_alarms" \
        --slurpfile dpi "$tmp_dpi" \
        --slurpfile rogueap "$tmp_rogueap" \
        --slurpfile wlans "$tmp_wlans" \
        --slurpfile networks "$tmp_networks" \
        --slurpfile alerts "$tmp_alerts" \
        '{
            data: {
                health: $health[0],
                devices: $devices[0],
                clients: $clients[0],
                alarms: $alarms[0],
                dpi: $dpi[0],
                rogueap: $rogueap[0],
                wlans: $wlans[0],
                networks: $networks[0]
            },
            alerts: $alerts[0]
        }'
    
    # Cleanup temp files
    rm -f "$tmp_health" "$tmp_devices" "$tmp_clients" "$tmp_alarms" "$tmp_dpi" "$tmp_rogueap" "$tmp_wlans" "$tmp_networks" "$tmp_alerts"
}

# === Markdown Generation ===

generate_markdown_inventory() {
    local json_data="$1"
    
    cat <<EOF
# UniFi Network Dashboard
Generated: $(date)

EOF
    
    # Health Status
    cat <<EOF
## Health Status
EOF
    local health_count
    health_count=$(echo "$json_data" | jq '[.data.health[]?] | length')
    
    if (( health_count > 0 )); then
        echo "$json_data" | jq -r '.data.health[]? | 
            "- **\(.subsystem | ascii_upcase)**: \(if .status == "ok" then "✅ OK" else "⚠️  \(.status)" end)\(if .num_user then " | \(.num_user) users" else "" end)\(if .num_ap then " | \(.num_ap) APs" else "" end)\(if .num_adopted then " | \(.num_adopted) adopted" else "" end)"'
    else
        echo "- No health data available"
    fi
    echo ""
    
    # Devices
    local device_count online_count offline_count
    device_count=$(echo "$json_data" | jq '[.data.devices[]?] | length')
    online_count=$(echo "$json_data" | jq '[.data.devices[]? | select(.state == 1)] | length')
    offline_count=$((device_count - online_count))
    
    cat <<EOF
## Devices ($device_count total, $online_count online, $offline_count offline)
EOF
    
    if (( device_count > 0 )); then
        echo "$json_data" | jq -r '.data.devices[]? | 
            "- **\(.name // .mac)** (\(.model // "unknown")): \(if .state == 1 then "🟢 Online" else "🔴 Offline" end) | \(if .num_sta then "\(.num_sta) clients" else "" end)\(if .uptime then " | Uptime: \((.uptime / 86400 | floor))d \(((.uptime % 86400) / 3600 | floor))h" else "" end)"'
    else
        echo "- No devices found"
    fi
    echo ""
    
    # Active Clients
    local client_count wired_count wireless_count
    client_count=$(echo "$json_data" | jq '[.data.clients[]?] | length')
    wired_count=$(echo "$json_data" | jq '[.data.clients[]? | select(.is_wired == true)] | length')
    wireless_count=$((client_count - wired_count))
    
    cat <<EOF
## Active Clients ($client_count total, $wireless_count wireless, $wired_count wired)
EOF
    
    if (( client_count > 0 )); then
        # Show top clients by activity (limit to 20)
        echo "### Top Clients"
        echo "$json_data" | jq -r '
            [.data.clients[]? | {
                name: (.hostname // .name // .mac),
                ip: .ip,
                is_wired: .is_wired,
                signal: (.rssi // .signal // null),
                ap_name: .ap_name,
                tx_rate: .tx_rate,
                rx_rate: .rx_rate,
                tx_bytes: .tx_bytes,
                rx_bytes: .rx_bytes
            }] | sort_by(-(.tx_bytes // 0)) | .[:20][] |
            "- **\(.name)** (\(.ip // "N/A")): \(if .is_wired then "🔌 Wired" else "📶 \(.signal // "?") dBm" end)\(if .ap_name then " @ \(.ap_name)" else "" end)"'
        
        # Show clients with poor signal
        local poor_signal_count
        poor_signal_count=$(echo "$json_data" | jq "[.data.clients[]? | select(.is_wired != true and (.rssi // .signal // 0) < $CLIENT_SIGNAL_WARN)] | length")
        
        if (( poor_signal_count > 0 )); then
            echo ""
            echo "### ⚠️  Clients with Poor Signal ($poor_signal_count)"
            echo "$json_data" | jq -r "
                [.data.clients[]? | select(.is_wired != true and (.rssi // .signal // 0) < $CLIENT_SIGNAL_WARN)] |
                sort_by(.rssi // .signal // 0) | .[:10][] |
                \"- **\(.hostname // .name // .mac)**: \(.rssi // .signal // 0) dBm @ \(.ap_name // \"unknown AP\")\""
        fi
    else
        echo "- No active clients"
    fi
    echo ""
    
    # WLANs
    local wlan_count
    wlan_count=$(echo "$json_data" | jq '[.data.wlans[]?] | length')
    
    if (( wlan_count > 0 )); then
        cat <<EOF
## Wireless Networks ($wlan_count SSIDs)
EOF
        echo "$json_data" | jq -r '.data.wlans[]? | 
            "- **\(.name)**: \(if .enabled then "✅ Enabled" else "❌ Disabled" end) | \(.security // "open")\(if .wlan_band then " | \(.wlan_band)" else "" end)"'
        echo ""
    fi
    
    # Networks
    local network_count
    network_count=$(echo "$json_data" | jq '[.data.networks[]?] | length')
    
    if (( network_count > 0 )); then
        cat <<EOF
## Networks ($network_count configured)
EOF
        echo "$json_data" | jq -r '.data.networks[]? | 
            "- **\(.name)**: \(.ip_subnet // "no subnet") | VLAN: \(.vlan // "untagged") | \(.purpose // "unknown")"'
        echo ""
    fi
    
    # Alarms
    local alarm_count recent_alarms
    alarm_count=$(echo "$json_data" | jq '[.data.alarms[]?] | length')
    recent_alarms=$(echo "$json_data" | jq "[.data.alarms[]? | select(.archived != true)] | length")
    
    cat <<EOF
## Alarms ($recent_alarms active, $alarm_count total)
EOF
    
    if (( recent_alarms > 0 )); then
        echo "$json_data" | jq -r '
            [.data.alarms[]? | select(.archived != true)] | sort_by(-(.time // .datetime // 0)) | .[:10][] |
            "- \(.msg // .key // "unknown")"'
    else
        echo "- ✅ No active alarms"
    fi
    echo ""
    
    # DPI - Top Applications
    local dpi_count
    dpi_count=$(echo "$json_data" | jq '[.data.dpi[]?] | length')
    
    if (( dpi_count > 0 )); then
        cat <<EOF
## Top Applications (DPI)
EOF
        # DPI data structure varies; try to extract useful info
        echo "$json_data" | jq -r '
            [.data.dpi[]? | .by_cat[]? // .] | 
            sort_by(-((.tx_bytes // 0) + (.rx_bytes // 0))) | 
            .[:10][] | 
            "- \(.cat // .app // "Unknown"): \(if .tx_bytes then ((.tx_bytes + (.rx_bytes // 0)) / 1073741824 * 100 | floor / 100 | tostring) + " GB" else "N/A" end)"' 2>/dev/null || echo "- DPI data format not recognized"
        echo ""
    fi
    
    # Rogue APs Summary
    local rogueap_count
    rogueap_count=$(echo "$json_data" | jq '[.data.rogueap[]?] | length')
    
    cat <<EOF
## Neighboring APs ($rogueap_count detected)
EOF
    if (( rogueap_count > 0 )); then
        # Show top 5 by signal strength
        echo "$json_data" | jq -r '
            [.data.rogueap[]?] | sort_by(-(.rssi // .signal // 0)) | .[:5][] |
            "- **\(.essid // "Hidden")** (\(.bssid)): \(.rssi // .signal // "?") dBm | Ch \(.channel // "?")"'
        (( rogueap_count > 5 )) && echo "- *(+$((rogueap_count - 5)) more)*"
    else
        echo "- No neighboring APs detected"
    fi
    echo ""
    
    # Alerts Summary
    local alert_count
    alert_count=$(echo "$json_data" | jq '[.alerts[]?] | length')
    
    cat <<EOF
## Health Summary
EOF
    
    if (( alert_count == 0 )); then
        echo "✅ **All systems healthy**"
    else
        local critical_count warning_count
        critical_count=$(echo "$json_data" | jq '[.alerts[]? | select(.severity == "critical")] | length')
        warning_count=$(echo "$json_data" | jq '[.alerts[]? | select(.severity == "warning")] | length')
        
        echo "⚠️  **$alert_count alert(s)** ($critical_count critical, $warning_count warnings)"
        echo ""
        echo "$json_data" | jq -r '.alerts[]? | "- [\(.severity | ascii_upcase)] \(.message)"'
    fi
    
    echo ""
    echo "---"
    echo ""
}

# === Main Script ===

main() {
    # Initialize logging (enables log rotation)
    init_logging "$SCRIPT_NAME"
    
    log_info "Starting $SCRIPT_NAME"
    
    # Ensure state directory exists
    ensure_state_dir "$STATE_DIR"
    
    # Collect data
    log_info "Collecting data from UniFi controller..."
    local data
    if ! data=$(collect_all_data); then
        log_error "Data collection failed"
        
        # Check if we got an error message (service unavailable, etc.)
        local error_msg
        error_msg=$(echo "$data" | jq -r '.error // "Unknown error"' 2>/dev/null)
        
        # Write error state file so caller knows what happened
        jq -n \
            --argjson timestamp "$TIMESTAMP" \
            --arg script "$SCRIPT_NAME" \
            --arg error "$error_msg" \
            --arg hostname "$(hostname)" \
            '{
                timestamp: $timestamp,
                script: $script,
                error: $error,
                data: null,
                alerts: [],
                metadata: {
                    hostname: $hostname,
                    status: "service_unavailable"
                }
            }' > "$JSON_FILE"
        
        ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"
        
        # Write error state to markdown
        cat > "$CURRENT_MD" <<EOF
# UniFi Network Dashboard
Generated: $(date)

## ⚠️ Service Unavailable

**Error:** $error_msg

The UniFi Network application is currently unavailable. This may be due to:
- Database migration in progress
- Service restart
- Controller update

Please try again later.

---
EOF
        log_warn "Created error state file: $JSON_FILE"
        exit 1
    fi
    
    # Check for errors in data
    if echo "$data" | jq -e '.error' >/dev/null 2>&1; then
        log_error "Data collection returned error: $(echo "$data" | jq -r '.error')"
        exit 1
    fi
    
    # 1. Write JSON state file (timestamped)
    # Use temp files to avoid "Argument list too long"
    local tmp_data=$(mktemp)
    local tmp_alerts=$(mktemp)
    echo "$data" | jq '.data' > "$tmp_data"
    echo "$data" | jq '.alerts' > "$tmp_alerts"
    
    jq -n \
        --argjson timestamp "$TIMESTAMP" \
        --arg script "$SCRIPT_NAME" \
        --slurpfile data "$tmp_data" \
        --slurpfile alerts "$tmp_alerts" \
        --arg hostname "$(hostname)" \
        --argjson exec_time "$(($(date +%s) - TIMESTAMP))" \
        '{
            timestamp: $timestamp,
            script: $script,
            data: $data[0],
            alerts: $alerts[0],
            metadata: {
                hostname: $hostname,
                execution_time: "\($exec_time)s"
            }
        }' > "$JSON_FILE"
    
    rm -f "$tmp_data" "$tmp_alerts"
    
    log_info "JSON state saved to: $JSON_FILE"
    
    # 2. Update 'latest' symlink (relative path)
    ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"
    
    # 3. Convert to markdown inventory (human-readable)
    generate_markdown_inventory "$data" > "$CURRENT_MD"
    log_info "Markdown inventory saved to: $CURRENT_MD"
    
    # 4. Clean up old state files (keep per retention policy)
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"
    
    # Check for alerts and notify
    local alert_count
    alert_count=$(echo "$data" | jq -r '.alerts | length')
    
    if (( alert_count > 0 )); then
        local critical_count
        critical_count=$(echo "$data" | jq '[.alerts[]? | select(.severity == "critical")] | length')
        
        local alert_msg
        alert_msg=$(echo "$data" | jq -r '.alerts[] | "[\(.severity | ascii_upcase)] \(.message)"' | head -10)
        
        local priority="normal"
        (( critical_count > 0 )) && priority="high"
        
        notify_alert "UniFi Network Alert ($alert_count issues)" "$alert_msg" "$priority"
        log_warn "$alert_count alerts generated"
    fi
    
    log_success "$SCRIPT_NAME completed successfully"
}

# Run main function
main "$@"
