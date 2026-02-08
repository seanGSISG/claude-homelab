#!/bin/bash
# Environment Loading Library
# Purpose: Centralized environment variable loading with validation
# Usage: source "$SCRIPT_DIR/lib/load-env.sh"

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This library should be sourced, not executed directly" >&2
    exit 1
fi

# Load .env file from repository root
# Usage: load_env_file [/path/to/.env]
# Args:
#   $1 - Optional path to .env file (default: auto-detect from repo root)
# Returns:
#   0 on success, 1 if .env file not found
load_env_file() {
    # Default to .env in repo root (one level up from lib/)
    local lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_root="$(cd "$lib_dir/.." && pwd)"
    local env_file="${1:-$repo_root/.env}"

    if [[ ! -f "$env_file" ]]; then
        echo "ERROR: Environment file not found: $env_file" >&2
        echo "Create .env file with required credentials" >&2
        return 1
    fi

    # Source with auto-export (set -a exports all variables)
    set -a
    source "$env_file"
    set +a

    return 0
}

# Validate required environment variables exist
# Usage: validate_env_vars "VAR1" "VAR2" "VAR3"
# Args:
#   $@ - List of required environment variable names to check
# Returns:
#   0 if all variables exist and are non-empty, 1 if any are missing
validate_env_vars() {
    local missing=()

    for var in "$@"; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("$var")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing required environment variables: ${missing[*]}" >&2
        echo "Add these to your .env file" >&2
        return 1
    fi

    return 0
}

# Load service credentials from environment
# Loads .env file if variables not already set, then validates they exist
# Usage: load_service_credentials "service_name" "URL_VAR" "API_KEY_VAR"
# Args:
#   $1 - Service name (for logging/debugging)
#   $2 - URL environment variable name
#   $3 - API key environment variable name
# Returns:
#   0 on success, 1 if .env not found or required variables missing
load_service_credentials() {
    local service_name="$1"
    local url_var="$2"
    local key_var="$3"

    # Load .env if variables not already set in environment
    if [[ -z "${!url_var:-}" ]] || [[ -z "${!key_var:-}" ]]; then
        load_env_file || return 1
    fi

    # Validate we got the required credentials
    validate_env_vars "$url_var" "$key_var"
}

# Functions are automatically available when this file is sourced
# No need to export since they're used in the same shell context
