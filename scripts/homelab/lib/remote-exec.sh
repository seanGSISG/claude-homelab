#!/bin/bash
# Remote Execution Library
# Purpose: Helpers for deploying and executing scripts on remote SSH hosts
# Usage: source "$SCRIPT_DIR/lib/remote-exec.sh"

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This library should be sourced, not executed directly"
    exit 1
fi

# SSH Configuration
SSH_CONNECT_TIMEOUT="${SSH_CONNECT_TIMEOUT:-10}"
SSH_COMMAND_TIMEOUT="${SSH_COMMAND_TIMEOUT:-60}"
SSH_OPTIONS="-o BatchMode=yes -o ConnectTimeout=$SSH_CONNECT_TIMEOUT -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"

# Maximum parallel SSH connections
MAX_PARALLEL_SSH="${MAX_PARALLEL_SSH:-3}"

# Get list of hosts from ~/.ssh/config
# Returns: List of hostnames, one per line
get_ssh_hosts() {
    local config_file="${HOME}/.ssh/config"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Error: SSH config file not found: $config_file" >&2
        return 1
    fi
    
    # Extract Host entries, excluding wildcards
    grep "^Host " "$config_file" \
        | awk '{print $2}' \
        | grep -v '\*' \
        | sort -u
}

# Test if SSH connection to host works
# Args: $1 = hostname
# Returns: 0 if success, 1 if failed
test_ssh_connection() {
    local host="$1"
    
    if [[ -z "$host" ]]; then
        echo "Error: hostname required" >&2
        return 1
    fi
    
    # Try to run a simple command with timeout
    if timeout "$SSH_CONNECT_TIMEOUT" ssh $SSH_OPTIONS "$host" "true" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get the actual hostname from a remote host
# Args: $1 = SSH target (from config)
# Returns: Actual hostname (e.g., "tootie")
get_remote_hostname() {
    local ssh_target="$1"
    
    ssh $SSH_OPTIONS "$ssh_target" "hostname" 2>/dev/null || echo "$ssh_target"
}

# =============================================================================
# Script Deployment Functions
# =============================================================================

# Get SHA256 hash of a local script
# Args: $1 = script path
# Returns: SHA256 hash
get_script_hash() {
    local script_path="$1"
    
    if [[ ! -f "$script_path" ]]; then
        echo "Error: Script not found: $script_path" >&2
        return 1
    fi
    
    sha256sum "$script_path" | awk '{print $1}'
}

# Get SHA256 hash of a script on remote host
# Args: $1 = hostname, $2 = remote script path
# Returns: SHA256 hash or empty if not found
get_remote_script_hash() {
    local host="$1"
    local remote_path="$2"
    
    ssh $SSH_OPTIONS "$host" "sha256sum '$remote_path' 2>/dev/null | awk '{print \$1}'" 2>/dev/null || echo ""
}

# Check if script needs to be deployed (different hash or doesn't exist)
# Args: $1 = hostname, $2 = local script path, $3 = remote path
# Returns: 0 if deployment needed, 1 if up-to-date
needs_deploy() {
    local host="$1"
    local local_script="$2"
    local remote_path="$3"
    
    local local_hash=$(get_script_hash "$local_script")
    local remote_hash=$(get_remote_script_hash "$host" "$remote_path")
    
    if [[ -z "$remote_hash" ]] || [[ "$local_hash" != "$remote_hash" ]]; then
        return 0  # Needs deploy
    else
        return 1  # Up-to-date
    fi
}

# Deploy a script to remote host
# Args: $1 = hostname, $2 = local script path, $3 = remote path (optional, defaults to /tmp/clawd-scripts/<basename>)
# Returns: 0 on success, 1 on failure
deploy_script() {
    local host="$1"
    local local_script="$2"
    local remote_path="${3:-/tmp/clawd-scripts/$(basename "$local_script")}"
    
    if [[ ! -f "$local_script" ]]; then
        echo "Error: Local script not found: $local_script" >&2
        return 1
    fi
    
    # Create remote directory
    ssh $SSH_OPTIONS "$host" "mkdir -p $(dirname '$remote_path')" 2>/dev/null
    
    # Copy script to remote host
    if scp -q $SSH_OPTIONS "$local_script" "${host}:${remote_path}" 2>/dev/null; then
        # Make executable
        ssh $SSH_OPTIONS "$host" "chmod +x '$remote_path'" 2>/dev/null
        return 0
    else
        echo "Error: Failed to deploy script to $host:$remote_path" >&2
        return 1
    fi
}

# Cleanup deployed scripts on remote host
# Args: $1 = hostname
# Returns: Always 0 (best effort cleanup)
cleanup_remote_scripts() {
    local host="$1"
    ssh $SSH_OPTIONS "$host" "rm -rf /tmp/clawd-scripts" 2>/dev/null || true
}

# =============================================================================
# Remote Execution Functions
# =============================================================================

# Execute a script on remote host
# Args: $1 = hostname, $2 = script path (local or remote), $3+ = arguments
# Returns: stdout from remote execution
remote_exec() {
    local host="$1"
    local script="$2"
    shift 2
    local args="$@"
    local stderr_file="/tmp/remote-exec-$$.err"
    
    local output
    # If script is a local file, stream it to remote host
    if [[ -f "$script" ]]; then
        output=$(timeout "$SSH_COMMAND_TIMEOUT" ssh $SSH_OPTIONS "$host" "bash -s $args" < "$script" 2>"$stderr_file")
    else
        # Assume it's a remote path
        output=$(timeout "$SSH_COMMAND_TIMEOUT" ssh $SSH_OPTIONS "$host" "bash '$script' $args" 2>"$stderr_file")
    fi
    
    local exit_code=$?
    
    # Log stderr if present (use log_debug if available, otherwise echo to stderr)
    if [[ -s "$stderr_file" ]]; then
        if command -v log_debug &>/dev/null; then
            log_debug "Remote stderr from $host: $(cat "$stderr_file")"
        else
            echo "[DEBUG] Remote stderr from $host: $(cat "$stderr_file")" >&2
        fi
    fi
    rm -f "$stderr_file"
    
    echo "$output"
    return $exit_code
}

# Execute a script on remote host and capture JSON output only
# Args: $1 = hostname, $2 = script path, $3+ = arguments
# Returns: JSON output (validated)
remote_exec_json() {
    local host="$1"
    local script="$2"
    shift 2
    local args="$@"
    
    local output
    output=$(remote_exec "$host" "$script" "$args" 2>/dev/null)
    
    # Validate JSON
    if echo "$output" | jq -e . >/dev/null 2>&1; then
        echo "$output"
    else
        echo "{\"error\": \"Invalid JSON output from $host\"}"
        return 1
    fi
}

# Execute a simple command on remote host
# Args: $1 = hostname, $2 = command string
# Returns: stdout from command
remote_cmd() {
    local host="$1"
    local cmd="$2"
    
    timeout "$SSH_COMMAND_TIMEOUT" ssh $SSH_OPTIONS "$host" "$cmd" 2>/dev/null
}
