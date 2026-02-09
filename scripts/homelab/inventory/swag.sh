#!/bin/bash
# SWAG Inventory - Reverse Proxy Configuration Scanner
# Purpose: Inventory all SWAG reverse proxy .conf files across hosts
# Output: JSON state + Markdown inventory
# Cron: 0 * * * * (hourly)

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

# Source shared libraries
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/notify.sh"
source "$REPO_ROOT/lib/state.sh"
source "$REPO_ROOT/lib/remote-exec.sh"

# SSH Inventory file (if available)
SSH_INVENTORY="${SSH_INVENTORY:-$HOME/memory/bank/ssh/latest.json}"

# === Cleanup ===
trap 'log_error "Script failed on line $LINENO"' ERR
trap 'cleanup' EXIT

cleanup() {
    rm -f /tmp/swag-*.tmp 2>/dev/null || true
}

# === Dependency Check ===
check_dependencies() {
    local missing=()
    for cmd in jq grep sed stat; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

# === SWAG Discovery Functions ===

# Get list of SSH hosts from config
get_ssh_hosts() {
    if [[ -f "$HOME/.ssh/config" ]]; then
        grep -E "^Host " "$HOME/.ssh/config" | awk '{print $2}' | grep -v '\*' | sort -u
    fi
}

# Find SWAG container and volume on a host
# Returns JSON: { "found": true/false, "container": "name", "volume": "/path/to/config" }
find_swag_on_host() {
    local host="$1"
    local ssh_cmd=""
    
    if [[ "$host" != "localhost" ]]; then
        ssh_cmd="ssh $SSH_OPTIONS $host"
    fi
    
    # Check if Docker is available
    if ! $ssh_cmd docker info &>/dev/null 2>&1; then
        echo '{"found": false, "error": "docker_unavailable"}'
        return
    fi
    
    # Look for SWAG container (common names: swag, letsencrypt)
    local container_name
    container_name=$($ssh_cmd docker ps -a --format '{{.Names}}' 2>/dev/null | grep -iE '^(swag|letsencrypt)$' | head -1 || echo "")
    
    if [[ -z "$container_name" ]]; then
        echo '{"found": false, "error": "no_swag_container"}'
        return
    fi
    
    # Get /config volume source
    local volume_source
    volume_source=$($ssh_cmd docker inspect "$container_name" 2>/dev/null | \
        jq -r '.[0].Mounts[] | select(.Destination == "/config") | .Source' 2>/dev/null || echo "")
    
    if [[ -z "$volume_source" ]]; then
        echo "{\"found\": true, \"container\": \"$container_name\", \"error\": \"no_config_volume\"}"
        return
    fi
    
    jq -n \
        --arg container "$container_name" \
        --arg volume "$volume_source" \
        '{found: true, container: $container, volume: $volume}'
}

# Try to get SWAG info from ssh-inventory first
get_swag_from_inventory() {
    if [[ ! -f "$SSH_INVENTORY" ]]; then
        return 1
    fi
    
    # Parse ssh-inventory for hosts with swag_container == true
    jq -r '.data.hosts | to_entries[] | 
        select(.value.capabilities.swag_container == true) |
        {
            host: .key,
            container: .value.capabilities.swag_container_name,
            volumes: .value.capabilities.swag_volumes
        } | @json' "$SSH_INVENTORY" 2>/dev/null || return 1
}

# === Config Parsing Functions ===

# Parse a single .conf file and return JSON
# Args: $1=host, $2=conf_file_path
parse_conf_file() {
    local host="$1"
    local conf_path="$2"
    local ssh_opts="-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
    
    # Get filename
    local filename
    filename=$(basename "$conf_path")
    
    # Skip .conf.sample files
    if [[ "$filename" == *.conf.sample ]]; then
        return 0
    fi
    
    # Determine type from filename
    local conf_type="custom"
    if [[ "$filename" == *.subdomain.conf ]]; then
        conf_type="subdomain"
    elif [[ "$filename" == *.subfolder.conf ]]; then
        conf_type="subfolder"
    fi
    
    # Read file content (avoid stdin conflicts by using -n for SSH)
    local content
    if [[ "$host" != "localhost" ]]; then
        content=$(ssh -n $ssh_opts "$host" "cat '$conf_path'" 2>/dev/null || echo "")
    else
        content=$(cat "$conf_path" 2>/dev/null || echo "")
    fi
    
    if [[ -z "$content" ]]; then
        log_warn "Could not read: $conf_path on $host"
        return 0
    fi
    
    # Extract server_name(s) - can be on multiple lines or space-separated
    local server_names
    server_names=$(echo "$content" | grep -oP '(?<=server_name\s)[\w\.\*\-\s]+(?=;)' 2>/dev/null | \
        tr '\n' ' ' | sed 's/\s\+/ /g; s/^ //; s/ $//' | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ $//')
    
    # Fallback: try different grep pattern
    if [[ -z "$server_names" ]]; then
        server_names=$(echo "$content" | grep "server_name" | head -1 | \
            sed 's/.*server_name\s*//; s/;.*//' | tr '\n' ' ' | sed 's/\s\+/ /g; s/^ //; s/ $//')
    fi
    
    # Extract listen ports (unique)
    local listen_ports
    listen_ports=$(echo "$content" | grep -oP '(?<=listen\s)\d+' 2>/dev/null | sort -un | tr '\n' ' ' | sed 's/ $//' || echo "")
    
    # Extract proxy_pass target (primary one)
    local proxy_target
    proxy_target=$(echo "$content" | grep -oP '(?<=proxy_pass\s)[^;]+' 2>/dev/null | head -1 | sed 's/\s*$//' || echo "")
    
    # Fallback for proxy_pass
    if [[ -z "$proxy_target" ]]; then
        proxy_target=$(echo "$content" | grep "proxy_pass" | head -1 | \
            sed 's/.*proxy_pass\s*//; s/;.*//' | sed 's/\s*$//')
    fi
    
    # Resolve nginx variables ($upstream_app, $upstream_port, $upstream_proto)
    # SWAG configs use: set $upstream_app <value>; etc.
    if [[ "$proxy_target" == *'$upstream'* ]]; then
        local upstream_app upstream_port upstream_proto
        upstream_app=$(echo "$content" | grep -oP '(?<=set \$upstream_app )[^;]+' 2>/dev/null | head -1 || echo "")
        upstream_port=$(echo "$content" | grep -oP '(?<=set \$upstream_port )[^;]+' 2>/dev/null | head -1 || echo "")
        upstream_proto=$(echo "$content" | grep -oP '(?<=set \$upstream_proto )[^;]+' 2>/dev/null | head -1 || echo "")
        
        # Substitute variables if we found values
        [[ -n "$upstream_app" ]] && proxy_target="${proxy_target//\$upstream_app/$upstream_app}"
        [[ -n "$upstream_port" ]] && proxy_target="${proxy_target//\$upstream_port/$upstream_port}"
        [[ -n "$upstream_proto" ]] && proxy_target="${proxy_target//\$upstream_proto/$upstream_proto}"
    fi
    
    # Check for SSL
    local ssl_enabled="false"
    if echo "$content" | grep -qE "(ssl_certificate|listen.*ssl)" 2>/dev/null; then
        ssl_enabled="true"
    fi
    
    # Check for authentication
    local auth_enabled="false"
    local auth_type=""
    if echo "$content" | grep -q "authelia" 2>/dev/null; then
        auth_enabled="true"
        auth_type="authelia"
    elif echo "$content" | grep -q "auth_basic" 2>/dev/null; then
        auth_enabled="true"
        auth_type="basic"
    fi
    
    # Get last modified time
    local last_modified
    if [[ "$host" != "localhost" ]]; then
        last_modified=$(ssh -n $ssh_opts "$host" "stat -c '%Y' '$conf_path'" 2>/dev/null || echo "0")
    else
        last_modified=$(stat -c '%Y' "$conf_path" 2>/dev/null || echo "0")
    fi
    local last_modified_iso
    last_modified_iso=$(date -d "@$last_modified" --iso-8601=seconds 2>/dev/null || echo "unknown")
    
    # Convert server_names to JSON array
    local server_names_json="[]"
    if [[ -n "$server_names" ]]; then
        server_names_json=$(echo "$server_names" | tr ' ' '\n' | grep -v '^$' | jq -R . | jq -s '.')
    fi
    
    # Convert listen_ports to JSON array of numbers
    local listen_ports_json="[]"
    if [[ -n "$listen_ports" ]]; then
        listen_ports_json=$(echo "$listen_ports" | tr ' ' '\n' | grep -v '^$' | jq -R 'tonumber' 2>/dev/null | jq -s '.' || echo "[]")
    fi
    
    # Build JSON object
    jq -n \
        --arg filename "$filename" \
        --argjson server_names "$server_names_json" \
        --arg type "$conf_type" \
        --argjson listen_ports "$listen_ports_json" \
        --arg proxy_target "$proxy_target" \
        --argjson ssl_enabled "$ssl_enabled" \
        --argjson auth_enabled "$auth_enabled" \
        --arg auth_type "$auth_type" \
        --arg last_modified "$last_modified_iso" \
        '{
            filename: $filename,
            server_names: $server_names,
            type: $type,
            listen_ports: $listen_ports,
            proxy_target: $proxy_target,
            ssl_enabled: $ssl_enabled,
            auth_enabled: $auth_enabled,
            auth_type: (if $auth_type == "" then null else $auth_type end),
            last_modified: $last_modified
        }'
}

# Scan all .conf files in a SWAG proxy-confs directory
# Args: $1=host, $2=swag_volume
scan_swag_configs() {
    local host="$1"
    local swag_volume="$2"
    local proxy_confs_dir="${swag_volume}/nginx/proxy-confs"
    local ssh_opts="-n -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
    
    # Check if directory exists
    local dir_exists
    if [[ "$host" != "localhost" ]]; then
        dir_exists=$(ssh $ssh_opts "$host" "test -d '$proxy_confs_dir' && echo yes || echo no" 2>/dev/null)
    else
        dir_exists=$(test -d "$proxy_confs_dir" && echo yes || echo no)
    fi
    
    if [[ "$dir_exists" != "yes" ]]; then
        log_warn "Proxy confs directory not found: $proxy_confs_dir on $host"
        echo "[]"
        return
    fi
    
    # Find all .conf files (excluding .conf.sample) and save to temp file
    local conf_files_tmp
    conf_files_tmp=$(mktemp /tmp/swag-confs-XXXXXX.tmp)
    if [[ "$host" != "localhost" ]]; then
        ssh $ssh_opts "$host" "find '$proxy_confs_dir' -maxdepth 1 -type f -name '*.conf' ! -name '*.conf.sample'" 2>/dev/null | sort > "$conf_files_tmp"
    else
        find "$proxy_confs_dir" -maxdepth 1 -type f -name "*.conf" ! -name "*.conf.sample" 2>/dev/null | sort > "$conf_files_tmp"
    fi
    
    if [[ ! -s "$conf_files_tmp" ]]; then
        log_info "No .conf files found in $proxy_confs_dir on $host"
        rm -f "$conf_files_tmp"
        echo "[]"
        return
    fi
    
    local file_count
    file_count=$(wc -l < "$conf_files_tmp")
    log_info "Found $file_count .conf files in $proxy_confs_dir"
    
    # Parse each config file using a for loop to avoid stdin issues
    local configs=()
    while IFS= read -r conf_file <&3; do
        [[ -z "$conf_file" ]] && continue
        
        log_debug "Parsing: $conf_file"
        local config_json
        config_json=$(parse_conf_file "$host" "$conf_file")
        
        if [[ -n "$config_json" ]]; then
            configs+=("$config_json")
        fi
    done 3< "$conf_files_tmp"
    
    rm -f "$conf_files_tmp"
    
    # Combine into JSON array
    if [[ ${#configs[@]} -gt 0 ]]; then
        printf '%s\n' "${configs[@]}" | jq -s '.'
    else
        echo "[]"
    fi
}

# === Main Collection Logic ===

collect_all_swag_data() {
    local -A hosts_data=()
    local total_hosts=0
    local total_configs=0
    local ssl_count=0
    local auth_count=0
    
    # First, try to get hosts from ssh-inventory
    local inventory_hosts=()
    if [[ -f "$SSH_INVENTORY" ]]; then
        log_info "Reading SWAG hosts from ssh-inventory..."
        while IFS= read -r host_json; do
            [[ -z "$host_json" ]] && continue
            inventory_hosts+=("$host_json")
        done < <(get_swag_from_inventory)
    fi
    
    # If no inventory, discover SWAG hosts via SSH
    if [[ ${#inventory_hosts[@]} -eq 0 ]]; then
        log_info "ssh-inventory not available, discovering SWAG hosts via SSH..."
        
        local hosts
        hosts=$(get_ssh_hosts)
        
        for host in $hosts localhost; do
            log_debug "Checking $host for SWAG..."
            
            local swag_info
            swag_info=$(find_swag_on_host "$host" 2>/dev/null || echo '{"found": false}')
            
            local found
            found=$(echo "$swag_info" | jq -r '.found')
            
            if [[ "$found" == "true" ]]; then
                local container volume
                container=$(echo "$swag_info" | jq -r '.container')
                volume=$(echo "$swag_info" | jq -r '.volume')
                
                log_info "Found SWAG on $host: container=$container, volume=$volume"
                
                # Scan configs
                local configs_json
                configs_json=$(scan_swag_configs "$host" "$volume")
                
                local config_count
                config_count=$(echo "$configs_json" | jq 'length')
                
                # Count SSL and Auth enabled
                local host_ssl_count host_auth_count
                host_ssl_count=$(echo "$configs_json" | jq '[.[] | select(.ssl_enabled == true)] | length')
                host_auth_count=$(echo "$configs_json" | jq '[.[] | select(.auth_enabled == true)] | length')
                
                # Build host data
                hosts_data["$host"]=$(jq -n \
                    --arg container "$container" \
                    --arg volume "$volume" \
                    --arg proxy_confs_dir "${volume}/nginx/proxy-confs" \
                    --argjson configs "$configs_json" \
                    --argjson total_configs "$config_count" \
                    '{
                        swag_container: $container,
                        swag_volume: $volume,
                        proxy_confs_dir: $proxy_confs_dir,
                        configs: $configs,
                        total_configs: $total_configs
                    }')
                
                ((total_hosts++))
                ((total_configs += config_count))
                ((ssl_count += host_ssl_count))
                ((auth_count += host_auth_count))
            fi
        done
    else
        # Process inventory hosts
        for host_json in "${inventory_hosts[@]}"; do
            local host container volumes
            host=$(echo "$host_json" | jq -r '.host')
            container=$(echo "$host_json" | jq -r '.container // "swag"')
            
            # Find /config volume from volumes array
            local volume
            volume=$(echo "$host_json" | jq -r '.volumes[] | select(.Destination == "/config") | .Source' 2>/dev/null || echo "")
            
            if [[ -z "$volume" ]]; then
                log_warn "No /config volume found for SWAG on $host"
                continue
            fi
            
            log_info "Processing SWAG on $host: volume=$volume"
            
            local configs_json
            configs_json=$(scan_swag_configs "$host" "$volume")
            
            local config_count host_ssl_count host_auth_count
            config_count=$(echo "$configs_json" | jq 'length')
            host_ssl_count=$(echo "$configs_json" | jq '[.[] | select(.ssl_enabled == true)] | length')
            host_auth_count=$(echo "$configs_json" | jq '[.[] | select(.auth_enabled == true)] | length')
            
            hosts_data["$host"]=$(jq -n \
                --arg container "$container" \
                --arg volume "$volume" \
                --arg proxy_confs_dir "${volume}/nginx/proxy-confs" \
                --argjson configs "$configs_json" \
                --argjson total_configs "$config_count" \
                '{
                    swag_container: $container,
                    swag_volume: $volume,
                    proxy_confs_dir: $proxy_confs_dir,
                    configs: $configs,
                    total_configs: $total_configs
                }')
            
            ((total_hosts++))
            ((total_configs += config_count))
            ((ssl_count += host_ssl_count))
            ((auth_count += host_auth_count))
        done
    fi
    
    # Build final hosts object
    local hosts_json="{}"
    for host in "${!hosts_data[@]}"; do
        hosts_json=$(echo "$hosts_json" | jq --arg h "$host" --argjson data "${hosts_data[$host]}" '. + {($h): $data}')
    done
    
    # Build complete data structure
    jq -n \
        --argjson hosts "$hosts_json" \
        --argjson total_hosts "$total_hosts" \
        --argjson total_configs "$total_configs" \
        --argjson ssl_enabled "$ssl_count" \
        --argjson auth_enabled "$auth_count" \
        '{
            hosts: $hosts,
            summary: {
                total_hosts: $total_hosts,
                total_configs: $total_configs,
                ssl_enabled: $ssl_enabled,
                auth_enabled: $auth_enabled
            }
        }'
}

# === Markdown Generation ===

generate_markdown() {
    local data="$1"
    
    local generated_date
    generated_date=$(date "+%Y-%m-%d %H:%M %Z")
    
    local total_hosts total_configs ssl_enabled auth_enabled
    total_hosts=$(echo "$data" | jq -r '.summary.total_hosts')
    total_configs=$(echo "$data" | jq -r '.summary.total_configs')
    ssl_enabled=$(echo "$data" | jq -r '.summary.ssl_enabled')
    auth_enabled=$(echo "$data" | jq -r '.summary.auth_enabled')
    
    cat <<EOF
# SWAG Reverse Proxy Configuration Inventory
Generated: $generated_date

## Summary
- **Total Hosts with SWAG:** $total_hosts
- **Total Proxy Configs:** $total_configs
- **SSL Enabled:** $ssl_enabled 🔒
- **Auth Enabled:** $auth_enabled 🔐

---
EOF
    
    # Process each host
    echo "$data" | jq -r '.hosts | to_entries[] | .key' | while read -r host; do
        local host_data
        host_data=$(echo "$data" | jq -r ".hosts[\"$host\"]")
        
        local swag_volume container config_count proxy_confs_dir
        swag_volume=$(echo "$host_data" | jq -r '.swag_volume')
        container=$(echo "$host_data" | jq -r '.swag_container')
        config_count=$(echo "$host_data" | jq -r '.total_configs')
        proxy_confs_dir=$(echo "$host_data" | jq -r '.proxy_confs_dir')
        
        cat <<EOF

## $host

**Container:** \`$container\`
**SWAG Volume:** \`$swag_volume\`
**Configs Directory:** \`$proxy_confs_dir\`

### Proxy Configurations ($config_count)

EOF
        
        # List each config
        echo "$host_data" | jq -c '.configs[]' | while read -r config; do
            local filename server_names conf_type proxy_target ssl_enabled auth_enabled auth_type last_modified
            filename=$(echo "$config" | jq -r '.filename')
            server_names=$(echo "$config" | jq -r '.server_names | join(", ")')
            conf_type=$(echo "$config" | jq -r '.type')
            proxy_target=$(echo "$config" | jq -r '.proxy_target')
            ssl_enabled=$(echo "$config" | jq -r '.ssl_enabled')
            auth_enabled=$(echo "$config" | jq -r '.auth_enabled')
            auth_type=$(echo "$config" | jq -r '.auth_type // ""')
            last_modified=$(echo "$config" | jq -r '.last_modified' | cut -d'T' -f1,2 | tr 'T' ' ' | cut -c1-16)
            
            local ssl_icon="❌"
            local auth_icon="❌"
            [[ "$ssl_enabled" == "true" ]] && ssl_icon="✅"
            if [[ "$auth_enabled" == "true" ]]; then
                if [[ -n "$auth_type" && "$auth_type" != "null" ]]; then
                    auth_icon="✅ ($auth_type)"
                else
                    auth_icon="✅"
                fi
            fi
            
            cat <<EOF
#### 🌐 $filename
- **Domains:** $server_names
- **Type:** ${conf_type^}
- **Target:** \`$proxy_target\`
- **SSL:** $ssl_icon | **Auth:** $auth_icon
- **Last Modified:** $last_modified

EOF
        done
    done
}

# === Change Detection ===

detect_changes() {
    local new_data="$1"
    
    # Get previous state
    if [[ ! -L "$LATEST_LINK" ]]; then
        echo "first_run"
        return
    fi
    
    local old_file
    old_file=$(readlink -f "$LATEST_LINK" 2>/dev/null || echo "")
    
    if [[ ! -f "$old_file" ]]; then
        echo "first_run"
        return
    fi
    
    # Compare config counts
    local old_count new_count
    old_count=$(jq -r '.data.summary.total_configs' "$old_file" 2>/dev/null || echo "0")
    new_count=$(echo "$new_data" | jq -r '.summary.total_configs')
    
    if [[ "$new_count" -gt "$old_count" ]]; then
        local diff=$((new_count - old_count))
        echo "added:$diff"
    elif [[ "$new_count" -lt "$old_count" ]]; then
        local diff=$((old_count - new_count))
        echo "removed:$diff"
    else
        echo "unchanged"
    fi
}

# === Main ===

main() {
    # Initialize logging
    init_logging "$SCRIPT_NAME"
    
    log_info "Starting $SCRIPT_NAME"
    
    # Check dependencies
    check_dependencies
    
    # Ensure state directory exists
    ensure_state_dir "$STATE_DIR"
    
    # Collect all SWAG data
    log_info "Scanning for SWAG reverse proxy configurations..."
    local data
    data=$(collect_all_swag_data)
    
    # Check for changes
    local change_status
    change_status=$(detect_changes "$data")
    
    # Write JSON state file
    local execution_time=$(($(date +%s) - TIMESTAMP))
    cat > "$JSON_FILE" <<EOF
{
  "timestamp": $TIMESTAMP,
  "script": "$SCRIPT_NAME",
  "data": $data,
  "metadata": {
    "hostname": "$(hostname)",
    "execution_time": "${execution_time}s"
  }
}
EOF
    log_info "JSON state saved to: $JSON_FILE"
    
    # Update 'latest' symlink
    ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"
    
    # Generate markdown
    generate_markdown "$data" > "$CURRENT_MD"
    log_info "Markdown inventory saved to: $CURRENT_MD"
    
    # Clean up old state files
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"
    
    # Send notification on changes
    case "$change_status" in
        added:*)
            local count=${change_status#added:}
            notify_alert "SWAG Config Added" "$count new reverse proxy config(s) detected" "normal"
            ;;
        removed:*)
            local count=${change_status#removed:}
            notify_alert "SWAG Config Removed" "$count reverse proxy config(s) removed" "normal"
            ;;
        first_run)
            local total
            total=$(echo "$data" | jq -r '.summary.total_configs')
            log_info "First run: found $total configs"
            ;;
        *)
            log_debug "No changes detected"
            ;;
    esac
    
    # Log summary
    local total_hosts total_configs
    total_hosts=$(echo "$data" | jq -r '.summary.total_hosts')
    total_configs=$(echo "$data" | jq -r '.summary.total_configs')
    
    log_success "$SCRIPT_NAME completed: $total_hosts hosts, $total_configs configs"
}

# Run main
main "$@"
