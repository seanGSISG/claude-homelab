#!/bin/bash
# Script Name: overseerr.sh
# Purpose: Query Overseerr API for pending media requests and display dashboard
# Output: JSON state files + markdown dashboard to ~/memory/bank/overseerr/
# Cron: "0 * * * *" (hourly)

set -euo pipefail

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

# Retention (configurable via environment)
STATE_RETENTION="${STATE_RETENTION:-168}"  # Keep last 168 files (7 days hourly)

# Enable Gotify notifications by default (with graceful degradation)
export CRONJOB_NOTIFY_METHOD="${CRONJOB_NOTIFY_METHOD:-gotify}"

# Overseerr-specific configuration
OVERSEERR_SKILL_DIR="$HOME/workspace/homelab/skills/overseerr"

# Configurable thresholds (via environment variables)
PENDING_WARN="${PENDING_WARN:-10}"   # Warn if >10 pending
PENDING_CRIT="${PENDING_CRIT:-20}"   # Critical if >20 pending
FAILED_WARN="${FAILED_WARN:-1}"      # Warn if any failed requests

# Source shared libraries
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/lib/load-env.sh"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/notify.sh"
source "$REPO_ROOT/lib/state.sh"

# Load credentials from .env
load_service_credentials "overseerr" "OVERSEERR_URL" "OVERSEERR_API_KEY"

# === Cleanup ===
trap 'log_error "Script failed on line $LINENO"' ERR
trap 'cleanup' EXIT

cleanup() {
    # Cleanup temporary files, etc.
    :
}

# === Functions ===

# Run Overseerr node script
run_overseerr() {
    local script_name="$1"
    shift
    
    if [[ ! -f "$OVERSEERR_SKILL_DIR/scripts/$script_name" ]]; then
        log_error "Overseerr script not found: $script_name"
        return 1
    fi
    
    node "$OVERSEERR_SKILL_DIR/scripts/$script_name" "$@"
}

# Collect pending requests data (enriched with titles)
collect_pending_requests() {
    log_debug "Fetching pending requests (enriched)..."
    
    local pending_json
    if ! pending_json=$(run_overseerr requests-enriched.mjs --filter pending --limit 100 2>&1); then
        log_error "Failed to fetch pending requests: $pending_json"
        echo "[]"
        return 1
    fi
    
    echo "$pending_json"
}

# Collect recent requests data (enriched with titles)
collect_recent_requests() {
    log_debug "Fetching recent requests (enriched)..."

    local recent_json
    if ! recent_json=$(run_overseerr requests-enriched.mjs --limit 10 2>&1); then
        log_error "Failed to fetch recent requests: $recent_json"
        echo "[]"
        return 1
    fi

    echo "$recent_json"
}

# Collect available (completed/downloaded) requests
collect_available_requests() {
    log_debug "Fetching available requests..."

    local available_json
    if ! available_json=$(run_overseerr requests-enriched.mjs --filter available --limit 10 --sort modified 2>&1); then
        log_error "Failed to fetch available requests: $available_json"
        echo '{"results":[],"pageInfo":{"results":0}}'
        return 1
    fi

    echo "$available_json"
}

# Collect failed requests
collect_failed_requests() {
    log_debug "Fetching failed requests..."

    local failed_json
    if ! failed_json=$(run_overseerr requests-enriched.mjs --filter failed --limit 20 2>&1); then
        log_error "Failed to fetch failed requests: $failed_json"
        echo '{"results":[],"pageInfo":{"results":0}}'
        return 1
    fi

    echo "$failed_json"
}

# Collect processing requests
collect_processing_requests() {
    log_debug "Fetching processing requests..."

    local processing_json
    if ! processing_json=$(run_overseerr requests-enriched.mjs --filter processing --limit 20 2>&1); then
        log_error "Failed to fetch processing requests: $processing_json"
        echo '{"results":[],"pageInfo":{"results":0}}'
        return 1
    fi

    echo "$processing_json"
}

# Check thresholds and generate alerts
check_thresholds() {
    local pending_count="$1"
    local failed_count="$2"
    local -a alerts=()

    if (( pending_count > PENDING_CRIT )); then
        alerts+=("$(jq -n \
            --arg severity "critical" \
            --arg message "Pending requests count ($pending_count) exceeds critical threshold ($PENDING_CRIT)" \
            --argjson value "$pending_count" \
            --argjson threshold "$PENDING_CRIT" \
            '{severity: $severity, message: $message, value: $value, threshold: $threshold}'
        )")
    elif (( pending_count > PENDING_WARN )); then
        alerts+=("$(jq -n \
            --arg severity "warning" \
            --arg message "Pending requests count ($pending_count) exceeds warning threshold ($PENDING_WARN)" \
            --argjson value "$pending_count" \
            --argjson threshold "$PENDING_WARN" \
            '{severity: $severity, message: $message, value: $value, threshold: $threshold}'
        )")
    fi

    if (( failed_count >= FAILED_WARN )); then
        alerts+=("$(jq -n \
            --arg severity "warning" \
            --arg message "There are $failed_count failed media requests that need attention" \
            --argjson value "$failed_count" \
            --argjson threshold "$FAILED_WARN" \
            '{severity: $severity, message: $message, value: $value, threshold: $threshold}'
        )")
    fi

    if [[ ${#alerts[@]} -gt 0 ]]; then
        printf '%s\n' "${alerts[@]}" | jq -s '.'
    else
        echo "[]"
    fi
}

# Generate markdown dashboard from data
generate_markdown_dashboard() {
    local pending_json="$1"
    local recent_json="$2"
    local pending_count="$3"
    local available_json="$4"
    local available_count="$5"
    local failed_json="$6"
    local failed_count="$7"
    local processing_json="$8"
    local processing_count="$9"

    cat <<EOF
# Overseerr Request Dashboard
Generated: $(date)

## Status Summary
| Category | Count |
|----------|-------|
| Pending | $pending_count |
| Processing | $processing_count |
| Available | $available_count |
| Failed | $failed_count |

EOF

    # Failed requests (show first - needs attention)
    if (( failed_count > 0 )); then
        echo "## ❌ Failed Requests"
        echo "*These requests failed and need attention:*"
        echo ""
        echo "$failed_json" | jq -r '
            .results[]? |
            "- **\(.media.mediaType | ascii_upcase)**: \(._title // "Unknown") | User: \(.requestedBy.displayName // "Unknown") | Date: \(.createdAt | split("T")[0])"
        ' 2>/dev/null || echo "- Unable to parse failed items"
        echo ""
    fi

    # Pending requests
    if (( pending_count > 0 )); then
        echo "## ⏳ Pending Requests"
        echo "*Awaiting approval:*"
        echo ""
        echo "$pending_json" | jq -r '.results[]? | "- **\(.media.mediaType | ascii_upcase)**: \(._title // "Unknown") | User: \(.requestedBy.displayName // "Unknown")"' 2>/dev/null || echo "- Unable to parse pending items"
        echo ""
    fi

    # Processing requests
    if (( processing_count > 0 )); then
        echo "## 🔄 Processing"
        echo "*Currently downloading:*"
        echo ""
        echo "$processing_json" | jq -r '
            .results[]? |
            "- **\(.media.mediaType | ascii_upcase)**: \(._title // "Unknown") | User: \(.requestedBy.displayName // "Unknown")"
        ' 2>/dev/null || echo "- Unable to parse processing items"
        echo ""
    fi

    # Recently available (completed downloads)
    if (( available_count > 0 )); then
        echo "## ✅ Recently Available"
        echo "*Recently completed downloads:*"
        echo ""
        echo "$available_json" | jq -r '
            .results[]? |
            "- **\(.media.mediaType | ascii_upcase)**: \(._title // "Unknown") | User: \(.requestedBy.displayName // "Unknown")"
        ' 2>/dev/null || echo "- Unable to parse available items"
        echo ""
    fi

    cat <<EOF
## 📋 Recent Activity
EOF

    echo "$recent_json" | jq -r '
        .results[]? |
        "- **\(.media.mediaType | ascii_upcase)**: \(._title // "Unknown") | Status: \(._statusLabel // .status) | User: \(.requestedBy.displayName // "Unknown") | Date: \(.createdAt | split("T")[0])"
    ' 2>/dev/null || echo "- Unable to parse recent requests"

    cat <<EOF

---
_Dashboard data from Overseerr API_
EOF
}

# === Main Script ===

main() {
    # ⚠️ REQUIRED: Initialize logging (enables log rotation)
    init_logging "$SCRIPT_NAME"

    log_info "Starting $SCRIPT_NAME"

    # Ensure state directory exists
    ensure_state_dir "$STATE_DIR"

    # Collect data
    log_info "Querying Overseerr..."

    PENDING_JSON=$(collect_pending_requests)
    PENDING_COUNT=$(echo "$PENDING_JSON" | jq -r '.pageInfo.results // 0' 2>/dev/null || echo "0")

    RECENT_JSON=$(collect_recent_requests)

    AVAILABLE_JSON=$(collect_available_requests)
    AVAILABLE_COUNT=$(echo "$AVAILABLE_JSON" | jq -r '.pageInfo.results // 0' 2>/dev/null || echo "0")

    FAILED_JSON=$(collect_failed_requests)
    FAILED_COUNT=$(echo "$FAILED_JSON" | jq -r '.pageInfo.results // 0' 2>/dev/null || echo "0")

    PROCESSING_JSON=$(collect_processing_requests)
    PROCESSING_COUNT=$(echo "$PROCESSING_JSON" | jq -r '.pageInfo.results // 0' 2>/dev/null || echo "0")

    log_info "Status: $PENDING_COUNT pending, $PROCESSING_COUNT processing, $AVAILABLE_COUNT available, $FAILED_COUNT failed"

    # Extract request arrays for JSON output
    PENDING_REQUESTS=$(echo "$PENDING_JSON" | jq '.results // []' 2>/dev/null || echo "[]")
    RECENT_REQUESTS=$(echo "$RECENT_JSON" | jq '.results // []' 2>/dev/null || echo "[]")
    AVAILABLE_REQUESTS=$(echo "$AVAILABLE_JSON" | jq '.results // []' 2>/dev/null || echo "[]")
    FAILED_REQUESTS=$(echo "$FAILED_JSON" | jq '.results // []' 2>/dev/null || echo "[]")
    PROCESSING_REQUESTS=$(echo "$PROCESSING_JSON" | jq '.results // []' 2>/dev/null || echo "[]")

    # Check for alerts
    ALERTS_JSON=$(check_thresholds "$PENDING_COUNT" "$FAILED_COUNT")

    # 1. Write JSON state file (timestamped)
    cat > "$JSON_FILE" <<EOF
{
  "timestamp": $TIMESTAMP,
  "script": "$SCRIPT_NAME",
  "data": {
    "pending_count": $PENDING_COUNT,
    "processing_count": $PROCESSING_COUNT,
    "available_count": $AVAILABLE_COUNT,
    "failed_count": $FAILED_COUNT,
    "pending_requests": $PENDING_REQUESTS,
    "processing_requests": $PROCESSING_REQUESTS,
    "available_requests": $AVAILABLE_REQUESTS,
    "failed_requests": $FAILED_REQUESTS,
    "recent_requests": $RECENT_REQUESTS
  },
  "alerts": $ALERTS_JSON,
  "metadata": {
    "hostname": "$(hostname)",
    "overseerr_url": "$OVERSEERR_URL",
    "execution_time": "$(($(date +%s) - TIMESTAMP))s"
  }
}
EOF
    log_info "JSON state saved to: $JSON_FILE"

    # 2. Update 'latest' symlink (relative path)
    ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"

    # 3. Generate markdown dashboard
    generate_markdown_dashboard "$PENDING_JSON" "$RECENT_JSON" "$PENDING_COUNT" \
        "$AVAILABLE_JSON" "$AVAILABLE_COUNT" \
        "$FAILED_JSON" "$FAILED_COUNT" \
        "$PROCESSING_JSON" "$PROCESSING_COUNT" > "$CURRENT_MD"
    log_info "Markdown dashboard saved to: $CURRENT_MD"
    
    # 4. Clean up old state files (keep per retention policy)
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"
    
    # 5. Send notifications for alerts
    local alert_count
    alert_count=$(echo "$ALERTS_JSON" | jq 'length')
    
    if (( alert_count > 0 )); then
        local severity
        severity=$(echo "$ALERTS_JSON" | jq -r '.[0].severity')
        local message
        message=$(echo "$ALERTS_JSON" | jq -r 'map(.message) | join("\n")')
        
        local priority="normal"
        if [[ "$severity" == "critical" ]]; then
            priority="high"
        fi
        
        notify_alert "Overseerr Alert" "$message" "$priority"
        log_warn "Alert sent: $message"
    fi
    
    log_success "$SCRIPT_NAME completed successfully"
    
    # Output current markdown for visibility
    cat "$CURRENT_MD"
}

# Run main function
main "$@"
