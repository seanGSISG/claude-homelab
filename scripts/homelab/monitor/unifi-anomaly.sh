#!/bin/bash
# UniFi Anomaly Detector - Token-Efficient Network Security Monitoring
# Purpose: Monitor UniFi network for alerts, new devices, rogue APs, health issues, and auth failures
# Output: JSON state + Markdown inventory (only when anomalies detected)
# Cron: */15 * * * * (every 15 minutes)

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

# Shared directory with other UniFi monitoring scripts
STATE_DIR="${STATE_DIR:-$HOME/memory/bank/unifi}"
FILE_PREFIX="anomaly"  # Prefix to avoid collisions with unifi-dashboard

# Timestamps
TIMESTAMP=$(date +%s)
JSON_FILE="$STATE_DIR/${FILE_PREFIX}-${TIMESTAMP}.json"
LATEST_LINK="$STATE_DIR/${FILE_PREFIX}-latest.json"
CURRENT_MD="$STATE_DIR/${FILE_PREFIX}-latest.md"

# Retention (every 15min = 96/day, keep 7 days = 672 files)
STATE_RETENTION="${STATE_RETENTION:-672}"

# Enable Gotify notifications by default
export CRONJOB_NOTIFY_METHOD="${CRONJOB_NOTIFY_METHOD:-gotify}"

# Source shared libraries
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/notify.sh"
source "$REPO_ROOT/lib/state.sh"

# Source UniFi API (exports unifi_login and unifi_get functions)
source "${HOME}/workspace/homelab/skills/unifi/scripts/unifi-api.sh"

# === Cleanup ===
trap 'log_error "Script failed on line $LINENO"' ERR
trap 'cleanup' EXIT

cleanup() {
    # Cleanup temp cookie if it exists
    if [[ -n "${UNIFI_COOKIE_FILE:-}" ]] && [[ -f "$UNIFI_COOKIE_FILE" ]]; then
        rm -f "$UNIFI_COOKIE_FILE" 2>/dev/null || true
    fi
}

# === Functions ===

# Helper: Make API call and extract .data array
unifi_api_get() {
    local endpoint="$1"
    local response
    response=$(unifi_get "$endpoint" 2>/dev/null || echo '')
    
    # Handle empty or invalid responses
    if [[ -z "$response" ]]; then
        echo '[]'
        return
    fi
    
    # Try to extract .data, fall back to empty array
    local data
    data=$(echo "$response" | jq -c '.data // []' 2>/dev/null || echo '[]')
    
    # Validate it's actually an array
    if ! echo "$data" | jq -e 'type == "array"' >/dev/null 2>&1; then
        echo '[]'
        return
    fi
    
    echo "$data"
}

# Check for new UniFi alerts (stat/alarm endpoint)
check_unifi_alerts() {
    local unifi_alerts
    unifi_alerts=$(unifi_api_get "stat/alarm")
    local alert_count
    alert_count=$(echo "$unifi_alerts" | jq 'length')
    local new_alerts="[]"
    
    if [[ "$alert_count" -gt 0 ]]; then
        local last_alerts_file="$STATE_DIR/last_alerts.json"
        
        if [[ -f "$last_alerts_file" ]]; then
            # Find alerts not in previous run (by _id or key)
            new_alerts=$(echo "$unifi_alerts" | jq --slurpfile old "$last_alerts_file" \
                '[.[] | select(._id as $id | $old[0] | map(._id) | index($id) | not)]' 2>/dev/null || echo "$unifi_alerts")
        else
            new_alerts="$unifi_alerts"
        fi
        
        # Save current alerts for next run
        echo "$unifi_alerts" > "$last_alerts_file"
    fi
    
    echo "$new_alerts"
}

# Check for rogue APs (stat/rogueap endpoint)
check_rogue_aps() {
    local rogue_aps
    rogue_aps=$(unifi_api_get "stat/rogueap")
    
    # Filter for recent rogues (seen in last hour) and unknown ones
    # Exclude known neighbor networks if needed
    local suspicious_rogues
    suspicious_rogues=$(echo "$rogue_aps" | jq -c '[.[] | select(.is_rogue == true or .security == "open")]' 2>/dev/null || echo '[]')
    
    echo "$suspicious_rogues"
}

# Check for health issues (stat/health endpoint)
check_health_issues() {
    local health_data
    health_data=$(unifi_api_get "stat/health")
    
    # Find subsystems not in "ok" status
    local unhealthy
    unhealthy=$(echo "$health_data" | jq -c '[.[] | select(.status != "ok")]' 2>/dev/null || echo '[]')
    
    echo "$unhealthy"
}

# Check for offline devices (stat/device endpoint)
check_offline_devices() {
    local devices
    devices=$(unifi_api_get "stat/device")
    
    # state == 0 means offline, state == 1 means connected
    local offline
    offline=$(echo "$devices" | jq -c '[.[] | select(.state == 0) | {name: .name, mac: .mac, model: .model, ip: .ip, last_seen: .last_seen}]' 2>/dev/null || echo '[]')
    
    echo "$offline"
}

# Check for poor signal clients (stat/sta endpoint, signal < -70dBm)
check_poor_signal_clients() {
    local clients
    clients=$(unifi_api_get "stat/sta")
    
    # Clients with signal weaker than -70dBm (more negative = worse)
    local poor_signal
    poor_signal=$(echo "$clients" | jq -c '[.[] | select(.signal != null and .signal < -70) | {hostname: (.hostname // .mac), mac: .mac, ip: .ip, signal: .signal, ap_mac: .ap_mac}]' 2>/dev/null || echo '[]')
    
    echo "$poor_signal"
}

# Check for authentication failures in logs
check_auth_failures() {
    local auth_failures="false"
    
    if [[ -f "${HOME}/workspace/homelab/logs/gateway.log" ]]; then
        local recent_401
        recent_401=$(grep -c "401 Unauthorized" "${HOME}/workspace/homelab/logs/gateway.log" 2>/dev/null || echo "0")
        if [[ "$recent_401" -gt 0 ]]; then
            auth_failures="true"
        fi
    fi
    
    echo "$auth_failures"
}

# Check for new/unknown devices
check_new_devices() {
    local clients
    clients=$(unifi_api_get "stat/sta")
    local known_devices_file="$STATE_DIR/${FILE_PREFIX}-known_devices.json"
    local new_devices="[]"
    
    if [[ -f "$known_devices_file" ]]; then
        new_devices=$(echo "$clients" | jq --slurpfile known "$known_devices_file" \
            '[.[] | select(.mac as $m | $known[0] | map(.mac) | index($m) | not) | {hostname: (.hostname // "Unknown"), mac: .mac, ip: .ip, oui: .oui, first_seen: .first_seen}]' 2>/dev/null || echo '[]')
    else
        # First run - all devices are "new" but don't alert
        log_info "First run - initializing known devices list"
        new_devices="[]"
    fi
    
    # Update known devices (store minimal info)
    echo "$clients" | jq -c '[.[] | {mac: .mac, hostname: .hostname, ip: .ip}]' > "$known_devices_file"
    
    echo "$new_devices"
}

# Collect all anomaly data
collect_anomaly_data() {
    log_info "Checking for UniFi anomalies..."
    
    # Login once for all API calls
    if ! unifi_login 2>/dev/null; then
        log_warn "UniFi API login failed - may be rate-limited or credentials invalid"
    fi
    
    local new_alerts=$(check_unifi_alerts)
    local rogue_aps=$(check_rogue_aps)
    local health_issues=$(check_health_issues)
    local offline_devices=$(check_offline_devices)
    local poor_signal_clients=$(check_poor_signal_clients)
    local auth_failures=$(check_auth_failures)
    local new_devices=$(check_new_devices)
    
    local alerts_count=$(echo "$new_alerts" | jq 'length')
    local rogue_count=$(echo "$rogue_aps" | jq 'length')
    local health_count=$(echo "$health_issues" | jq 'length')
    local offline_count=$(echo "$offline_devices" | jq 'length')
    local poor_signal_count=$(echo "$poor_signal_clients" | jq 'length')
    local devices_count=$(echo "$new_devices" | jq 'length')
    
    jq -n \
        --argjson new_alerts "$new_alerts" \
        --argjson rogue_aps "$rogue_aps" \
        --argjson health_issues "$health_issues" \
        --argjson offline_devices "$offline_devices" \
        --argjson poor_signal_clients "$poor_signal_clients" \
        --arg auth_failures "$auth_failures" \
        --argjson new_devices "$new_devices" \
        --argjson alerts_count "$alerts_count" \
        --argjson rogue_count "$rogue_count" \
        --argjson health_count "$health_count" \
        --argjson offline_count "$offline_count" \
        --argjson poor_signal_count "$poor_signal_count" \
        --argjson devices_count "$devices_count" \
        '{
            new_alerts: $new_alerts,
            new_alerts_count: $alerts_count,
            rogue_aps: $rogue_aps,
            rogue_aps_count: $rogue_count,
            health_issues: $health_issues,
            health_issues_count: $health_count,
            offline_devices: $offline_devices,
            offline_devices_count: $offline_count,
            poor_signal_clients: $poor_signal_clients,
            poor_signal_clients_count: $poor_signal_count,
            auth_failures: ($auth_failures == "true"),
            new_devices: $new_devices,
            new_devices_count: $devices_count,
            has_anomalies: ($alerts_count > 0 or $rogue_count > 0 or $health_count > 0 or $offline_count > 0 or $auth_failures == "true" or $devices_count > 0)
        }'
}

# Generate alerts for notification
generate_alerts() {
    local data="$1"
    local -a alerts=()
    
    local new_alerts_count=$(echo "$data" | jq -r '.new_alerts_count')
    local rogue_count=$(echo "$data" | jq -r '.rogue_aps_count')
    local health_count=$(echo "$data" | jq -r '.health_issues_count')
    local offline_count=$(echo "$data" | jq -r '.offline_devices_count')
    local poor_signal_count=$(echo "$data" | jq -r '.poor_signal_clients_count')
    local auth_failures=$(echo "$data" | jq -r '.auth_failures')
    local new_devices_count=$(echo "$data" | jq -r '.new_devices_count')
    
    # Critical: Rogue APs detected
    if [[ "$rogue_count" -gt 0 ]]; then
        local rogue_list=$(echo "$data" | jq -r '.rogue_aps[:5][] | "- \(.essid // "Hidden") (Ch: \(.channel // "?"), RSSI: \(.rssi // "?"))"')
        alerts+=("{\"severity\":\"critical\",\"type\":\"rogue_aps\",\"count\":$rogue_count,\"message\":\"🚨 $rogue_count rogue/suspicious AP(s) detected:\\n$rogue_list\"}")
    fi
    
    # Critical: Health subsystem issues
    if [[ "$health_count" -gt 0 ]]; then
        local health_list=$(echo "$data" | jq -r '.health_issues[] | "- \(.subsystem): \(.status)"')
        alerts+=("{\"severity\":\"critical\",\"type\":\"health_issues\",\"count\":$health_count,\"message\":\"⚠️ Network health issues:\\n$health_list\"}")
    fi
    
    # Critical: Authentication failures
    if [[ "$auth_failures" == "true" ]]; then
        alerts+=("{\"severity\":\"critical\",\"type\":\"auth_failure\",\"message\":\"🔐 UniFi API authentication failures detected. Cookie may need refresh.\"}")
    fi
    
    # Warning: Offline devices
    if [[ "$offline_count" -gt 0 ]]; then
        local offline_list=$(echo "$data" | jq -r '.offline_devices[:5][] | "- \(.name // .mac) (\(.ip // "no IP"))"')
        alerts+=("{\"severity\":\"warning\",\"type\":\"offline_devices\",\"count\":$offline_count,\"message\":\"📴 $offline_count UniFi device(s) offline:\\n$offline_list\"}")
    fi
    
    # Warning: New UniFi alerts
    if [[ "$new_alerts_count" -gt 0 ]]; then
        local alert_summary=$(echo "$data" | jq -r '.new_alerts[:5][] | "- \(.msg // .key)"')
        alerts+=("{\"severity\":\"warning\",\"type\":\"new_alerts\",\"count\":$new_alerts_count,\"message\":\"🔔 $new_alerts_count new UniFi alert(s):\\n$alert_summary\"}")
    fi
    
    # Info: New devices
    if [[ "$new_devices_count" -gt 0 ]]; then
        local device_list=$(echo "$data" | jq -r '.new_devices[:5][] | "- \(.hostname // .mac) (\(.ip // "no IP"))"')
        alerts+=("{\"severity\":\"info\",\"type\":\"new_devices\",\"count\":$new_devices_count,\"message\":\"📱 $new_devices_count new device(s) on network:\\n$device_list\"}")
    fi
    
    # Info: Poor signal clients (only if > 5 to avoid noise)
    if [[ "$poor_signal_count" -gt 5 ]]; then
        local poor_list=$(echo "$data" | jq -r '.poor_signal_clients | sort_by(.signal)[:5][] | "- \(.hostname) (\(.signal)dBm)"')
        alerts+=("{\"severity\":\"info\",\"type\":\"poor_signal\",\"count\":$poor_signal_count,\"message\":\"📶 $poor_signal_count client(s) with poor WiFi signal (<-70dBm):\\n$poor_list\"}")
    fi
    
    # Convert to JSON array
    if [[ ${#alerts[@]} -gt 0 ]]; then
        echo "[$(IFS=,; echo "${alerts[*]}")]"
    else
        echo "[]"
    fi
}

# Generate markdown inventory
generate_markdown_inventory() {
    local json_data="$1"
    local has_anomalies=$(echo "$json_data" | jq -r '.data.has_anomalies')
    
    cat <<EOF
# UniFi Anomaly Detector Report
Generated: $(date)

## Status
$(if [[ "$has_anomalies" == "true" ]]; then
    echo "⚠️  **Anomalies Detected**"
else
    echo "✅ **No Anomalies**"
fi)

## Summary
| Check | Count | Status |
|-------|-------|--------|
| New Alerts | $(echo "$json_data" | jq -r '.data.new_alerts_count') | $(if [[ "$(echo "$json_data" | jq -r '.data.new_alerts_count')" -gt 0 ]]; then echo "⚠️"; else echo "✅"; fi) |
| Rogue APs | $(echo "$json_data" | jq -r '.data.rogue_aps_count') | $(if [[ "$(echo "$json_data" | jq -r '.data.rogue_aps_count')" -gt 0 ]]; then echo "🚨"; else echo "✅"; fi) |
| Health Issues | $(echo "$json_data" | jq -r '.data.health_issues_count') | $(if [[ "$(echo "$json_data" | jq -r '.data.health_issues_count')" -gt 0 ]]; then echo "🚨"; else echo "✅"; fi) |
| Offline Devices | $(echo "$json_data" | jq -r '.data.offline_devices_count') | $(if [[ "$(echo "$json_data" | jq -r '.data.offline_devices_count')" -gt 0 ]]; then echo "⚠️"; else echo "✅"; fi) |
| Poor Signal | $(echo "$json_data" | jq -r '.data.poor_signal_clients_count') | $(if [[ "$(echo "$json_data" | jq -r '.data.poor_signal_clients_count')" -gt 5 ]]; then echo "ℹ️"; else echo "✅"; fi) |
| Auth Failures | $(echo "$json_data" | jq -r '.data.auth_failures') | $(if [[ "$(echo "$json_data" | jq -r '.data.auth_failures')" == "true" ]]; then echo "🚨"; else echo "✅"; fi) |
| New Devices | $(echo "$json_data" | jq -r '.data.new_devices_count') | $(if [[ "$(echo "$json_data" | jq -r '.data.new_devices_count')" -gt 0 ]]; then echo "ℹ️"; else echo "✅"; fi) |

$(
rogue_count=$(echo "$json_data" | jq -r '.data.rogue_aps_count')
health_count=$(echo "$json_data" | jq -r '.data.health_issues_count')
offline_count=$(echo "$json_data" | jq -r '.data.offline_devices_count')
alerts_count=$(echo "$json_data" | jq -r '.data.new_alerts_count')
devices_count=$(echo "$json_data" | jq -r '.data.new_devices_count')
poor_count=$(echo "$json_data" | jq -r '.data.poor_signal_clients_count')
auth_fail=$(echo "$json_data" | jq -r '.data.auth_failures')

if [[ "$rogue_count" -gt 0 ]]; then
    echo "## 🚨 Rogue APs Detected"
    echo "$json_data" | jq -r '.data.rogue_aps[:10][] | "- **\(.essid // "Hidden SSID")** - Channel: \(.channel // "?"), RSSI: \(.rssi // "?")dBm, Security: \(.security // "?")"'
    echo ""
fi

if [[ "$health_count" -gt 0 ]]; then
    echo "## ⚠️ Health Issues"
    echo "$json_data" | jq -r '.data.health_issues[] | "- **\(.subsystem)**: \(.status) - \(.message // "")"'
    echo ""
fi

if [[ "$offline_count" -gt 0 ]]; then
    echo "## 📴 Offline Devices"
    echo "$json_data" | jq -r '.data.offline_devices[] | "- **\(.name // .mac)** (\(.model // "unknown")) - IP: \(.ip // "N/A")"'
    echo ""
fi

if [[ "$alerts_count" -gt 0 ]]; then
    echo "## 🔔 New Alerts"
    echo "$json_data" | jq -r '.data.new_alerts[:10][] | "- **\(.msg // .key)**"'
    echo ""
fi

if [[ "$devices_count" -gt 0 ]]; then
    echo "## 📱 New Devices"
    echo "$json_data" | jq -r '.data.new_devices[] | "- **\(.hostname // .mac)** - IP: \(.ip // "N/A"), MAC: \(.mac)"'
    echo ""
fi

if [[ "$poor_count" -gt 5 ]]; then
    echo "## 📶 Poor Signal Clients (>5 devices)"
    echo "$json_data" | jq -r '.data.poor_signal_clients | sort_by(.signal)[:10][] | "- **\(.hostname // .mac)** - Signal: \(.signal)dBm, IP: \(.ip // "N/A")"'
    echo ""
fi

if [[ "$auth_fail" == "true" ]]; then
    echo "## 🔐 Authentication Issues"
    echo "⚠️ UniFi API authentication failures detected in recent logs."
    echo "The API cookie may need to be refreshed."
    echo ""
fi
)

---
*Last checked: $(date)*
EOF
}

# === Main Script ===

main() {
    # Initialize logging (MUST be first)
    init_logging "$SCRIPT_NAME"
    
    log_info "Starting $SCRIPT_NAME"
    
    # Ensure state directory exists
    ensure_state_dir "$STATE_DIR"
    
    # Collect anomaly data
    local data=$(collect_anomaly_data)
    local has_anomalies=$(echo "$data" | jq -r '.has_anomalies')
    
    # Generate alerts
    local alerts=$(generate_alerts "$data")
    local alert_count=$(echo "$alerts" | jq 'length')
    
    # Build full JSON output
    local json_output=$(jq -n \
        --argjson timestamp "$TIMESTAMP" \
        --arg script "$SCRIPT_NAME" \
        --arg hostname "$(hostname)" \
        --argjson data "$data" \
        --argjson alerts "$alerts" \
        '{
            timestamp: $timestamp,
            script: $script,
            metadata: {
                hostname: $hostname,
                execution_time: "0s"
            },
            data: $data,
            alerts: $alerts
        }')
    
    # 1. Write JSON state file
    echo "$json_output" > "$JSON_FILE"
    log_info "JSON state saved to: $JSON_FILE"
    
    # 2. Update 'latest' symlink (relative path)
    ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"
    
    # 3. Generate markdown inventory
    generate_markdown_inventory "$json_output" > "$CURRENT_MD"
    log_info "Markdown inventory saved to: $CURRENT_MD"
    
    # 4. Clean up old state files
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"
    
    # 5. Send notifications if anomalies detected
    if [[ "$has_anomalies" == "true" ]]; then
        log_warn "Anomalies detected: $alert_count alert(s)"
        
        # Build alert message grouped by severity
        local critical_msgs=$(echo "$alerts" | jq -r '[.[] | select(.severity == "critical")] | .[].message' 2>/dev/null | head -5)
        local warning_msgs=$(echo "$alerts" | jq -r '[.[] | select(.severity == "warning")] | .[].message' 2>/dev/null | head -5)
        local info_msgs=$(echo "$alerts" | jq -r '[.[] | select(.severity == "info")] | .[].message' 2>/dev/null | head -3)
        
        local alert_msg=""
        [[ -n "$critical_msgs" ]] && alert_msg+="$critical_msgs\n"
        [[ -n "$warning_msgs" ]] && alert_msg+="$warning_msgs\n"
        [[ -n "$info_msgs" ]] && alert_msg+="$info_msgs"
        
        # Determine priority based on highest severity
        local priority="normal"
        if echo "$alerts" | jq -e '.[] | select(.severity == "critical")' >/dev/null 2>&1; then
            priority="high"
        fi
        
        notify_alert "UniFi Anomaly Alert" "$(echo -e "$alert_msg")" "$priority"
    else
        log_info "No anomalies detected"
    fi
    
    log_success "$SCRIPT_NAME completed successfully"
}

# Run main function
main "$@"
