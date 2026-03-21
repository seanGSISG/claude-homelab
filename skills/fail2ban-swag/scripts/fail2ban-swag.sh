#!/bin/bash
# Script: fail2ban-swag.sh
# Purpose: Wrapper script for managing fail2ban inside SWAG container on remote host
# Usage: ./fail2ban-swag.sh <command> [args]

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$PLUGIN_ROOT/lib/load-env.sh"
load_env_file || exit 1
validate_env_vars "SWAG_HOST" "SWAG_CONTAINER_NAME" "SWAG_APPDATA_PATH"

# === Configuration ===
SWAG_HOST="${SWAG_HOST}"
SWAG_CONTAINER_NAME="${SWAG_CONTAINER_NAME}"
SWAG_APPDATA_PATH="${SWAG_APPDATA_PATH}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"

# SSH command wrapper
ssh_exec() {
    ssh "$SWAG_HOST" "$@"
}

# Docker exec wrapper
docker_exec() {
    ssh_exec "docker exec $SWAG_CONTAINER_NAME $*"
}

# Check SSH connectivity
check_connectivity() {
    if ! ssh -q -o ConnectTimeout=5 "$SWAG_HOST" exit 2>/dev/null; then
        echo "ERROR: Cannot connect to $SWAG_HOST via SSH" >&2
        echo "Ensure SSH keys are configured and host is reachable" >&2
        exit 1
    fi
}

# JSON output helper
json_output() {
    local key="$1"
    shift
    local data="$*"

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        # Wrap raw output in JSON
        local escaped
        escaped=$(echo "$data" | jq -Rs '.')
        echo "{\"$key\": $escaped}"
    else
        echo "$data"
    fi
}

# === Commands ===

cmd_status() {
    local raw
    raw=$(docker_exec fail2ban-client status)

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        local jail_count jail_list
        jail_count=$(echo "$raw" | grep "Number of jail:" | sed 's/.*:[[:space:]]*//')
        jail_list=$(echo "$raw" | grep "Jail list:" | sed 's/.*:[[:space:]]*//' | tr ',' '\n' | sed 's/^[[:space:]]*//' | jq -R . | jq -s .)
        jq -n --argjson count "${jail_count:-0}" --argjson jails "$jail_list" \
            '{"jail_count": $count, "jails": $jails}'
    else
        echo "=== fail2ban Status ==="
        echo "$raw"
    fi
}

cmd_list_jails() {
    local raw
    raw=$(docker_exec fail2ban-client status | grep "Jail list:" | sed 's/.*Jail list:[[:space:]]*//')

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "$raw" | tr ',' '\n' | sed 's/^[[:space:]]*//' | jq -R . | jq -s '{"jails": .}'
    else
        echo "=== Active Jails ==="
        echo "$raw"
    fi
}

cmd_jail_status() {
    local jail="${1:?Jail name required}"
    local raw
    raw=$(docker_exec fail2ban-client status "$jail")

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        local currently_failed total_failed currently_banned total_banned banned_list
        currently_failed=$(echo "$raw" | grep "Currently failed:" | sed 's/.*:[[:space:]]*//')
        total_failed=$(echo "$raw" | grep "Total failed:" | sed 's/.*:[[:space:]]*//')
        currently_banned=$(echo "$raw" | grep "Currently banned:" | sed 's/.*:[[:space:]]*//')
        total_banned=$(echo "$raw" | grep "Total banned:" | sed 's/.*:[[:space:]]*//')
        banned_list=$(echo "$raw" | grep "Banned IP list:" | sed 's/.*:[[:space:]]*//')

        local banned_json="[]"
        if [[ -n "$banned_list" ]]; then
            banned_json=$(echo "$banned_list" | tr ' ' '\n' | jq -R 'select(length > 0)' | jq -s .)
        fi

        jq -n \
            --arg jail "$jail" \
            --argjson cf "${currently_failed:-0}" \
            --argjson tf "${total_failed:-0}" \
            --argjson cb "${currently_banned:-0}" \
            --argjson tb "${total_banned:-0}" \
            --argjson ips "$banned_json" \
            '{"jail": $jail, "filter": {"currently_failed": $cf, "total_failed": $tf}, "actions": {"currently_banned": $cb, "total_banned": $tb, "banned_ips": $ips}}'
    else
        echo "=== Status for jail: $jail ==="
        echo "$raw"
    fi
}

cmd_banned_ips() {
    local jail="${1:?Jail name required}"
    local raw
    raw=$(docker_exec fail2ban-client get "$jail" banip)

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "$raw" | tr ' ' '\n' | jq -R 'select(length > 0)' | jq -s "{\"jail\": \"$jail\", \"banned_ips\": .}"
    else
        echo "=== Banned IPs in jail: $jail ==="
        echo "$raw"
    fi
}

cmd_unban() {
    local ip="${1:?IP address required}"
    local jail="${2:-}"

    if [[ -n "$jail" ]]; then
        echo "Unbanning $ip from jail: $jail"
        docker_exec fail2ban-client set "$jail" unbanip "$ip"
    else
        echo "Unbanning $ip from all jails"
        docker_exec fail2ban-client unban "$ip"
    fi
    echo "✓ Unbanned $ip"
}

cmd_ban() {
    local ip="${1:?IP address required}"
    local jail="${2:?Jail name required}"

    echo "Banning $ip in jail: $jail"
    docker_exec fail2ban-client set "$jail" banip "$ip"
    echo "✓ Banned $ip"
}

cmd_reload() {
    echo "Reloading fail2ban configuration..."
    docker_exec fail2ban-client reload
    echo "✓ Configuration reloaded"
}

cmd_test_filter() {
    local filter="${1:?Filter name required}"
    echo "=== Testing filter: $filter ==="
    docker_exec fail2ban-regex /config/log/nginx/access.log "/config/fail2ban/filter.d/$filter.conf"
}

cmd_logs() {
    local follow="${1:-}"
    if [[ "$follow" == "--follow" ]]; then
        ssh_exec "tail -f $SWAG_APPDATA_PATH/log/fail2ban/fail2ban.log"
    else
        ssh_exec "tail -100 $SWAG_APPDATA_PATH/log/fail2ban/fail2ban.log"
    fi
}

cmd_nginx_access_log() {
    local follow="${1:-}"
    if [[ "$follow" == "--follow" ]]; then
        ssh_exec "tail -f $SWAG_APPDATA_PATH/log/nginx/access.log"
    else
        ssh_exec "tail -100 $SWAG_APPDATA_PATH/log/nginx/access.log"
    fi
}

cmd_nginx_error_log() {
    local follow="${1:-}"
    if [[ "$follow" == "--follow" ]]; then
        ssh_exec "tail -f $SWAG_APPDATA_PATH/log/nginx/error.log"
    else
        ssh_exec "tail -100 $SWAG_APPDATA_PATH/log/nginx/error.log"
    fi
}

cmd_search_ip() {
    local ip="${1:?IP address required}"
    echo "=== Searching for $ip in logs ==="
    echo ""
    echo "--- fail2ban log ---"
    ssh_exec "grep '$ip' $SWAG_APPDATA_PATH/log/fail2ban/fail2ban.log | tail -20" || echo "No matches in fail2ban log"
    echo ""
    echo "--- nginx access log ---"
    ssh_exec "grep '$ip' $SWAG_APPDATA_PATH/log/nginx/access.log | tail -20" || echo "No matches in nginx access log"
}

cmd_iptables() {
    echo "=== iptables Rules ==="
    docker_exec iptables -L -n -v
}

cmd_create_jail() {
    local jail_name="${1:?Jail name required}"
    shift

    local filter=""
    local logpath=""
    local maxretry=5
    local findtime=600
    local bantime=3600

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --filter) filter="$2"; shift 2 ;;
            --logpath) logpath="$2"; shift 2 ;;
            --maxretry) maxretry="$2"; shift 2 ;;
            --findtime) findtime="$2"; shift 2 ;;
            --bantime) bantime="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    if [[ -z "$filter" ]] || [[ -z "$logpath" ]]; then
        echo "ERROR: --filter and --logpath are required" >&2
        exit 1
    fi

    local jail_config="[$jail_name]
enabled  = true
filter   = $filter
port     = http,https
logpath  = $logpath
maxretry = $maxretry
findtime = $findtime
bantime  = $bantime
chain    = DOCKER-USER"

    echo "Creating jail: $jail_name"
    echo "$jail_config"

    # Append to jail.local on host
    ssh_exec "echo '' >> $SWAG_APPDATA_PATH/fail2ban/jail.local"
    ssh_exec "echo '$jail_config' >> $SWAG_APPDATA_PATH/fail2ban/jail.local"

    echo "✓ Jail created. Run 'reload' to activate."
}

cmd_create_filter() {
    local filter_name="${1:?Filter name required}"
    shift

    local regex=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --regex) regex="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
    done

    if [[ -z "$regex" ]]; then
        echo "ERROR: --regex is required" >&2
        exit 1
    fi

    local filter_config="[Definition]
failregex = $regex
ignoreregex ="

    echo "Creating filter: $filter_name"
    echo "$filter_config"

    # Create filter file on host
    ssh_exec "cat > $SWAG_APPDATA_PATH/fail2ban/filter.d/$filter_name.local" <<EOF
$filter_config
EOF

    echo "✓ Filter created at filter.d/$filter_name.local"
}

cmd_edit_jail() {
    local jail_name="${1:?Jail name required}"
    local editor="${EDITOR:-nano}"
    echo "Opening jail.local for editing..."
    ssh_exec "$editor $SWAG_APPDATA_PATH/fail2ban/jail.local"
}

cmd_backup() {
    local timestamp=$(date +%Y-%m-%d)
    local backup_file="fail2ban-backup-$timestamp.tar.gz"

    echo "Creating backup: $backup_file"
    ssh_exec "cd $SWAG_APPDATA_PATH && tar -czf /tmp/$backup_file fail2ban/"
    scp "$SWAG_HOST:/tmp/$backup_file" .
    ssh_exec "rm /tmp/$backup_file"

    echo "✓ Backup saved to: $backup_file"
}

cmd_restore() {
    local backup_file="${1:?Backup file required}"

    if [[ ! -f "$backup_file" ]]; then
        echo "ERROR: Backup file not found: $backup_file" >&2
        exit 1
    fi

    echo "Restoring from backup: $backup_file"
    scp "$backup_file" "$SWAG_HOST:/tmp/"
    ssh_exec "cd $SWAG_APPDATA_PATH && tar -xzf /tmp/$(basename "$backup_file")"
    ssh_exec "rm /tmp/$(basename "$backup_file")"

    echo "✓ Restored from backup. Run 'reload' to apply changes."
}

cmd_help() {
    cat <<EOF
fail2ban-swag.sh - Manage fail2ban inside SWAG container on remote host

USAGE:
    ./fail2ban-swag.sh [--json] <command> [args]

GLOBAL FLAGS:
    --json                          - Output in JSON format (status, jail-status, list-jails, banned-ips)

COMMANDS:
    status                          - Show fail2ban status
    list-jails                      - List all active jails
    jail-status <jail>              - Show status of specific jail
    banned-ips <jail>               - List banned IPs in jail
    unban <ip> [jail]               - Unban IP (all jails or specific)
    ban <ip> <jail>                 - Ban IP in specific jail
    reload                          - Reload fail2ban configuration
    test-filter <filter>            - Test filter regex against logs
    logs [--follow]                 - View fail2ban logs
    nginx-access-log [--follow]     - View nginx access log
    nginx-error-log [--follow]      - View nginx error log
    search-ip <ip>                  - Search for IP in logs
    iptables                        - Show iptables rules
    create-jail <name> [opts]       - Create new jail
    create-filter <name> [opts]     - Create new filter
    edit-jail <name>                - Edit jail configuration
    backup                          - Backup fail2ban configuration
    restore <file>                  - Restore from backup
    help                            - Show this help

EXAMPLES:
    # Check status
    ./fail2ban-swag.sh status

    # Unban an IP
    ./fail2ban-swag.sh unban 192.168.1.100

    # Create custom jail
    ./fail2ban-swag.sh create-jail custom-401 \\
        --filter custom-401 \\
        --logpath "/config/log/nginx/access.log" \\
        --maxretry 3

    # Test filter
    ./fail2ban-swag.sh test-filter nginx-http-auth

For more information, see SKILL.md
EOF
}

# === Main ===

main() {
    # Parse global flags
    while [[ "${1:-}" == --* ]]; do
        case "$1" in
            --json) OUTPUT_FORMAT="json"; shift ;;
            --help|-h) cmd_help; return ;;
            *) break ;;
        esac
    done

    local cmd="${1:-help}"
    shift || true

    # Skip connectivity check for help
    if [[ "$cmd" != "help" && "$cmd" != "--help" && "$cmd" != "-h" ]]; then
        check_connectivity
    fi

    case "$cmd" in
        status) cmd_status "$@" ;;
        list-jails) cmd_list_jails "$@" ;;
        jail-status) cmd_jail_status "$@" ;;
        banned-ips) cmd_banned_ips "$@" ;;
        unban) cmd_unban "$@" ;;
        ban) cmd_ban "$@" ;;
        reload) cmd_reload "$@" ;;
        test-filter) cmd_test_filter "$@" ;;
        logs) cmd_logs "$@" ;;
        nginx-access-log) cmd_nginx_access_log "$@" ;;
        nginx-error-log) cmd_nginx_error_log "$@" ;;
        search-ip) cmd_search_ip "$@" ;;
        iptables) cmd_iptables "$@" ;;
        create-jail) cmd_create_jail "$@" ;;
        create-filter) cmd_create_filter "$@" ;;
        edit-jail) cmd_edit_jail "$@" ;;
        backup) cmd_backup "$@" ;;
        restore) cmd_restore "$@" ;;
        help|--help|-h) cmd_help ;;
        *) echo "Unknown command: $cmd" >&2; cmd_help; exit 1 ;;
    esac
}

main "$@"
