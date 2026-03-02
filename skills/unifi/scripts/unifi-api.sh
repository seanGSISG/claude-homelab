#!/usr/bin/env bash
# UniFi API helper - handles login and authenticated calls
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$HOME/.homelab-skills/load-env.sh"

# Load credentials from .env (UniFi uses username/password, not API key)
load_env_file || exit 1
validate_env_vars "UNIFI_URL" "UNIFI_USERNAME" "UNIFI_PASSWORD"

# Map to script's internal variable names
UNIFI_USER="$UNIFI_USERNAME"
UNIFI_PASS="$UNIFI_PASSWORD"
UNIFI_SITE="${UNIFI_SITE:-default}"

# Login and store cookie
# Usage: unifi_login [cookie_file_path]
unifi_login() {
  local cookie_file="${1:-${UNIFI_COOKIE_FILE:-$(mktemp)}}"
  
  # If it's a temp file we created just now, export it so subsequent calls use it
  if [ -z "${UNIFI_COOKIE_FILE:-}" ]; then
      export UNIFI_COOKIE_FILE="$cookie_file"
  fi

  local payload
  payload=$(jq -nc --arg username "$UNIFI_USER" --arg password "$UNIFI_PASS" '{username:$username,password:$password}')
  
  # Try login
  curl -sk -c "$cookie_file" \
    -H "Content-Type: application/json" \
    -X POST \
    "$UNIFI_URL/api/auth/login" \
    --data "$payload" >/dev/null

  if [ ! -s "$cookie_file" ]; then
    echo "Error: Login failed (empty cookie file)" >&2
    return 1
  fi
}

# Make authenticated GET request
# Usage: unifi_get <endpoint>
# Endpoint should be like "stat/sta" or "rest/portforward" - site path is added automatically
# Uses UNIFI_COOKIE_FILE if set, otherwise logs in temporarily
unifi_get() {
  local endpoint="$1"
  local temp_cookie=false
  
  # Ensure we have a cookie
  if [ -z "${UNIFI_COOKIE_FILE:-}" ] || [ ! -f "$UNIFI_COOKIE_FILE" ]; then
    temp_cookie=true
    export UNIFI_COOKIE_FILE=$(mktemp)
    unifi_login "$UNIFI_COOKIE_FILE"
  fi
  
  # Handle both old format (/api/s/site/...) and new format (stat/...)
  local full_url
  if [[ "$endpoint" == /api/* ]]; then
    # Old format - use as-is with proxy/network prefix
    full_url="$UNIFI_URL/proxy/network$endpoint"
  else
    # New format - add full path
    full_url="$UNIFI_URL/proxy/network/api/s/$UNIFI_SITE/$endpoint"
  fi
  
  curl -sk -b "$UNIFI_COOKIE_FILE" "$full_url"
  
  # Cleanup if we created a temp cookie just for this request
  if [ "$temp_cookie" = true ]; then
    rm -f "$UNIFI_COOKIE_FILE"
    unset UNIFI_COOKIE_FILE
  fi
}

# Check if UniFi Network application is running
# Returns 0 if running, 1 if not
# Sets UNIFI_STATUS_MESSAGE with details
unifi_check_status() {
  local cookie_file="${UNIFI_COOKIE_FILE:-}"
  local temp_cookie=false
  
  # Ensure we have a cookie
  if [ -z "$cookie_file" ] || [ ! -f "$cookie_file" ]; then
    temp_cookie=true
    cookie_file=$(mktemp)
    unifi_login "$cookie_file" 2>/dev/null || {
      export UNIFI_STATUS_MESSAGE="Login failed"
      return 1
    }
  fi
  
  # Try the health endpoint first (more reliable)
  local health_response
  health_response=$(curl -sk -b "$cookie_file" "$UNIFI_URL/proxy/network/api/s/$UNIFI_SITE/stat/health" 2>/dev/null)
  
  # Cleanup temp cookie
  if [ "$temp_cookie" = true ]; then
    rm -f "$cookie_file"
  fi
  
  if [ -z "$health_response" ]; then
    export UNIFI_STATUS_MESSAGE="Cannot reach UniFi controller"
    return 1
  fi
  
  # Check if the health endpoint returns OK
  local meta_rc
  meta_rc=$(echo "$health_response" | jq -r '.meta.rc // "error"')
  
  if [ "$meta_rc" = "ok" ]; then
    export UNIFI_STATUS_MESSAGE="OK"
    return 0
  elif [ "$meta_rc" = "error" ]; then
    # Check if there's an error message
    local error_msg
    error_msg=$(echo "$health_response" | jq -r '.meta.msg // .error.message // "Unknown error"')
    export UNIFI_STATUS_MESSAGE="Network application error: $error_msg"
    return 1
  else
    export UNIFI_STATUS_MESSAGE="Network application status: $meta_rc"
    return 1
  fi
}

export -f unifi_login
export -f unifi_get
export -f unifi_check_status
export UNIFI_URL UNIFI_SITE
