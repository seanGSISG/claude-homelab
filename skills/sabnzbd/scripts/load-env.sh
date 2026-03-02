#!/bin/bash
# Environment Loading Library
# Purpose: Centralized environment variable loading with validation
# Usage: source "$SCRIPT_DIR/lib/load-env.sh"

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This library should be sourced, not executed directly" >&2
    exit 1
fi

# Load .env file from standard locations
# Usage: load_env_file [/path/to/.env]
# Args:
#   $1 - Optional path to .env file (default: search standard locations)
# Returns:
#   0 on success, 1 if .env file not found in any location
# Search order (first match wins):
#   1. Explicit path argument (if provided)
#   2. Current directory ./.env (project-specific overrides)
#   3. ~/.claude-homelab/.env (recommended global location)
#   4. ~/claude-homelab/.env (alternative global location)
#   5. Repository root .env (for development)
load_env_file() {
    local env_file=""

    if [[ -n "${1:-}" ]]; then
        # Use explicit path if provided
        env_file="$1"
    else
        # Search standard locations in order of preference
        local search_paths=(
            "$PWD/.env"                      # Current directory (project-specific)
            "$HOME/.claude/.env"     # Recommended global location
            "$HOME/claude-homelab/.env"      # Alternative global location
        )

        # Add repo root as fallback for development
        local lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local repo_root="$(cd "$lib_dir/.." && pwd)"
        search_paths+=("$repo_root/.env")

        # Find first existing .env file
        for path in "${search_paths[@]}"; do
            if [[ -f "$path" ]]; then
                env_file="$path"
                break
            fi
        done
    fi

    # Validate we found an .env file
    if [[ -z "$env_file" ]] || [[ ! -f "$env_file" ]]; then
        echo "ERROR: Environment file not found" >&2
        echo "Searched locations:" >&2
        echo "  - ./.env (current directory)" >&2
        echo "  - ~/.claude-homelab/.env (recommended)" >&2
        echo "  - ~/claude-homelab/.env (alternative)" >&2
        echo "  - Repository root .env (development)" >&2
        echo "" >&2
        echo "Create .env file with required credentials:" >&2
        echo "  mkdir -p ~/.claude" >&2
        echo "  touch ~/.claude/.env" >&2
        echo "  chmod 600 ~/.claude/.env" >&2
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
