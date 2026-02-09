#!/bin/bash
# Script Name: authelia-api.sh
# Purpose: Wrapper for Authelia REST API endpoints
# Usage: ./authelia-api.sh <command> [options]

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HOME/claude-homelab/.env"
COOKIE_FILE="/tmp/authelia-cookies-$USER.txt"

# === Functions ===

usage() {
    cat <<EOF
Usage: $0 <command> [options]

Commands:
    health              Check system health
    state               Get authentication state
    config              Get system configuration
    user-info           Get user information
    user-2fa            Get user 2FA preferences
    session-status      Check session validity
    elevation           Check session elevation status
    dashboard           Complete security dashboard (all info)

Options:
    --help              Show this help message
    --json              Output raw JSON (default)

Authentication:
    Uses AUTHELIA_USERNAME and AUTHELIA_PASSWORD from .env for cookie auth
    Or AUTHELIA_API_TOKEN for bearer token auth

Examples:
    $0 health
    $0 state
    $0 dashboard
    $0 user-info | jq .

Environment Variables:
    AUTHELIA_URL        Authelia server URL (required)
    AUTHELIA_USERNAME   Username for authentication (required for cookie auth)
    AUTHELIA_PASSWORD   Password for authentication (required for cookie auth)
    AUTHELIA_API_TOKEN  Bearer token (optional, replaces cookie auth)
EOF
}

# Authenticate and get session cookie
authenticate() {
    # Skip if using bearer token
    if [[ -n "${AUTHELIA_API_TOKEN:-}" ]]; then
        return 0
    fi

    # Skip if cookie file exists and is recent (less than 1 hour old)
    if [[ -f "$COOKIE_FILE" ]]; then
        local file_age=$(($(date +%s) - $(stat -c %Y "$COOKIE_FILE" 2>/dev/null || stat -f %m "$COOKIE_FILE" 2>/dev/null)))
        if [[ $file_age -lt 3600 ]]; then
            return 0
        fi
    fi

    # Check credentials
    if [[ -z "${AUTHELIA_USERNAME:-}" ]] || [[ -z "${AUTHELIA_PASSWORD:-}" ]]; then
        echo "ERROR: AUTHELIA_USERNAME and AUTHELIA_PASSWORD required for cookie auth" >&2
        echo "Or set AUTHELIA_API_TOKEN for bearer token auth" >&2
        exit 1
    fi

    # Create cookie file with restricted permissions
    touch "$COOKIE_FILE"
    chmod 600 "$COOKIE_FILE"

    # Authenticate
    local auth_response
    auth_response=$(curl -sk -c "$COOKIE_FILE" \
        -X POST "$AUTHELIA_URL/api/firstfactor" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$AUTHELIA_USERNAME\",\"password\":\"$AUTHELIA_PASSWORD\",\"keepMeLoggedIn\":false}" \
        2>/dev/null)

    # Check for authentication success
    local http_code
    http_code=$(curl -sk -c "$COOKIE_FILE" -o /dev/null -w "%{http_code}" \
        -X POST "$AUTHELIA_URL/api/firstfactor" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$AUTHELIA_USERNAME\",\"password\":\"$AUTHELIA_PASSWORD\",\"keepMeLoggedIn\":false}")

    if [[ "$http_code" != "200" ]] && [[ "$http_code" != "204" ]]; then
        echo "ERROR: Authentication failed with HTTP $http_code" >&2
        echo "Response: $auth_response" >&2
        rm -f "$COOKIE_FILE"
        exit 1
    fi
}

# Make authenticated API call
api_call() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    # Ensure authentication
    authenticate

    # Build curl command
    local curl_cmd="curl -sk"

    # Add authentication
    if [[ -n "${AUTHELIA_API_TOKEN:-}" ]]; then
        curl_cmd+=" -H 'Authorization: Bearer $AUTHELIA_API_TOKEN'"
    else
        curl_cmd+=" -b $COOKIE_FILE"
    fi

    # Add method and content type
    curl_cmd+=" -X $method"
    if [[ -n "$data" ]]; then
        curl_cmd+=" -H 'Content-Type: application/json' -d '$data'"
    fi

    # Add endpoint
    curl_cmd+=" '$AUTHELIA_URL$endpoint'"

    # Execute
    eval "$curl_cmd" 2>/dev/null
}

# Get system health
get_health() {
    # Health endpoint doesn't require auth
    curl -sk "$AUTHELIA_URL/api/health" 2>/dev/null
}

# Get authentication state
get_state() {
    # State endpoint doesn't require auth but returns different data based on auth
    curl -sk "$AUTHELIA_URL/api/state" 2>/dev/null
}

# Get configuration
get_config() {
    api_call "GET" "/api/configuration"
}

# Get user information
get_user_info() {
    api_call "GET" "/api/user/info"
}

# Get user 2FA preferences
get_user_2fa() {
    get_user_info
}

# Check session status
check_session() {
    # Try to get user info - if successful, session is valid
    local response
    response=$(api_call "GET" "/api/user/info" 2>/dev/null)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]] && echo "$response" | jq . >/dev/null 2>&1; then
        echo '{"session_valid": true, "user_info": '$response'}'
    else
        echo '{"session_valid": false, "error": "Session invalid or expired"}'
    fi
}

# Check session elevation
check_elevation() {
    api_call "GET" "/api/user/session/elevation"
}

# Generate dashboard
generate_dashboard() {
    local health state config user_info

    echo "{"
    echo '  "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",'
    echo '  "authelia_url": "'$AUTHELIA_URL'",'

    # Health
    echo -n '  "health": '
    health=$(get_health 2>/dev/null || echo '{"status":"ERROR"}')
    echo "$health,"

    # State
    echo -n '  "state": '
    state=$(get_state 2>/dev/null || echo '{"error":"Failed to get state"}')
    echo "$state,"

    # Config
    echo -n '  "configuration": '
    config=$(get_config 2>/dev/null || echo '{"error":"Failed to get config"}')
    echo "$config,"

    # User info (requires auth)
    echo -n '  "user_info": '
    user_info=$(get_user_info 2>/dev/null || echo '{"error":"Failed to get user info"}')
    echo "$user_info"

    echo "}"
}

# Cleanup on exit
cleanup() {
    # Optional: remove cookie file on exit
    # Commented out to allow cookie reuse between calls
    # rm -f "$COOKIE_FILE"
    :
}

trap cleanup EXIT

# === Main Script ===

main() {
    local command="${1:-}"

    # Handle --help before loading environment
    if [[ -z "$command" ]] || [[ "$command" == "--help" ]]; then
        usage
        exit 0
    fi

    # === Load Environment Variables ===
    if [[ ! -f "$ENV_FILE" ]]; then
        echo "ERROR: .env file not found at $ENV_FILE" >&2
        echo "Please create it with AUTHELIA_URL, AUTHELIA_USERNAME, AUTHELIA_PASSWORD" >&2
        exit 1
    fi

    source "$ENV_FILE"

    # Validate required variables
    if [[ -z "${AUTHELIA_URL:-}" ]]; then
        echo "ERROR: AUTHELIA_URL must be set in .env" >&2
        exit 1
    fi

    # Remove trailing slash from URL
    AUTHELIA_URL="${AUTHELIA_URL%/}"

    case "$command" in
        health)
            get_health
            ;;
        state)
            get_state
            ;;
        config)
            get_config
            ;;
        user-info)
            get_user_info
            ;;
        user-2fa)
            get_user_2fa
            ;;
        session-status)
            check_session
            ;;
        elevation)
            check_elevation
            ;;
        dashboard)
            generate_dashboard
            ;;
        --help)
            usage
            ;;
        *)
            echo "ERROR: Unknown command: $command" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
