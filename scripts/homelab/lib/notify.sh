#!/bin/bash
# Notification helper for cronjob alerts
# ALWAYS logs to file + optionally sends via Gotify/message tool

NOTIFY_METHOD="${CRONJOB_NOTIFY_METHOD:-gotify}"  # gotify, message, file, or none

notify_alert() {
    local TITLE="$1"
    local MESSAGE="$2"
    local PRIORITY="${3:-normal}"  # low, normal, high
    
    # ALWAYS log to file first (regardless of notify method)
    local ALERT_LOG_FILE="$HOME/workspace/homelab/logs/cronjob-alerts.log"
    mkdir -p "$(dirname "$ALERT_LOG_FILE")"
    {
        echo ""
        echo "=== [$PRIORITY] $TITLE - $(date) ==="
        echo "$MESSAGE"
    } >> "$ALERT_LOG_FILE"
    
    # Check if file needs rotation (10MB max)
    local size
    size=$(stat -f%z "$ALERT_LOG_FILE" 2>/dev/null || stat -c%s "$ALERT_LOG_FILE" 2>/dev/null || echo "0")
    if (( size > 10485760 )); then
        [[ -f "$ALERT_LOG_FILE.1" ]] && rm -f "$ALERT_LOG_FILE.1"
        mv "$ALERT_LOG_FILE" "$ALERT_LOG_FILE.1"
        touch "$ALERT_LOG_FILE"
        echo "[$(date)] Rotated alert log (size: ${size} bytes)" >> "$ALERT_LOG_FILE"
    fi
    
    # Now send notification based on method
    case "$NOTIFY_METHOD" in
        file)
            # File-only mode (already logged above)
            echo "📝 Alert logged to: $ALERT_LOG_FILE"
            ;;
            
        gotify)
            # Send via Gotify (requires gotify skill + config)
            GOTIFY_CLI="$HOME/workspace/homelab/skills/gotify/scripts/gotify"
            if [[ -x "$GOTIFY_CLI" ]]; then
                # Map priority to Gotify priority (0-10)
                case "$PRIORITY" in
                    low) GOTIFY_PRIO=2 ;;
                    high) GOTIFY_PRIO=8 ;;
                    *) GOTIFY_PRIO=5 ;;  # normal or default
                esac
                
                if "$GOTIFY_CLI" push \
                    --title "$TITLE" \
                    --message "$MESSAGE" \
                    --priority "$GOTIFY_PRIO" 2>/dev/null; then
                    echo "📱 Sent via Gotify + logged to file"
                else
                    echo "⚠️  Gotify failed (not configured?), logged to file only"
                fi
            else
                echo "⚠️  Gotify not available, logged to file only"
            fi
            ;;
            
        message)
            # Send via message tool
            # Requires CRONJOB_NOTIFY_CHANNEL env var (e.g., "webchat" or phone number)
            if [[ -n "${CRONJOB_NOTIFY_CHANNEL:-}" ]]; then
                claude message send \
                    --target "$CRONJOB_NOTIFY_CHANNEL" \
                    --message "[$PRIORITY] $TITLE

$MESSAGE"
                echo "💬 Sent via message + logged to file"
            else
                echo "⚠️  CRONJOB_NOTIFY_CHANNEL not set, logged to file only"
            fi
            ;;
            
        none)
            # Silent mode
            :
            ;;
            
        *)
            echo "⚠️  Unknown notify method: $NOTIFY_METHOD"
            ;;
    esac
}

# Export for use in other scripts
export -f notify_alert
