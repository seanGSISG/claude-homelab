#!/bin/bash
# Docker Cache Monitor - Multi-Host with Notification Support
# Purpose: Monitor Docker build cache, image cache, and dangling volumes across fleet
# Output: JSON state + Markdown inventory with recommendations
# Cron: 0 */6 * * * (every 6 hours)

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

# Shared directory with other Docker monitoring scripts
STATE_DIR="${STATE_DIR:-$HOME/memory/bank/docker}"
FILE_PREFIX="cache"  # Prefix to avoid collisions with docker-inventory
CURRENT_MD="$STATE_DIR/${FILE_PREFIX}-latest.md"

# Timestamps
TIMESTAMP=$(date +%s)
JSON_FILE="$STATE_DIR/${FILE_PREFIX}-${TIMESTAMP}.json"
LATEST_LINK="$STATE_DIR/${FILE_PREFIX}-latest.json"

# Retention (configurable via environment)
STATE_RETENTION="${STATE_RETENTION:-168}"  # Keep last 168 files (7 days hourly)

# Enable Gotify notifications by default (with graceful degradation)
export CRONJOB_NOTIFY_METHOD="${CRONJOB_NOTIFY_METHOD:-gotify}"

# Source shared libraries
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/notify.sh"
source "$REPO_ROOT/lib/state.sh"

# Thresholds (in GB) - configurable via env vars
BUILD_CACHE_WARN_GB="${BUILD_CACHE_WARN_GB:-10}"
BUILD_CACHE_CRIT_GB="${BUILD_CACHE_CRIT_GB:-20}"
IMAGE_CACHE_WARN_GB="${IMAGE_CACHE_WARN_GB:-30}"
IMAGE_CACHE_CRIT_GB="${IMAGE_CACHE_CRIT_GB:-50}"
AUTO_PRUNE_THRESHOLD_GB="${AUTO_PRUNE_THRESHOLD_GB:-100}"

# Convert GB thresholds to bytes
BUILD_CACHE_WARN=$((BUILD_CACHE_WARN_GB * 1024 * 1024 * 1024))
BUILD_CACHE_CRIT=$((BUILD_CACHE_CRIT_GB * 1024 * 1024 * 1024))
IMAGE_CACHE_WARN=$((IMAGE_CACHE_WARN_GB * 1024 * 1024 * 1024))
IMAGE_CACHE_CRIT=$((IMAGE_CACHE_CRIT_GB * 1024 * 1024 * 1024))
AUTO_PRUNE_THRESHOLD=$((AUTO_PRUNE_THRESHOLD_GB * 1024 * 1024 * 1024))

# === Cleanup ===
trap 'log_error "Script failed on line $LINENO"' ERR
trap 'cleanup' EXIT

cleanup() {
    # Clean up any temporary files
    rm -f /tmp/docker-cache-*.json 2>/dev/null || true
}

# === Functions ===

# Helper: Convert bytes to human readable
human_size() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "$1 bytes"
}

# Get list of hosts from ~/.ssh/config
get_ssh_hosts() {
    if [[ -f "$HOME/.ssh/config" ]]; then
        grep -E "^Host " "$HOME/.ssh/config" | awk '{print $2}' | grep -v '\*'
    fi
}

# Check Docker bloat on a single host
# Returns JSON object with host data
check_host() {
    local HOST="$1"
    local SSH_CMD=""

    if [[ "$HOST" != "localhost" ]]; then
        SSH_CMD="ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no $HOST"
    fi

    # Test if Docker is available
    if ! $SSH_CMD docker info &>/dev/null; then
        log_warn "Docker not available on $HOST, skipping"
        echo "{\"hostname\": \"$HOST\", \"status\": \"unavailable\", \"error\": \"Docker not available\"}"
        return
    fi

    local BUILD_CACHE_SIZE=0
    local IMAGE_SIZE=0
    local CONTAINER_SIZE=0
    local VOLUME_SIZE=0

    # Get system df data (timeout to prevent hanging)
    local DOCKER_OUTPUT
    if ! DOCKER_OUTPUT=$(timeout 15 $SSH_CMD docker system df --format json 2>/dev/null); then
        log_warn "Docker timeout on $HOST"
        echo "{\"hostname\": \"$HOST\", \"status\": \"timeout\", \"error\": \"Docker timeout\"}"
        return
    fi

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local TYPE SIZE_STR SIZE_BYTES
        TYPE=$(echo "$line" | jq -r '.Type // empty' 2>/dev/null)
        SIZE_STR=$(echo "$line" | jq -r '.Size // "0"' 2>/dev/null)

        # Handle "0B" or empty sizes
        if [[ "$SIZE_STR" == "0B" ]] || [[ -z "$SIZE_STR" ]] || [[ "$SIZE_STR" == "null" ]]; then
            SIZE_BYTES=0
        else
            # Strip trailing 'B' from sizes like "12.48GB" → "12.48G" for numfmt
            local SIZE_STR_CLEAN
            SIZE_STR_CLEAN=$(echo "$SIZE_STR" | sed 's/B$//')
            SIZE_BYTES=$(echo "$SIZE_STR_CLEAN" | numfmt --from=iec 2>/dev/null || echo "0")
        fi

        case "$TYPE" in
            "Build Cache") BUILD_CACHE_SIZE=$SIZE_BYTES ;;
            "Images") IMAGE_SIZE=$SIZE_BYTES ;;
            "Containers") CONTAINER_SIZE=$SIZE_BYTES ;;
            "Local Volumes") VOLUME_SIZE=$SIZE_BYTES ;;
        esac
    done <<< "$DOCKER_OUTPUT"

    # Get dangling volumes count
    local DANGLING_COUNT
    DANGLING_COUNT=$(timeout 15 $SSH_CMD docker volume ls -qf dangling=true 2>/dev/null | wc -l || echo "0")

    # Calculate totals
    local TOTAL_BLOAT=$((BUILD_CACHE_SIZE + IMAGE_SIZE + CONTAINER_SIZE + VOLUME_SIZE))
    local TOTAL_RECLAIMABLE=$((BUILD_CACHE_SIZE + IMAGE_SIZE))

    # Return JSON object
    jq -n \
        --arg hostname "$HOST" \
        --argjson build_cache_bytes "$BUILD_CACHE_SIZE" \
        --argjson image_cache_bytes "$IMAGE_SIZE" \
        --argjson container_bytes "$CONTAINER_SIZE" \
        --argjson volume_bytes "$VOLUME_SIZE" \
        --argjson dangling_volumes "$DANGLING_COUNT" \
        --argjson total_bloat "$TOTAL_BLOAT" \
        --argjson total_reclaimable "$TOTAL_RECLAIMABLE" \
        --arg build_cache_human "$(human_size $BUILD_CACHE_SIZE)" \
        --arg image_cache_human "$(human_size $IMAGE_SIZE)" \
        --arg total_human "$(human_size $TOTAL_BLOAT)" \
        '{
            hostname: $hostname,
            status: "ok",
            build_cache_bytes: $build_cache_bytes,
            image_cache_bytes: $image_cache_bytes,
            container_bytes: $container_bytes,
            volume_bytes: $volume_bytes,
            dangling_volumes: $dangling_volumes,
            total_bloat: $total_bloat,
            total_reclaimable: $total_reclaimable,
            build_cache_human: $build_cache_human,
            image_cache_human: $image_cache_human,
            total_human: $total_human
        }'
}

# Check all hosts and generate alerts
check_host_alerts() {
    local host_data="$1"
    local -a alerts=()

    local hostname status build_cache image_cache dangling total_bloat
    hostname=$(echo "$host_data" | jq -r '.hostname')
    status=$(echo "$host_data" | jq -r '.status')

    # Skip unavailable hosts
    if [[ "$status" != "ok" ]]; then
        alerts+=("{\"host\": \"$hostname\", \"severity\": \"warning\", \"message\": \"Host $status\", \"type\": \"connectivity\"}")
        printf '%s\n' "${alerts[@]}" | jq -s '.'
        return
    fi

    build_cache=$(echo "$host_data" | jq -r '.build_cache_bytes')
    image_cache=$(echo "$host_data" | jq -r '.image_cache_bytes')
    dangling=$(echo "$host_data" | jq -r '.dangling_volumes')
    total_bloat=$(echo "$host_data" | jq -r '.total_bloat')

    # Check build cache
    if (( build_cache > BUILD_CACHE_CRIT )); then
        alerts+=("{\"host\": \"$hostname\", \"severity\": \"critical\", \"message\": \"Build cache: $(human_size $build_cache)\", \"type\": \"build_cache\", \"value\": $build_cache}")
    elif (( build_cache > BUILD_CACHE_WARN )); then
        alerts+=("{\"host\": \"$hostname\", \"severity\": \"warning\", \"message\": \"Build cache: $(human_size $build_cache)\", \"type\": \"build_cache\", \"value\": $build_cache}")
    fi

    # Check image cache
    if (( image_cache > IMAGE_CACHE_CRIT )); then
        alerts+=("{\"host\": \"$hostname\", \"severity\": \"critical\", \"message\": \"Images: $(human_size $image_cache)\", \"type\": \"image_cache\", \"value\": $image_cache}")
    elif (( image_cache > IMAGE_CACHE_WARN )); then
        alerts+=("{\"host\": \"$hostname\", \"severity\": \"warning\", \"message\": \"Images: $(human_size $image_cache)\", \"type\": \"image_cache\", \"value\": $image_cache}")
    fi

    # Check dangling volumes
    if (( dangling >= 5 )); then
        alerts+=("{\"host\": \"$hostname\", \"severity\": \"warning\", \"message\": \"$dangling dangling volumes\", \"type\": \"dangling_volumes\", \"value\": $dangling}")
    fi

    # Check total bloat (auto-prune threshold)
    if (( total_bloat > AUTO_PRUNE_THRESHOLD )); then
        alerts+=("{\"host\": \"$hostname\", \"severity\": \"critical\", \"message\": \"Total bloat: $(human_size $total_bloat) exceeds ${AUTO_PRUNE_THRESHOLD_GB}GB threshold\", \"type\": \"auto_prune\", \"value\": $total_bloat}")
    fi

    # Return alerts as JSON array
    if (( ${#alerts[@]} > 0 )); then
        printf '%s\n' "${alerts[@]}" | jq -s '.'
    else
        echo "[]"
    fi
}

# Collect data from all hosts
collect_data() {
    local -a hosts=()
    local -a all_alerts=()

    # Check localhost
    log_info "Checking localhost..."
    local localhost_data
    localhost_data=$(check_host "localhost")
    hosts+=("$localhost_data")

    local localhost_alerts
    localhost_alerts=$(check_host_alerts "$localhost_data")
    [[ "$localhost_alerts" != "[]" ]] && all_alerts+=("$localhost_alerts")

    # Check all SSH hosts
    for host in $(get_ssh_hosts); do
        [[ -z "$host" ]] && continue
        log_info "Checking $host..."

        local host_data
        host_data=$(check_host "$host")
        hosts+=("$host_data")

        local host_alerts
        host_alerts=$(check_host_alerts "$host_data")
        [[ "$host_alerts" != "[]" ]] && all_alerts+=("$host_alerts")
    done

    # Build final JSON
    local hosts_json
    hosts_json=$(printf '%s\n' "${hosts[@]}" | jq -s '.')

    local alerts_json
    if (( ${#all_alerts[@]} > 0 )); then
        alerts_json=$(printf '%s\n' "${all_alerts[@]}" | jq -s 'flatten')
    else
        alerts_json="[]"
    fi

    jq -n \
        --argjson hosts "$hosts_json" \
        --argjson alerts "$alerts_json" \
        '{hosts: $hosts, alerts: $alerts}'
}

# Generate markdown report from JSON data
generate_markdown_report() {
    local json_data="$1"

    cat <<EOF
# Docker Cache Monitor Report
Generated: $(date)

## Overview

| Host | Build Cache | Images | Total | Dangling Volumes | Status |
|------|-------------|--------|-------|------------------|--------|
EOF

    # Generate table rows
    echo "$json_data" | jq -r '.hosts[] |
        "| \(.hostname) | \(.build_cache_human // "N/A") | \(.image_cache_human // "N/A") | \(.total_human // "N/A") | \(.dangling_volumes // 0) | \(if .status == "ok" then "✅" else "⚠️ \(.status)" end) |"'

    echo ""

    # Alerts section
    local alert_count
    alert_count=$(echo "$json_data" | jq '.alerts | length')

    if (( alert_count > 0 )); then
        cat <<EOF
## ⚠️ Alerts ($alert_count)

EOF
        echo "$json_data" | jq -r '.alerts[] |
            "- \(if .severity == "critical" then "🚨" else "⚠️" end) **[\(.host)]** \(.message)"'
        echo ""
    else
        cat <<EOF
## ✅ No Alerts

All hosts are within acceptable thresholds.

EOF
    fi

    # Recommendations section
    cat <<EOF
## Recommendations

EOF

    # Generate recommendations based on alerts
    local has_recs=false

    # Build cache recommendations
    local build_cache_alerts
    build_cache_alerts=$(echo "$json_data" | jq '[.alerts[] | select(.type == "build_cache")]')
    if [[ "$build_cache_alerts" != "[]" ]]; then
        has_recs=true
        echo "### Build Cache Cleanup"
        echo ""
        echo "$build_cache_alerts" | jq -r '.[] |
            "```bash\n# \(.host) - \(.message)\n\(if .host == "localhost" then "" else "ssh \(.host) " end)docker builder prune -af\n```"'
        echo ""
    fi

    # Image cache recommendations
    local image_cache_alerts
    image_cache_alerts=$(echo "$json_data" | jq '[.alerts[] | select(.type == "image_cache")]')
    if [[ "$image_cache_alerts" != "[]" ]]; then
        has_recs=true
        echo "### Image Cleanup"
        echo ""
        echo "$image_cache_alerts" | jq -r '.[] |
            "```bash\n# \(.host) - \(.message)\n\(if .host == "localhost" then "" else "ssh \(.host) " end)docker image prune -af\n```"'
        echo ""
    fi

    # Dangling volume recommendations
    local dangling_alerts
    dangling_alerts=$(echo "$json_data" | jq '[.alerts[] | select(.type == "dangling_volumes")]')
    if [[ "$dangling_alerts" != "[]" ]]; then
        has_recs=true
        echo "### Volume Cleanup"
        echo ""
        echo "$dangling_alerts" | jq -r '.[] |
            "```bash\n# \(.host) - \(.message)\n\(if .host == "localhost" then "" else "ssh \(.host) " end)docker volume prune -f\n```"'
        echo ""
    fi

    # Auto-prune recommendations
    local auto_prune_alerts
    auto_prune_alerts=$(echo "$json_data" | jq '[.alerts[] | select(.type == "auto_prune")]')
    if [[ "$auto_prune_alerts" != "[]" ]]; then
        has_recs=true
        echo "### Full System Prune (Critical)"
        echo ""
        echo "$auto_prune_alerts" | jq -r '.[] |
            "```bash\n# \(.host) - \(.message)\n\(if .host == "localhost" then "" else "ssh \(.host) \"" end)docker system prune -af --volumes\(if .host == "localhost" then "" else "\"" end)\n```"'
        echo ""
    fi

    if [[ "$has_recs" == "false" ]]; then
        echo "No cleanup actions required at this time."
        echo ""
    fi

    # Thresholds reference
    cat <<EOF
## Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| Build Cache | ${BUILD_CACHE_WARN_GB}GB | ${BUILD_CACHE_CRIT_GB}GB |
| Image Cache | ${IMAGE_CACHE_WARN_GB}GB | ${IMAGE_CACHE_CRIT_GB}GB |
| Auto-Prune | - | ${AUTO_PRUNE_THRESHOLD_GB}GB |
| Dangling Volumes | 5+ | - |

EOF
}

# === Main Script ===

main() {
    # Initialize logging (enables log rotation)
    init_logging "$SCRIPT_NAME"

    log_info "Starting $SCRIPT_NAME"

    # Ensure state directory exists
    ensure_state_dir "$STATE_DIR"

    # Collect data from all hosts
    log_info "Collecting Docker cache data from fleet..."
    local data
    if ! data=$(collect_data); then
        log_error "Data collection failed"
        exit 1
    fi

    # 1. Write JSON state file (timestamped)
    jq -n \
        --argjson timestamp "$TIMESTAMP" \
        --arg script "$SCRIPT_NAME" \
        --argjson data "$data" \
        --arg hostname "$(hostname)" \
        --argjson exec_time "$(($(date +%s) - TIMESTAMP))" \
        --argjson build_warn_gb "$BUILD_CACHE_WARN_GB" \
        --argjson build_crit_gb "$BUILD_CACHE_CRIT_GB" \
        --argjson image_warn_gb "$IMAGE_CACHE_WARN_GB" \
        --argjson image_crit_gb "$IMAGE_CACHE_CRIT_GB" \
        --argjson auto_prune_gb "$AUTO_PRUNE_THRESHOLD_GB" \
        '{
            timestamp: $timestamp,
            script: $script,
            metadata: {
                hostname: $hostname,
                execution_time: "\($exec_time)s",
                thresholds: {
                    build_cache_warn_gb: $build_warn_gb,
                    build_cache_crit_gb: $build_crit_gb,
                    image_cache_warn_gb: $image_warn_gb,
                    image_cache_crit_gb: $image_crit_gb,
                    auto_prune_threshold_gb: $auto_prune_gb
                }
            },
            data: $data
        }' > "$JSON_FILE"

    log_info "JSON state saved to: $JSON_FILE"

    # 2. Update 'latest' symlink (relative path)
    ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"

    # 3. Generate markdown report (human-readable)
    generate_markdown_report "$data" > "$CURRENT_MD"
    log_info "Markdown report saved to: $CURRENT_MD"

    # 4. Clean up old state files (keep per retention policy)
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"

    # 5. Check for alerts and notify
    local alert_count
    alert_count=$(echo "$data" | jq -r '.alerts | length')

    if (( alert_count > 0 )); then
        local alert_msg
        alert_msg=$(echo "$data" | jq -r '.alerts[] | "[\(.severity | ascii_upcase)] \(.host): \(.message)"' | head -10)

        notify_alert "Docker Cache Alert ($alert_count issues)" "$alert_msg" "normal"
        log_warn "$alert_count alerts generated"
    else
        log_info "All hosts healthy - no alerts"
    fi

    log_success "$SCRIPT_NAME completed successfully"
}

# Run main function
main "$@"
