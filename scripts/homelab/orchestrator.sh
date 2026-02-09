#!/bin/bash
# Script Name: orchestrator.sh
# Purpose: Orchestrate script execution across discovered SSH hosts
# Output: Execution results to ~/memory/bank/orchestrator/
# Cron: Manual execution (not scheduled)

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

# Paths
STATE_DIR="${STATE_DIR:-$HOME/memory/bank/$SCRIPT_NAME}"
SSH_INVENTORY="$HOME/memory/bank/ssh/latest.json"

# Timestamps
TIMESTAMP=$(date +%s)
JSON_FILE="$STATE_DIR/${TIMESTAMP}.json"
LATEST_LINK="$STATE_DIR/latest.json"

# Retention (manual runs, keep 30 executions)
STATE_RETENTION="${STATE_RETENTION:-30}"

# Enable Gotify notifications by default
export CRONJOB_NOTIFY_METHOD="${CRONJOB_NOTIFY_METHOD:-gotify}"

# Source shared libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/notify.sh"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/remote-exec.sh"

# === Cleanup ===
trap 'log_error "Script failed on line $LINENO"' ERR
trap 'cleanup' EXIT

cleanup() {
    rm -f /tmp/orchestrator-*.tmp 2>/dev/null || true
}

# === Host Filtering Functions ===

# Load SSH inventory
# Returns: JSON array of hosts
load_inventory() {
    if [[ ! -f "$SSH_INVENTORY" ]]; then
        log_error "SSH inventory not found"
        return 1
    fi
    
    jq -c '.' "$SSH_INVENTORY"
}

# Filter hosts based on criteria
# Args: $1 = inventory JSON
#       $2 = filter expression (jq syntax, optional)
# Returns: Filtered JSON array
filter_hosts() {
    local inventory="$1"
    local filter="${2:-.}"
    
    if [[ -z "$inventory" ]]; then
        log_error "Empty inventory passed to filter_hosts"
        return 1
    fi
    
    echo "$inventory" | jq -c "$filter"
}

# Get only reachable hosts
# Args: $1 = inventory JSON
# Returns: JSON array of reachable hosts
get_reachable_hosts() {
    local inventory="$1"
    filter_hosts "$inventory" '[.[] | select(.reachable == true)]'
}

# Get hosts by OS type
# Args: $1 = inventory JSON
#       $2 = os_type (linux, darwin)
# Returns: JSON array of matching hosts
get_hosts_by_os() {
    local inventory="$1"
    local os_type="$2"
    
    if [[ -z "$os_type" ]]; then
        log_error "OS type cannot be empty"
        return 1
    fi
    
    filter_hosts "$inventory" "[.[] | select(.os_type == \"$os_type\")]"
}

# Get hosts with specific capability
# Args: $1 = inventory JSON
#       $2 = capability name (docker, systemd, etc.)
# Returns: JSON array of matching hosts
get_hosts_with_capability() {
    local inventory="$1"
    local capability="$2"
    
    case "$capability" in
        docker)
            filter_hosts "$inventory" '[.[] | select(.docker.has_docker == true)]'
            ;;
        systemd)
            filter_hosts "$inventory" '[.[] | select(.systemd.has_systemd == true)]'
            ;;
        gpu)
            filter_hosts "$inventory" '[.[] | select(.gpu.has_gpu == true)]'
            ;;
        *)
            log_error "Unknown capability: $capability"
            return 1
            ;;
    esac
}

# === Script Execution Functions ===

# Execute script on a single host
# Args: $1 = hostname
#       $2 = script path (local file or remote command)
#       $3 = description
# Returns: JSON with execution result
execute_on_host() {
    local host="$1"
    local script="$2"
    local description="${3:-Executing script}"
    
    log_info "$description on $host"
    
    local start_time=$(date +%s)
    local result
    local exit_code
    
    if [[ -f "$script" ]]; then
        # Local script - use remote_exec
        result=$(remote_exec "$host" "$script" 2>&1)
        exit_code=$?
    else
        # Remote command - use remote_cmd
        result=$(remote_cmd "$host" "$script" 2>&1)
        exit_code=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Build result JSON
    local status="success"
    [[ $exit_code -ne 0 ]] && status="failed"
    
    # Use jq to properly escape all fields
    jq -n \
        --arg hostname "$host" \
        --arg script "$script" \
        --arg desc "$description" \
        --arg status "$status" \
        --argjson exit_code "$exit_code" \
        --argjson duration "$duration" \
        --argjson timestamp "$start_time" \
        --arg output "$result" \
        '{
            hostname: $hostname,
            script: $script,
            description: $desc,
            status: $status,
            exit_code: $exit_code,
            duration: $duration,
            timestamp: $timestamp,
            output: $output
        }'
}

# Execute script on multiple hosts
# Args: $1 = hosts JSON array
#       $2 = script path
#       $3 = description
# Returns: JSON array of execution results
execute_on_hosts() {
    local hosts_json="$1"
    local script="$2"
    local description="${3:-Executing script}"
    
    local results=()
    local hostnames
    
    # Extract hostname array
    mapfile -t hostnames < <(echo "$hosts_json" | jq -r '.[].hostname')
    
    if [[ ${#hostnames[@]} -eq 0 ]]; then
        log_warn "No hosts to execute on"
        echo "[]"
        return 0
    fi
    
    log_info "Executing on ${#hostnames[@]} hosts"
    
    # Execute on each host
    for hostname in "${hostnames[@]}"; do
        local result=$(execute_on_host "$hostname" "$script" "$description")
        results+=("$result")
    done
    
    # Combine results into JSON array
    printf '%s\n' "${results[@]}" | jq -s '.'
}

# Execute script on multiple hosts in parallel
# Args: $1 = hosts JSON array
#       $2 = script path
#       $3 = description
#       $4 = max parallel (optional, default 5)
# Returns: JSON array of execution results
execute_parallel() {
    local hosts_json="$1"
    local script="$2"
    local description="${3:-Executing script}"
    local max_parallel="${4:-5}"
    
    local hostnames
    mapfile -t hostnames < <(echo "$hosts_json" | jq -r '.[].hostname')
    
    if [[ ${#hostnames[@]} -eq 0 ]]; then
        log_warn "No hosts to execute on"
        echo "[]"
        return 0
    fi
    
    log_info "Executing on ${#hostnames[@]} hosts (parallel: $max_parallel)"
    
    # Create temp dir for results
    local temp_dir=$(mktemp -d /tmp/orchestrator-XXXXXX)
    trap "rm -rf $temp_dir" RETURN
    
    # Execute in parallel - source libraries in subprocess
    printf '%s\n' "${hostnames[@]}" | xargs -P "$max_parallel" -I {} bash -c "
        # Source required libraries
        source '$SCRIPT_DIR/lib/logging.sh'
        source '$SCRIPT_DIR/lib/remote-exec.sh'
        
        # Define execute_on_host locally
        $(declare -f execute_on_host)
        
        # Execute
        result=\$(execute_on_host '{}' '$script' '$description')
        echo \"\$result\" > '$temp_dir/{}.json'
    "
    
    # Collect results
    local results=()
    for hostname in "${hostnames[@]}"; do
        if [[ -f "$temp_dir/$hostname.json" ]]; then
            results+=("$(cat "$temp_dir/$hostname.json")")
        fi
    done
    
    # Combine into JSON array
    printf '%s\n' "${results[@]}" | jq -s '.'
}

# Summarize execution results
# Args: $1 = results JSON array
# Outputs: Human-readable summary to stdout
summarize_results() {
    local results="$1"
    
    local total=$(echo "$results" | jq 'length')
    local success=$(echo "$results" | jq '[.[] | select(.status == "success")] | length')
    local failed=$(echo "$results" | jq '[.[] | select(.status == "failed")] | length')
    local avg_duration=$(echo "$results" | jq 'if length == 0 then 0 else ([.[] | .duration] | add / length | floor) end')
    
    echo "Execution Summary:"
    echo "  Total hosts: $total"
    echo "  Success: $success"
    echo "  Failed: $failed"
    echo "  Average duration: ${avg_duration}s"
    
    if [[ $failed -gt 0 ]]; then
        echo ""
        echo "Failed hosts:"
        echo "$results" | jq -r '.[] | select(.status == "failed") | "  - \(.hostname) (exit code: \(.exit_code))"'
    fi
}

# === Helper Functions ===

# Update the latest.json symlink to point to the newest state file
# Args: $1 = target file, $2 = symlink path
update_latest_link() {
    local target="$1"
    local link="$2"
    
    # Remove existing link if present
    rm -f "$link"
    
    # Create symlink (using relative path for portability)
    local target_basename=$(basename "$target")
    ln -sf "$target_basename" "$link"
}

# === CLI Functions ===

# Show usage information
show_usage() {
    cat <<EOF
Usage: orchestrator.sh [OPTIONS] <script> [hosts_filter]

Execute a script across SSH-discovered hosts with optional filtering.

Arguments:
  script          Path to script file or command to execute

Options:
  -f, --filter    jq filter expression (default: reachable hosts)
  -p, --parallel  Execute in parallel (default: sequential)
  -m, --max       Max parallel executions (default: 5)
  -h, --help      Show this help message

Examples:
  # Execute on all reachable hosts
  orchestrator.sh "uptime"

  # Execute on Linux hosts only
  orchestrator.sh -f '[.[] | select(.os_type == "linux")]' "df -h"

  # Execute on Docker hosts in parallel
  orchestrator.sh -f '[.[] | select(.docker.has_docker)]' -p "docker ps"

  # Custom parallel limit
  orchestrator.sh -p -m 10 ./my-script.sh
EOF
}

# Parse command-line arguments
# Sets globals: SCRIPT_TO_EXEC, FILTER_EXPR, PARALLEL_MODE, MAX_PARALLEL
parse_args() {
    SCRIPT_TO_EXEC=""
    FILTER_EXPR='[.[] | select(.reachable == true)]'  # Default: reachable only
    PARALLEL_MODE=false
    MAX_PARALLEL=5
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -f|--filter)
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    log_error "Option -f requires a filter expression"
                    exit 1
                fi
                FILTER_EXPR="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL_MODE=true
                shift
                ;;
            -m|--max)
                if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ || "$2" -eq 0 ]]; then
                    log_error "Option -m requires a positive integer"
                    exit 1
                fi
                MAX_PARALLEL="$2"
                shift 2
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$SCRIPT_TO_EXEC" ]]; then
                    SCRIPT_TO_EXEC="$1"
                    shift
                else
                    log_error "Too many arguments"
                    show_usage
                    exit 1
                fi
                ;;
        esac
    done
    
    if [[ -z "$SCRIPT_TO_EXEC" ]]; then
        log_error "Missing required argument: script"
        show_usage
        exit 1
    fi
}

# === Main Script ===

main() {
    init_logging "$SCRIPT_NAME"
    
    # Check dependencies
    if ! command -v jq &>/dev/null; then
        log_error "jq is required but not installed. Install with: sudo apt install jq"
        exit 1
    fi
    
    log_info "Starting $SCRIPT_NAME"
    
    ensure_state_dir "$STATE_DIR"
    
    # Verify ssh-inventory exists
    if [[ ! -f "$SSH_INVENTORY" ]]; then
        log_error "SSH inventory not found at $SSH_INVENTORY"
        log_error "Run ssh-inventory.sh first"
        exit 1
    fi
    
    # Parse command-line arguments
    parse_args "$@"
    
    # Load inventory and apply filter
    local inventory=$(load_inventory)
    local filtered=$(filter_hosts "$inventory" "$FILTER_EXPR")
    
    local host_count=$(echo "$filtered" | jq 'length')
    log_info "Selected $host_count hosts"
    
    if [[ $host_count -eq 0 ]]; then
        log_warn "No hosts match filter"
        exit 0
    fi
    
    # Execute
    local results
    if [[ "$PARALLEL_MODE" == "true" ]]; then
        results=$(execute_parallel "$filtered" "$SCRIPT_TO_EXEC" "Orchestrated execution" "$MAX_PARALLEL")
    else
        results=$(execute_on_hosts "$filtered" "$SCRIPT_TO_EXEC" "Orchestrated execution")
    fi
    
    # Write results
    echo "$results" | jq '.' > "$JSON_FILE"
    update_latest_link "$JSON_FILE" "$LATEST_LINK"
    
    # Show summary
    summarize_results "$results"
    
    # Cleanup old state
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"
    
    log_success "$SCRIPT_NAME completed successfully"
}

main "$@"
