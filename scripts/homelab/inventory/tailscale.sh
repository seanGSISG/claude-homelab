#!/bin/bash
# Script Name: tailscale-inventory.sh
# Purpose: Inventory all devices on the Tailscale network (tailnet)
# Output: JSON state file + Markdown inventory
# Cron: */15 * * * * (every 15 minutes)

set -euo pipefail

# Add snap binaries to PATH (for snap-installed tailscale)
export PATH="/snap/bin:$PATH"

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

# Paths (flat structure in memory/bank)
STATE_DIR="${STATE_DIR:-$HOME/memory/bank/$SCRIPT_NAME}"
CURRENT_MD="$STATE_DIR/latest.md"

# Timestamps
TIMESTAMP=$(date +%s)
JSON_FILE="$STATE_DIR/${TIMESTAMP}.json"
LATEST_LINK="$STATE_DIR/latest.json"

# Retention: 672 files = 7 days at 15-min intervals
STATE_RETENTION="${STATE_RETENTION:-672}"

# Enable Gotify notifications by default (with graceful degradation)
export CRONJOB_NOTIFY_METHOD="${CRONJOB_NOTIFY_METHOD:-gotify}"

# Source shared libraries
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/notify.sh"
source "$REPO_ROOT/lib/state.sh"

# === Cleanup ===
trap 'log_error "Script failed on line $LINENO"' ERR
trap 'cleanup' EXIT

cleanup() {
    rm -f /tmp/tailscale-inv-*.tmp 2>/dev/null || true
}

# === Helper Functions ===

# Check dependencies
check_dependencies() {
    if ! command -v jq &>/dev/null; then
        log_error "jq is required but not installed. Install with: sudo apt install jq"
        exit 1
    fi
}

# Check if Tailscale is installed and running
check_tailscale() {
    if ! command -v tailscale &>/dev/null; then
        log_error "Tailscale CLI not found. Please install Tailscale."
        return 1
    fi
    
    # Check if tailscaled is running
    if ! tailscale status &>/dev/null; then
        log_error "Tailscale daemon not running or not connected."
        return 1
    fi
    
    return 0
}

# === Main Collection Function ===

# Note: Tailscale status API does not expose peer versions, so version field is set to "N/A"
collect_tailscale_data() {
    local raw_json
    raw_json=$(tailscale status --json 2>/dev/null)
    
    if [[ -z "$raw_json" ]]; then
        log_error "Failed to get Tailscale status"
        return 1
    fi
    
    # Parse the JSON and extract device info
    local devices_json
    devices_json=$(echo "$raw_json" | jq -r '
        # Get self node info
        .Self as $self |
        
        # Build devices object from peers + self
        (
            # Self device
            {
                ($self.HostName // $self.DNSName | split(".")[0]): {
                    tailscale_ip: ($self.TailscaleIPs[0] // "Unknown"),
                    dns_name: ($self.DNSName // ""),
                    os: ($self.OS // "Unknown"),
                    online: true,
                    last_seen: "Now",
                    last_seen_raw: null,
                    tags: ($self.Tags // []),
                    exit_node: false,
                    exit_node_option: ($self.ExitNodeOption // false),
                    routes: ($self.PrimaryRoutes // []),
                    relay: "",
                    cur_addr: "",
                    connection: "Self",
                    version: "N/A",
                    is_self: true,
                    active: true,
                    rx_bytes: ($self.RxBytes // 0),
                    tx_bytes: ($self.TxBytes // 0)
                }
            }
        ) + (
            # Peer devices
            (.Peer // {}) | to_entries | map(
                .value as $peer |
                {
                    ($peer.HostName // $peer.DNSName | split(".")[0]): {
                        tailscale_ip: ($peer.TailscaleIPs[0] // "Unknown"),
                        dns_name: ($peer.DNSName // ""),
                        os: ($peer.OS // "Unknown"),
                        online: ($peer.Online // false),
                        last_seen: ($peer.LastSeen // null),
                        last_seen_raw: ($peer.LastSeen // null),
                        tags: ($peer.Tags // []),
                        exit_node: ($peer.ExitNode // false),
                        exit_node_option: ($peer.ExitNodeOption // false),
                        routes: ($peer.PrimaryRoutes // []),
                        relay: ($peer.Relay // ""),
                        cur_addr: ($peer.CurAddr // ""),
                        connection: (
                            if ($peer.Relay // "") != "" then "Relayed"
                            elif ($peer.CurAddr // "") != "" then "Direct"
                            else "Unknown"
                            end
                        ),
                        version: "N/A",
                        is_self: false,
                        active: ($peer.Active // false),
                        rx_bytes: ($peer.RxBytes // 0),
                        tx_bytes: ($peer.TxBytes // 0)
                    }
                }
            ) | add // {}
        )
    ')
    
    # Calculate summary
    local total_devices online_count offline_count exit_nodes
    total_devices=$(echo "$devices_json" | jq 'length')
    online_count=$(echo "$devices_json" | jq '[.[] | select(.online == true)] | length')
    offline_count=$(echo "$devices_json" | jq '[.[] | select(.online == false)] | length')
    exit_nodes=$(echo "$devices_json" | jq '[.[] | select(.exit_node_option == true)] | length')
    
    # Get current node info
    local current_node
    current_node=$(echo "$raw_json" | jq -r '.Self.HostName // .Self.DNSName | split(".")[0]')
    
    # Get tailnet name from DNS name
    local tailnet_name
    tailnet_name=$(echo "$raw_json" | jq -r '.Self.DNSName // "" | split(".") | if length > 1 then .[1:] | join(".") else "Unknown" end')
    
    # Build complete output
    jq -n \
        --argjson devices "$devices_json" \
        --argjson total "$total_devices" \
        --argjson online "$online_count" \
        --argjson offline "$offline_count" \
        --argjson exits "$exit_nodes" \
        --arg current "$current_node" \
        --arg tailnet "$tailnet_name" \
        '{
            devices: $devices,
            summary: {
                total_devices: $total,
                online: $online,
                offline: $offline,
                exit_nodes: $exits
            },
            network: {
                current_node: $current,
                tailnet: $tailnet
            }
        }'
}

# === Offline Detection & Alerting ===

check_offline_changes() {
    local current_data="$1"
    local previous_file
    previous_file=$(get_state_at_offset "$STATE_DIR" 1 2>/dev/null || echo "")
    
    if [[ -z "$previous_file" || ! -f "$previous_file" ]]; then
        return 0
    fi
    
    # Get previously online devices that are now offline
    local newly_offline
    newly_offline=$(jq -n \
        --argjson current "$current_data" \
        --slurpfile previous "$previous_file" '
        ($previous[0].data.devices // {}) as $prev |
        ($current.devices // {}) as $curr |
        [
            $prev | to_entries[] |
            select(.value.online == true) |
            .key as $name |
            select(($curr[$name].online // false) == false) |
            $name
        ]
    ')
    
    local count
    count=$(echo "$newly_offline" | jq 'length')
    
    if (( count > 0 )); then
        local names
        names=$(echo "$newly_offline" | jq -r 'join(", ")')
        notify_alert "Tailscale: Device(s) Offline" "The following device(s) went offline: $names" "normal"
        log_warn "Devices went offline: $names"
    fi
}

# === Markdown Generation ===

generate_markdown_inventory() {
    local data="$1"
    local generated_date
    generated_date=$(date '+%Y-%m-%d %H:%M %Z')
    
    # Extract values
    local total online offline exits current_node tailnet
    total=$(echo "$data" | jq -r '.summary.total_devices')
    online=$(echo "$data" | jq -r '.summary.online')
    offline=$(echo "$data" | jq -r '.summary.offline')
    exits=$(echo "$data" | jq -r '.summary.exit_nodes')
    current_node=$(echo "$data" | jq -r '.network.current_node')
    tailnet=$(echo "$data" | jq -r '.network.tailnet')
    
    cat <<EOF
# Tailscale Network Inventory
Generated: $generated_date

## Summary
- **Tailnet:** $tailnet
- **Current Node:** $current_node
- **Total Devices:** $total
- **Online:** $online ✅ | **Offline:** $offline 🔴
- **Exit Nodes:** $exits

---

## Online Devices ($online)

EOF

    # Online devices
    echo "$data" | jq -r '
        .devices | to_entries | 
        sort_by(.key) |
        map(select(.value.online == true)) |
        .[] |
        "### 🟢 \(.key) (\(.value.tailscale_ip))\n" +
        (if .value.is_self then "- **Status:** This device (self)\n" else "" end) +
        "- **OS:** \(.value.os)\n" +
        (if (.value.tags | length) > 0 then "- **Tags:** \(.value.tags | join(", "))\n" else "" end) +
        (if (.value.routes | length) > 0 then "- **Routes:** \(.value.routes | join(", "))\n" else "" end) +
        (if .value.exit_node_option then "- **Exit Node:** Available\n" else "" end) +
        (if .value.exit_node then "- **Exit Node:** ⚡ Active\n" else "" end) +
        "- **Connection:** \(.value.connection)\n" +
        (if .value.last_seen_raw and .value.last_seen_raw != "null" then "- **Last Seen:** \(.value.last_seen_raw)\n" else "- **Last Seen:** Now\n" end) +
        "\n"
    '

    if (( offline > 0 )); then
        cat <<EOF
---

## Offline Devices ($offline)

EOF

        # Offline devices
        echo "$data" | jq -r '
            .devices | to_entries | 
            sort_by(.key) |
            map(select(.value.online == false)) |
            .[] |
            "### 🔴 \(.key) (\(.value.tailscale_ip))\n" +
            "- **OS:** \(.value.os)\n" +
            (if (.value.tags | length) > 0 then "- **Tags:** \(.value.tags | join(", "))\n" else "" end) +
            (if .value.last_seen_raw and .value.last_seen_raw != "null" then "- **Last Seen:** \(.value.last_seen_raw)\n" else "- **Last Seen:** Unknown\n" end) +
            "\n"
        '
    fi

    cat <<EOF
---

## Device Details

| Device | IP | OS | Status | Connection | Exit Node |
|--------|----|----|--------|------------|-----------|
EOF

    # Table of all devices
    echo "$data" | jq -r '
        .devices | to_entries | 
        sort_by(.key) |
        .[] |
        "| \(.key) | \(.value.tailscale_ip) | \(.value.os) | \(if .value.online then "🟢 Online" else "🔴 Offline" end) | \(.value.connection) | \(if .value.exit_node_option then "✅" else "—" end) |"
    '
}

# === Main Script ===

main() {
    # Initialize logging (REQUIRED - enables log rotation)
    init_logging "$SCRIPT_NAME"
    
    # Check dependencies first (jq required for JSON processing)
    check_dependencies
    
    log_info "Starting $SCRIPT_NAME"
    
    # Check Tailscale availability
    if ! check_tailscale; then
        notify_alert "Tailscale Inventory Failed" "Tailscale CLI not available or not connected" "high"
        exit 1
    fi
    
    # Ensure state directory exists
    ensure_state_dir "$STATE_DIR"
    
    # Collect data
    log_info "Collecting Tailscale network data..."
    DATA=$(collect_tailscale_data)
    
    if [[ -z "$DATA" || "$DATA" == "null" ]]; then
        log_error "Failed to collect Tailscale data"
        notify_alert "Tailscale Inventory Failed" "Could not collect network data" "high"
        exit 1
    fi
    
    # Check for offline changes before saving new state
    check_offline_changes "$DATA"
    
    # 1. Write JSON state file (timestamped)
    local execution_time=$(($(date +%s) - TIMESTAMP))
    cat > "$JSON_FILE" <<EOF
{
  "timestamp": $TIMESTAMP,
  "script": "$SCRIPT_NAME",
  "data": $DATA,
  "metadata": {
    "hostname": "$(hostname)",
    "execution_time": "${execution_time}s"
  }
}
EOF
    log_info "JSON state saved to: $JSON_FILE"
    
    # 2. Update 'latest' symlink (relative path)
    ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"
    
    # 3. Generate markdown inventory (human-readable)
    generate_markdown_inventory "$DATA" > "$CURRENT_MD"
    log_info "Markdown inventory saved to: $CURRENT_MD"
    
    # 4. Clean up old state files (keep per retention policy)
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"
    
    # Log summary
    local total online offline
    total=$(echo "$DATA" | jq -r '.summary.total_devices')
    online=$(echo "$DATA" | jq -r '.summary.online')
    offline=$(echo "$DATA" | jq -r '.summary.offline')
    log_info "$SCRIPT_NAME completed: $total devices ($online online, $offline offline)"
}

# Run main function
main "$@"
