#!/bin/bash
# Script Name: docker-inventory.sh
# Purpose: Inventory Docker containers across all hosts with detailed information
# Output: JSON state file to ~/memory/bank/docker/
# Cron: 0 * * * * (hourly)

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

# Shared directory with other Docker monitoring scripts
STATE_DIR="${STATE_DIR:-$HOME/memory/bank/docker}"
FILE_PREFIX="inventory"  # Prefix to avoid collisions with docker-cache-monitor

# SSH Inventory path
SSH_INVENTORY_FILE="${SSH_INVENTORY_FILE:-$HOME/memory/bank/ssh/latest.json}"

# Timestamps
TIMESTAMP=$(date +%s)
JSON_FILE="$STATE_DIR/${FILE_PREFIX}-${TIMESTAMP}.json"
LATEST_LINK="$STATE_DIR/${FILE_PREFIX}-latest.json"
CURRENT_MD="$STATE_DIR/${FILE_PREFIX}-latest.md"

# Retention (configurable via environment)
STATE_RETENTION="${STATE_RETENTION:-168}"  # Keep last 168 files (7 days hourly)

# Enable Gotify notifications by default (with graceful degradation)
export CRONJOB_NOTIFY_METHOD="${CRONJOB_NOTIFY_METHOD:-gotify}"

# Source shared libraries
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/notify.sh"
source "$REPO_ROOT/lib/state.sh"
source "$REPO_ROOT/lib/remote-exec.sh"

# === Cleanup ===
trap 'log_error "Script failed on line $LINENO"' ERR
trap 'cleanup' EXIT

cleanup() {
    # Clean up any temporary files
    rm -f /tmp/docker-inventory-*.json 2>/dev/null || true
}

# === Dependency Check ===
check_dependencies() {
    local missing=()
    
    for cmd in jq ssh; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if (( ${#missing[@]} > 0 )); then
        log_error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

# === Functions ===

# Get list of Docker hosts from ssh-inventory or fall back to SSH config
get_docker_hosts() {
    local -a hosts=()
    
    # Try to read from ssh-inventory first
    if [[ -f "$SSH_INVENTORY_FILE" ]]; then
        log_info "Reading Docker hosts from ssh-inventory"
        
        # Extract hosts where docker.has_docker == true
        # ssh-inventory structure: [{hostname, docker: {has_docker, version}, ...}, ...]
        local inventory_hosts
        inventory_hosts=$(jq -r '
            .[] | 
            select(.docker.has_docker == true) | 
            .hostname
        ' "$SSH_INVENTORY_FILE" 2>/dev/null || echo "")
        
        if [[ -n "$inventory_hosts" ]]; then
            while IFS= read -r host; do
                [[ -n "$host" ]] && hosts+=("$host")
            done <<< "$inventory_hosts"
        fi
    fi
    
    # Fall back to SSH config if no ssh-inventory or no Docker hosts found
    if (( ${#hosts[@]} == 0 )); then
        log_warn "No ssh-inventory found or no Docker hosts in inventory, falling back to SSH config"
        
        # Check each SSH host for Docker
        for host in $(get_ssh_hosts); do
            [[ -z "$host" ]] && continue
            
            # Test if Docker is available (use -n to not consume stdin)
            if timeout 10 ssh -n $SSH_OPTIONS "$host" "command -v docker" &>/dev/null; then
                hosts+=("$host")
            fi
        done
    fi
    
    # Always include localhost if Docker is available
    if command -v docker &>/dev/null; then
        # Check if localhost is already in the list
        local has_localhost=false
        for h in "${hosts[@]}"; do
            [[ "$h" == "localhost" ]] && has_localhost=true && break
        done
        [[ "$has_localhost" == "false" ]] && hosts=("localhost" "${hosts[@]}")
    fi
    
    printf '%s\n' "${hosts[@]}"
}

# Get container details via docker inspect
# Args: $1 = host, $2 = container ID
get_container_details() {
    local host="$1"
    local container_id="$2"
    local SSH_CMD=""
    
    # Use -n to prevent SSH from consuming stdin (important when called inside while read loops)
    [[ "$host" != "localhost" ]] && SSH_CMD="ssh -n $SSH_OPTIONS $host"
    
    # Get full container inspect output
    local inspect_json
    if ! inspect_json=$(timeout 30 $SSH_CMD docker inspect "$container_id" 2>/dev/null); then
        echo "{}"
        return
    fi
    
    # Parse the inspect output with jq
    # Note: Docker timestamps include nanoseconds (.123456789Z) which jq's fromdateiso8601 can't parse,
    # so we strip them first with sub("\\.[0-9]+Z$"; "Z")
    echo "$inspect_json" | jq -c '.[0] | {
        name: (.Name | ltrimstr("/")),
        image: .Config.Image,
        state: .State.Status,
        status: (
            if .State.Status == "running" then
                "Up " + (
                    (now - (.State.StartedAt | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)) / 86400 | floor | tostring
                ) + " days"
            elif .State.Status == "exited" then
                "Exited (" + (.State.ExitCode | tostring) + ")"
            elif .State.Status == "restarting" then
                "Restarting (" + (.RestartCount | tostring) + " times)"
            else
                .State.Status
            end
        ),
        exit_code: .State.ExitCode,
        restart_count: .RestartCount,
        created: .Created,
        started_at: .State.StartedAt,
        volumes: [
            .Mounts[]? | {
                source: .Source,
                destination: .Destination,
                type: .Type,
                mode: .Mode
            }
        ],
        networks: (
            .NetworkSettings.Networks | to_entries | map({
                (.key): .value.IPAddress
            }) | add // {}
        ),
        ports: [
            .NetworkSettings.Ports | to_entries[]? | 
            select(.value != null) |
            .value[]? as $binding |
            {
                container: (.key | split("/")[0]),
                protocol: (.key | split("/")[1]),
                host: ($binding.HostPort // "")
            } | select(.host != "")
        ],
        compose_project: (.Config.Labels["com.docker.compose.project.working_dir"] // null),
        compose_service: (.Config.Labels["com.docker.compose.service"] // null)
    }' 2>/dev/null || echo "{}"
}

# Collect all containers from a single host
# Args: $1 = hostname
collect_host_containers() {
    local host="$1"
    local SSH_CMD=""
    
    # Use -n to prevent SSH from consuming stdin (important when called inside while read loops)
    [[ "$host" != "localhost" ]] && SSH_CMD="ssh -n $SSH_OPTIONS $host"
    
    # Test Docker availability
    if ! timeout 10 $SSH_CMD docker info &>/dev/null; then
        log_warn "Docker not available on $host"
        jq -n --arg host "$host" '{
            status: "unavailable",
            error: "Docker not available",
            containers: {running: [], stopped: [], restarting: []},
            summary: {total: 0, running: 0, stopped: 0, restarting: 0}
        }'
        return
    fi
    
    # Get all container IDs
    local container_ids
    container_ids=$(timeout 30 $SSH_CMD docker ps -aq 2>/dev/null || echo "")
    
    if [[ -z "$container_ids" ]]; then
        log_info "No containers on $host"
        jq -n '{
            status: "ok",
            containers: {running: [], stopped: [], restarting: []},
            summary: {total: 0, running: 0, stopped: 0, restarting: 0}
        }'
        return
    fi
    
    local -a running=()
    local -a stopped=()
    local -a restarting=()
    
    # Get details for each container
    while IFS= read -r cid; do
        [[ -z "$cid" ]] && continue
        
        local details
        details=$(get_container_details "$host" "$cid")
        
        [[ -z "$details" || "$details" == "{}" ]] && continue
        
        local state
        state=$(echo "$details" | jq -r '.state // "unknown"')
        
        case "$state" in
            running)
                running+=("$details")
                ;;
            exited|dead|created)
                stopped+=("$details")
                ;;
            restarting)
                restarting+=("$details")
                ;;
            *)
                log_debug "Unknown container state: $state"
                stopped+=("$details")
                ;;
        esac
    done <<< "$container_ids"
    
    # Build JSON output
    local running_json="[]"
    local stopped_json="[]"
    local restarting_json="[]"
    
    (( ${#running[@]} > 0 )) && running_json=$(printf '%s\n' "${running[@]}" | jq -s '.')
    (( ${#stopped[@]} > 0 )) && stopped_json=$(printf '%s\n' "${stopped[@]}" | jq -s '.')
    (( ${#restarting[@]} > 0 )) && restarting_json=$(printf '%s\n' "${restarting[@]}" | jq -s '.')
    
    local total=$((${#running[@]} + ${#stopped[@]} + ${#restarting[@]}))
    
    jq -n \
        --argjson running "$running_json" \
        --argjson stopped "$stopped_json" \
        --argjson restarting "$restarting_json" \
        --argjson total "$total" \
        --argjson running_count "${#running[@]}" \
        --argjson stopped_count "${#stopped[@]}" \
        --argjson restarting_count "${#restarting[@]}" \
        '{
            status: "ok",
            containers: {
                running: $running,
                stopped: $stopped,
                restarting: $restarting
            },
            summary: {
                total: $total,
                running: $running_count,
                stopped: $stopped_count,
                restarting: $restarting_count
            }
        }'
}

# Collect data from all Docker hosts
collect_data() {
    local -a hosts_data=()
    local -a errors=()
    
    local total_hosts=0
    local total_containers=0
    local total_running=0
    local total_stopped=0
    local total_restarting=0
    
    # Get Docker hosts
    local docker_hosts
    docker_hosts=$(get_docker_hosts)
    
    if [[ -z "$docker_hosts" ]]; then
        log_error "No Docker hosts found"
        jq -n '{
            hosts: {},
            summary: {
                total_hosts: 0,
                total_containers: 0,
                total_running: 0,
                total_stopped: 0,
                total_restarting: 0
            },
            errors: ["No Docker hosts found"]
        }'
        return
    fi
    
    # Process each host
    while IFS= read -r host; do
        [[ -z "$host" ]] && continue
        
        log_info "Collecting containers from $host..."
        
        local host_data
        if ! host_data=$(collect_host_containers "$host"); then
            log_error "Failed to collect from $host"
            errors+=("$host: Collection failed")
            host_data=$(jq -n --arg host "$host" '{
                status: "error",
                error: "Collection failed",
                containers: {running: [], stopped: [], restarting: []},
                summary: {total: 0, running: 0, stopped: 0, restarting: 0}
            }')
        fi
        
        # Add to hosts data
        hosts_data+=("$(jq -n --arg host "$host" --argjson data "$host_data" '{ ($host): $data }')")
        
        # Update totals
        local host_status
        host_status=$(echo "$host_data" | jq -r '.status')
        
        if [[ "$host_status" == "ok" ]]; then
            ((total_hosts++)) || true
            ((total_containers += $(echo "$host_data" | jq -r '.summary.total'))) || true
            ((total_running += $(echo "$host_data" | jq -r '.summary.running'))) || true
            ((total_stopped += $(echo "$host_data" | jq -r '.summary.stopped'))) || true
            ((total_restarting += $(echo "$host_data" | jq -r '.summary.restarting'))) || true
        else
            errors+=("$host: $host_status")
        fi
        
    done <<< "$docker_hosts"
    
    # Combine all host data - write to temp file to avoid arg list too long
    local hosts_tmp="/tmp/docker-inventory-hosts-$$.json"
    if (( ${#hosts_data[@]} > 0 )); then
        printf '%s\n' "${hosts_data[@]}" | jq -s 'add' > "$hosts_tmp"
    else
        echo '{}' > "$hosts_tmp"
    fi
    
    # Build errors array
    local errors_tmp="/tmp/docker-inventory-errors-$$.json"
    if (( ${#errors[@]} > 0 )); then
        printf '%s\n' "${errors[@]}" | jq -R -s 'split("\n") | map(select(. != ""))' > "$errors_tmp"
    else
        echo '[]' > "$errors_tmp"
    fi
    
    # Return final data structure - use --slurpfile to avoid arg list too long
    jq -n \
        --slurpfile hosts "$hosts_tmp" \
        --slurpfile errors "$errors_tmp" \
        --argjson total_hosts "$total_hosts" \
        --argjson total_containers "$total_containers" \
        --argjson total_running "$total_running" \
        --argjson total_stopped "$total_stopped" \
        --argjson total_restarting "$total_restarting" \
        '{
            hosts: $hosts[0],
            summary: {
                total_hosts: $total_hosts,
                total_containers: $total_containers,
                total_running: $total_running,
                total_stopped: $total_stopped,
                total_restarting: $total_restarting
            },
            errors: $errors[0]
        }'
    
    # Clean up temp files
    rm -f "$hosts_tmp" "$errors_tmp" 2>/dev/null || true
}

# Generate markdown inventory from JSON data
generate_markdown_inventory() {
    local data="$1"
    local generated_date
    generated_date=$(date '+%Y-%m-%d %H:%M %Z')
    
    # Header
    cat <<EOF
# Docker Container Inventory
Generated: $generated_date

## Summary
EOF
    
    # Summary stats
    local total_hosts total_containers total_running total_stopped total_restarting
    total_hosts=$(echo "$data" | jq -r '.summary.total_hosts')
    total_containers=$(echo "$data" | jq -r '.summary.total_containers')
    total_running=$(echo "$data" | jq -r '.summary.total_running')
    total_stopped=$(echo "$data" | jq -r '.summary.total_stopped')
    total_restarting=$(echo "$data" | jq -r '.summary.total_restarting')
    
    cat <<EOF
- **Total Hosts:** $total_hosts
- **Total Containers:** $total_containers ($total_running running, $total_stopped stopped, $total_restarting restarting)

EOF
    
    # Check for errors
    local error_count
    error_count=$(echo "$data" | jq -r '.errors | length')
    if (( error_count > 0 )); then
        echo "### ⚠️ Errors"
        echo ""
        echo "$data" | jq -r '.errors[] | "- " + .'
        echo ""
    fi
    
    echo "---"
    echo ""
    
    # Per-host details
    echo "$data" | jq -r '.hosts | to_entries[] | .key' | while IFS= read -r host; do
        [[ -z "$host" ]] && continue
        
        local host_data
        host_data=$(echo "$data" | jq --arg h "$host" '.hosts[$h]')
        
        local host_status host_total
        host_status=$(echo "$host_data" | jq -r '.status')
        host_total=$(echo "$host_data" | jq -r '.summary.total')
        
        echo "## $host ($host_total containers)"
        echo ""
        
        if [[ "$host_status" != "ok" ]]; then
            local host_error
            host_error=$(echo "$host_data" | jq -r '.error // "Unknown error"')
            echo "⚠️ **Status:** $host_status - $host_error"
            echo ""
            continue
        fi
        
        # Running containers
        local running_count
        running_count=$(echo "$host_data" | jq -r '.summary.running')
        
        if (( running_count > 0 )); then
            echo "### Running ($running_count)"
            echo ""
            
            echo "$host_data" | jq -r '.containers.running[] | 
                "- **\(.name)** (\(.image))\n" +
                (if .ports | length > 0 then
                    "  - Ports: " + ([.ports[] | "\(.host):\(.container)/\(.protocol)"] | join(", ")) + "\n"
                else "" end) +
                (if .volumes | length > 0 then
                    "  - Volumes: " + ([.volumes[] | "\(.source) → \(.destination)"] | join(", ")) + "\n"
                else "" end) +
                (if .compose_project then
                    "  - Compose: \(.compose_project)\n"
                else "" end) +
                (if (.networks | length > 0) then
                    "  - IP: " + ([.networks | to_entries[] | "\(.key)=\(.value)"] | join(", ")) + "\n"
                else "" end)'
            echo ""
        fi
        
        # Stopped containers
        local stopped_count
        stopped_count=$(echo "$host_data" | jq -r '.summary.stopped')
        
        if (( stopped_count > 0 )); then
            echo "### Stopped ($stopped_count)"
            echo ""
            
            echo "$host_data" | jq -r '.containers.stopped[] | 
                "- **\(.name)** (\(.image)) - Exit code: \(.exit_code // "N/A")"'
            echo ""
        fi
        
        # Restarting containers
        local restarting_count
        restarting_count=$(echo "$host_data" | jq -r '.summary.restarting')
        
        if (( restarting_count > 0 )); then
            echo "### ⚠️ Restarting ($restarting_count)"
            echo ""
            
            echo "$host_data" | jq -r '.containers.restarting[] | 
                "- **\(.name)** (\(.image)) - Restart count: \(.restart_count // 0)"'
            echo ""
        fi
        
        echo "---"
        echo ""
    done
}

# === Main Script ===

main() {
    # Initialize logging (enables log rotation)
    init_logging "$SCRIPT_NAME"
    
    log_info "Starting $SCRIPT_NAME"
    
    # Check dependencies
    check_dependencies
    
    # Ensure state directory exists
    ensure_state_dir "$STATE_DIR"
    
    # Collect data from all hosts
    log_info "Collecting Docker container inventory..."
    local data
    if ! data=$(collect_data); then
        log_error "Data collection failed"
        notify_alert "Docker Inventory Error" "Failed to collect container inventory" "high"
        exit 1
    fi
    
    # 1. Write JSON state file (timestamped)
    # Use temp file to avoid "Argument list too long" with large data
    local data_tmp="/tmp/docker-inventory-data-$$.json"
    echo "$data" > "$data_tmp"
    
    jq -n \
        --argjson timestamp "$TIMESTAMP" \
        --arg script "$SCRIPT_NAME" \
        --slurpfile data "$data_tmp" \
        --arg hostname "$(hostname)" \
        --argjson exec_time "$(($(date +%s) - TIMESTAMP))" \
        '{
            timestamp: $timestamp,
            script: $script,
            data: $data[0],
            metadata: {
                hostname: $hostname,
                execution_time: "\($exec_time)s"
            }
        }' > "$JSON_FILE"
    
    rm -f "$data_tmp" 2>/dev/null || true
    
    log_info "JSON state saved to: $JSON_FILE"
    
    # 2. Update 'latest' symlink (relative path)
    ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"
    
    # 3. Generate markdown inventory (human-readable)
    generate_markdown_inventory "$data" > "$CURRENT_MD"
    log_info "Markdown inventory saved to: $CURRENT_MD"
    
    # 4. Clean up old state files (keep per retention policy)
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"
    
    # 5. Check for issues and notify
    local error_count restarting_count
    error_count=$(echo "$data" | jq -r '.errors | length')
    restarting_count=$(echo "$data" | jq -r '.summary.total_restarting')
    
    if (( error_count > 0 )); then
        local error_msg
        error_msg=$(echo "$data" | jq -r '.errors | join("\n")')
        notify_alert "Docker Inventory: $error_count host errors" "$error_msg" "high"
        log_warn "$error_count host errors during collection"
    fi
    
    if (( restarting_count > 0 )); then
        local restart_msg
        restart_msg=$(echo "$data" | jq -r '
            [.hosts | to_entries[] | 
             select(.value.summary.restarting > 0) |
             "\(.key): " + ([.value.containers.restarting[].name] | join(", "))] | 
            join("\n")')
        notify_alert "Docker Inventory: $restarting_count containers restarting" "$restart_msg" "normal"
        log_warn "$restarting_count containers in restarting state"
    fi
    
    # Summary
    local total_hosts total_containers total_running
    total_hosts=$(echo "$data" | jq -r '.summary.total_hosts')
    total_containers=$(echo "$data" | jq -r '.summary.total_containers')
    total_running=$(echo "$data" | jq -r '.summary.total_running')
    
    log_success "$SCRIPT_NAME completed: $total_hosts hosts, $total_containers containers ($total_running running)"
}

# Run main function
main "$@"
