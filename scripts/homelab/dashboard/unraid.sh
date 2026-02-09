#!/bin/bash
# Unraid Fleet Dashboard - Multi-Server Monitoring
# Purpose: Monitor Unraid server health, storage, Docker, and VMs
# Output: JSON state + Markdown inventory
# Cron: 0 * * * * (hourly)

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_VERSION="1.0.0"  # Script version for tracking changes

# Paths (flat structure in memory/bank)
STATE_DIR="${STATE_DIR:-$HOME/memory/bank/$SCRIPT_NAME}"
CURRENT_MD="$STATE_DIR/latest.md"
QUERY_SCRIPT="$HOME/workspace/homelab/skills/unraid/scripts/unraid-query.sh"

# Timestamps
TIMESTAMP=$(date +%s)
JSON_FILE="$STATE_DIR/${TIMESTAMP}.json"
LATEST_LINK="$STATE_DIR/latest.json"

# Retention (configurable via environment)
STATE_RETENTION="${STATE_RETENTION:-168}"  # Keep last 168 files (7 days hourly)

# Enable Gotify notifications by default (with graceful degradation)
export CRONJOB_NOTIFY_METHOD="${CRONJOB_NOTIFY_METHOD:-gotify}"

# Source shared libraries
source "$REPO_ROOT/lib/load-env.sh"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/notify.sh"
source "$REPO_ROOT/lib/state.sh"

# Load credentials from .env for all servers
load_env_file || exit 1
for server in "TOOTIE" "SHART"; do
    url_var="UNRAID_${server}_URL"
    key_var="UNRAID_${server}_API_KEY"
    validate_env_vars "$url_var" "$key_var" || exit 1
done

# Thresholds
DISK_TEMP_WARN="${DISK_TEMP_WARN:-45}"
DISK_TEMP_CRIT="${DISK_TEMP_CRIT:-50}"
STORAGE_WARN_PCT="${STORAGE_WARN_PCT:-80}"
STORAGE_CRIT_PCT="${STORAGE_CRIT_PCT:-90}"

# === Cleanup ===
trap 'echo "ERROR: Script failed on line $LINENO" >&2' ERR
trap 'cleanup' EXIT

cleanup() {
    # Clean up any temporary files
    rm -f /tmp/unraid-query-*.json 2>/dev/null || true
}

# === Functions ===

# Query a single Unraid server
query_server() {
    local name="$1"
    local url="$2"
    local api_key="$3"
    
    export UNRAID_URL="$url"
    export UNRAID_API_KEY="$api_key"
    export IGNORE_ERRORS="true"
    
    local query='query Dashboard {
      info {
        time
        cpu { 
          model cores threads speed speedmin speedmax
          manufacturer brand vendor family
          socket processors voltage
        }
        memory {
          layout {
            size bank type clockSpeed partNum serialNum
            manufacturer formFactor
          }
        }
        os { 
          platform distro release codename kernel arch 
          hostname fqdn build uptime uefi
        }
        system { 
          manufacturer model version serial uuid sku virtual
        }
        baseboard {
          manufacturer model version serial assetTag
          memMax memSlots
        }
        devices {
          network {
            iface model vendor mac virtual speed dhcp
          }
          gpu { typeid vendorname blacklisted }
          usb { name bus device }
          pci { typeid vendorname vendorid productname class blacklisted }
        }
        display {
          theme unit scale tabs resize wwn total usage text
          warning critical hot max locale
        }
        versions {
          core { unraid api kernel }
          packages { openssl node npm git docker nginx php }
        }
      }
      metrics {
        cpu { percentTotal }
        memory { total used free available active buffcache percentTotal swapTotal swapUsed swapFree percentSwapTotal }
      }
      flash {
        id vendor product
      }
      notifications {
        overview {
          unread { info warning alert total }
          archive { info warning alert total }
        }
        list(filter: { type: UNREAD, offset: 0, limit: 50 }) {
          id title subject description importance
          timestamp formattedTimestamp link
        }
      }
      array {
        state
        capacity { kilobytes { total free used } }
        disks { name device temp status fsSize fsFree fsUsed isSpinning numErrors }
        caches { name device temp status fsSize fsFree fsUsed fsType type }
        parityCheckStatus { status progress errors }
      }
      disks { id name }
      shares { 
        name comment size used free 
        include exclude cache allocator 
        splitLevel floor luksStatus color
      }
      docker {
        containers { names image state status }
      }
      vms { domains { id name state } }
      online
      isSSOEnabled
    }'
    
    if ! response=$("$QUERY_SCRIPT" -q "$query" -f json 2>&1); then
        echo "ERROR: Failed to query $name: $response" >&2
        echo "{\"error\": \"Query failed\", \"server\": \"$name\"}"
        return 1
    fi
    
    # Filter out GraphQL warnings (they break JSON parsing)
    # Keep only lines that are valid JSON (starting with { or [)
    response=$(echo "$response" | grep -E '^\{|^\[' | head -1)
    
    # Validate JSON
    if ! echo "$response" | jq -e . >/dev/null 2>&1; then
        echo "ERROR: Invalid JSON response from $name" >&2
        echo "{\"error\": \"Invalid JSON\", \"server\": \"$name\"}"
        return 1
    fi
    
    echo "$response"
}

# Collect data from all servers
collect_data() {
    local -a servers=()
    local -a alerts=()

    # Process each server from environment variables
    for server in "TOOTIE" "SHART"; do
        local name="${server,,}"  # Convert to lowercase
        local url_var="UNRAID_${server}_URL"
        local key_var="UNRAID_${server}_API_KEY"
        local url="${!url_var}"
        local api_key="${!key_var}"
        
        echo "Querying $name..." >&2
        
        local response
        if response=$(query_server "$name" "$url" "$api_key"); then
            # Check for alerts
            local server_alerts
            server_alerts=$(check_server_health "$name" "$response")
            
            if [[ -n "$server_alerts" ]]; then
                alerts+=("$server_alerts")
            fi
            
            # Add to servers array
            servers+=("$(echo "$response" | jq -c --arg name "$name" '.data + {server_name: $name}')")
        else
            # Add error entry
            servers+=("{\"server_name\": \"$name\", \"error\": \"Query failed\"}")
            alerts+=("{\"server\": \"$name\", \"severity\": \"critical\", \"message\": \"Failed to query server\"}")
        fi
    done
    
    # Build final JSON
    local servers_json
    servers_json=$(printf '%s\n' "${servers[@]}" | jq -s '.')
    
    local alerts_json
    if (( ${#alerts[@]} > 0 )); then
        # Flatten nested arrays and combine into single array
        alerts_json=$(printf '%s\n' "${alerts[@]}" | jq -s 'flatten')
    else
        alerts_json="[]"
    fi
    
    jq -n \
        --argjson servers "$servers_json" \
        --argjson alerts "$alerts_json" \
        '{servers: $servers, alerts: $alerts}'
}

# Check server health and generate alerts
check_server_health() {
    local name="$1"
    local response="$2"
    local -a alerts=()
    
    # Check disk temperatures
    while IFS= read -r disk; do
        [[ -z "$disk" ]] && continue
        
        local disk_name
        local temp
        
        disk_name=$(echo "$disk" | jq -r '.name')
        temp=$(echo "$disk" | jq -r '.temp // 0')
        
        if (( temp > DISK_TEMP_CRIT )); then
            alerts+=("{\"server\": \"$name\", \"severity\": \"critical\", \"message\": \"Disk $disk_name temperature: ${temp}°C (critical)\", \"value\": $temp}")
        elif (( temp > DISK_TEMP_WARN )); then
            alerts+=("{\"server\": \"$name\", \"severity\": \"warning\", \"message\": \"Disk $disk_name temperature: ${temp}°C (warning)\", \"value\": $temp}")
        fi
    done < <(echo "$response" | jq -c '.data.array.disks[]?')
    
    # Check disk errors
    while IFS= read -r disk; do
        [[ -z "$disk" ]] && continue
        
        local disk_name
        local errors
        
        disk_name=$(echo "$disk" | jq -r '.name')
        errors=$(echo "$disk" | jq -r '.numErrors // 0')
        
        if (( errors > 0 )); then
            alerts+=("{\"server\": \"$name\", \"severity\": \"critical\", \"message\": \"Disk $disk_name has $errors errors\", \"value\": $errors}")
        fi
    done < <(echo "$response" | jq -c '.data.array.disks[]?')
    
    # Check storage usage
    local total
    local used
    local used_pct
    
    total=$(echo "$response" | jq -r '.data.array.capacity.kilobytes.total // 0')
    used=$(echo "$response" | jq -r '.data.array.capacity.kilobytes.used // 0')
    
    if (( total > 0 )); then
        used_pct=$((used * 100 / total))
        
        if (( used_pct > STORAGE_CRIT_PCT )); then
            alerts+=("{\"server\": \"$name\", \"severity\": \"critical\", \"message\": \"Storage usage: ${used_pct}% (critical)\", \"value\": $used_pct}")
        elif (( used_pct > STORAGE_WARN_PCT )); then
            alerts+=("{\"server\": \"$name\", \"severity\": \"warning\", \"message\": \"Storage usage: ${used_pct}% (warning)\", \"value\": $used_pct}")
        fi
    fi
    
    # Check for unhealthy containers
    local unhealthy
    unhealthy=$(echo "$response" | jq -r '[.data.docker.containers[]? | select(.status | test("unhealthy|restarting"; "i"))] | length')
    
    if (( unhealthy > 0 )); then
        local unhealthy_list=$(echo "$response" | jq -r '[.data.docker.containers[]? | select(.status | test("unhealthy|restarting"; "i")) | .names[0]] | join(", ")')
        alerts+=("{\"server\": \"$name\", \"severity\": \"warning\", \"message\": \"$unhealthy unhealthy containers: $unhealthy_list\", \"value\": $unhealthy}")
    fi
    
    # Check for stopped/exited containers
    local stopped
    stopped=$(echo "$response" | jq -r '[.data.docker.containers[]? | select(.state != "RUNNING")] | length')
    
    if (( stopped > 0 )); then
        local stopped_list=$(echo "$response" | jq -r '[.data.docker.containers[]? | select(.state != "RUNNING") | .names[0]] | join(", ")')
        alerts+=("{\"server\": \"$name\", \"severity\": \"warning\", \"message\": \"$stopped stopped containers: $stopped_list\", \"value\": $stopped}")
    fi
    
    # Return alerts as JSON array
    if (( ${#alerts[@]} > 0 )); then
        printf '%s\n' "${alerts[@]}" | jq -s '.'
    fi
}

# Generate markdown inventory from JSON data
generate_markdown_inventory() {
    local json_data="$1"
    
    cat <<EOF
# Unraid Fleet Dashboard
Generated: $(date)

EOF
    
    # Process each server
    echo "$json_data" | jq -c '.servers[]' | while IFS= read -r server; do
        local name
        name=$(echo "$server" | jq -r '.server_name')
        
        # Check for error
        if echo "$server" | jq -e '.error' >/dev/null 2>&1; then
            cat <<EOF
## Server: $name (⚠️ Error)
Failed to retrieve data.

EOF
            continue
        fi
        
        # System Info
        local cpu_model cores threads manufacturer system_model
        local os_distro os_rel
        local cpu_load mem_used mem_total mem_pct
        
        cpu_model=$(echo "$server" | jq -r '.info.cpu.model // "Unknown"')
        cores=$(echo "$server" | jq -r '.info.cpu.cores // 0')
        threads=$(echo "$server" | jq -r '.info.cpu.threads // 0')
        manufacturer=$(echo "$server" | jq -r '.info.system.manufacturer // "Unknown"')
        system_model=$(echo "$server" | jq -r '.info.system.model // "Unknown"')
        os_distro=$(echo "$server" | jq -r '.info.os.distro // "Unknown"')
        os_rel=$(echo "$server" | jq -r '.info.os.release // "Unknown"')
        cpu_load=$(echo "$server" | jq -r '.metrics.cpu.percentTotal // 0' | awk '{printf "%.1f", $1}')
        
        mem_total=$(echo "$server" | jq -r '.metrics.memory.total // 0')
        mem_used=$(echo "$server" | jq -r '.metrics.memory.used // 0')
        mem_free=$(echo "$server" | jq -r '.metrics.memory.free // 0')
        # percentTotal is "active" memory (excludes reclaimable ZFS cache)
        mem_pct=$(echo "$server" | jq -r '.metrics.memory.percentTotal // 0' | awk '{printf "%.1f", $1}')
        
        local mem_total_gb=$((mem_total / 1024 / 1024 / 1024))
        local mem_free_gb=$((mem_free / 1024 / 1024 / 1024))
        
        # Flash drive info
        local flash_vendor flash_product
        flash_vendor=$(echo "$server" | jq -r '.flash.vendor // "Unknown"')
        flash_product=$(echo "$server" | jq -r '.flash.product // "Unknown"')
        
        # Notifications summary
        local notif_unread notif_warnings notif_alerts
        notif_unread=$(echo "$server" | jq -r '.notifications.overview.unread.total // 0')
        notif_warnings=$(echo "$server" | jq -r '.notifications.overview.unread.warning // 0')
        notif_alerts=$(echo "$server" | jq -r '.notifications.overview.unread.alert // 0')
        
        cat <<EOF
## Server: $name

### Notifications
EOF
        if (( notif_unread > 0 )); then
            echo "- 🔔 **$notif_unread unread** ($notif_warnings warnings, $notif_alerts alerts)"
            
            # Show critical/alert notifications
            local alert_notifs
            alert_notifs=$(echo "$server" | jq -r '.notifications.list[]? | select(.importance == "ALERT") | "  - ⚠️  **\(.title)**: \(.subject)"')
            if [[ -n "$alert_notifs" ]]; then
                echo "$alert_notifs"
            fi
            echo ""
        else
            echo "- ✅ No unread notifications"
            echo ""
        fi
        
        cat <<EOF
### System
- **Hardware:** $manufacturer $system_model
- **OS:** $os_distro $os_rel
- **CPU:** $cores cores / $threads threads
- **CPU Load:** ${cpu_load}%
- **Memory:** ${mem_pct}% active (${mem_free_gb}GB / ${mem_total_gb}GB free)
- **Flash Drive:** $flash_vendor $flash_product

EOF
        
        # Network Interfaces
        local net_count
        net_count=$(echo "$server" | jq '[.info.devices.network[]?] | length')
        
        if (( net_count > 0 )); then
            cat <<EOF
### Network Interfaces ($net_count total)
EOF
            echo "$server" | jq -r '.info.devices.network[]? | 
                "- **\(.iface)** (\(.model // "Unknown")): \(.mac) | \(.speed) | \(if .dhcp then "DHCP" else "Static" end)\(if .virtual then " | Virtual" else "" end)"'
            echo ""
        fi
        
        # Array Storage
        local array_state total used free used_pct
        
        array_state=$(echo "$server" | jq -r '.array.state // "UNKNOWN"')
        total=$(echo "$server" | jq -r '.array.capacity.kilobytes.total // 0')
        used=$(echo "$server" | jq -r '.array.capacity.kilobytes.used // 0')
        free=$(echo "$server" | jq -r '.array.capacity.kilobytes.free // 0')
        
        if (( total > 0 )); then
            local total_tb=$(echo "scale=2; $total / 1024 / 1024 / 1024" | bc)
            local used_tb=$(echo "scale=2; $used / 1024 / 1024 / 1024" | bc)
            local free_tb=$(echo "scale=2; $free / 1024 / 1024 / 1024" | bc)
            used_pct=$((used * 100 / total))
            
            cat <<EOF
### Array Storage ($array_state)
- **Capacity:** ${total_tb}TB total
- **Used:** ${used_tb}TB (${used_pct}%)
- **Free:** ${free_tb}TB

EOF
        fi
        
        # Individual Disks
        local disk_count
        disk_count=$(echo "$server" | jq '[.array.disks[]?] | length')
        
        if (( disk_count > 0 )); then
            cat <<EOF
### Array Disks ($disk_count total)
EOF
            echo "$server" | jq -r '.array.disks[]? | 
                "- **\(.name)** (\(.device)): \(.temp)°C | \(if .isSpinning then "⚡ spinning" else "💤 standby" end) | \(.status)\(if .numErrors > 0 then " | ❌ \(.numErrors) errors" else "" end)"'
            echo ""
        fi
        
        # Cache Pools
        local cache_count
        cache_count=$(echo "$server" | jq '[.array.caches[]?] | length')
        
        if (( cache_count > 0 )); then
            cat <<EOF
### Cache Pools ($cache_count total)
EOF
            echo "$server" | jq -r '.array.caches[]? | 
                "- **\(.name)** (\(.device), \(.fsType // "unknown")): \(.temp)°C | \(if .fsUsed and .fsSize then "\((.fsUsed / 1024 / 1024 / 1024 | floor))GB / \((.fsSize / 1024 / 1024 / 1024 | floor))GB used" else "size unknown" end) | \(.status)"'
            echo ""
        fi
        
        # Parity Check
        local parity_status parity_progress parity_errors
        parity_status=$(echo "$server" | jq -r '.array.parityCheckStatus.status // "UNKNOWN"')
        parity_progress=$(echo "$server" | jq -r '.array.parityCheckStatus.progress // 0')
        parity_errors=$(echo "$server" | jq -r '.array.parityCheckStatus.errors // "null"')
        
        cat <<EOF
### Parity Check
- **Status:** $parity_status
EOF
        if [[ "$parity_status" != "NEVER_RUN" ]] && [[ "$parity_status" != "UNKNOWN" ]]; then
            echo "- **Progress:** ${parity_progress}%"
            [[ "$parity_errors" != "null" ]] && echo "- **Errors:** $parity_errors"
        fi
        echo ""
        
        # Docker Containers
        local total_containers running_containers stopped_containers
        
        total_containers=$(echo "$server" | jq '[.docker.containers[]?] | length')
        running_containers=$(echo "$server" | jq '[.docker.containers[]? | select(.state == "RUNNING")] | length')
        stopped_containers=$((total_containers - running_containers))
        
        cat <<EOF
### Docker Containers
- **Total:** $total_containers ($running_containers running, $stopped_containers stopped)

EOF
        
        # Unhealthy containers
        local unhealthy_count
        unhealthy_count=$(echo "$server" | jq '[.docker.containers[]? | select(.status | test("unhealthy|restarting"; "i"))] | length')
        
        if (( unhealthy_count > 0 )); then
            echo "**⚠️  Unhealthy Containers:**"
            echo "$server" | jq -r '.docker.containers[]? | select(.status | test("unhealthy|restarting"; "i")) | "- \(.names[0]): \(.status)"'
            echo ""
        fi
        
        # Stopped/exited containers
        if (( stopped_containers > 0 )); then
            echo "**🛑 Stopped Containers:**"
            echo "$server" | jq -r '.docker.containers[]? | select(.state != "RUNNING") | "- \(.names[0]): \(.status)"'
            echo ""
        fi
        
        # VMs
        if echo "$server" | jq -e '.vms.domains' >/dev/null 2>&1; then
            local total_vms running_vms
            
            total_vms=$(echo "$server" | jq '[.vms.domains[]?] | length')
            running_vms=$(echo "$server" | jq '[.vms.domains[]? | select(.state == "RUNNING")] | length')
            
            cat <<EOF
### Virtual Machines
- **Total:** $total_vms ($running_vms running)

EOF
            if (( total_vms > 0 )); then
                echo "$server" | jq -r '.vms.domains[]? | "- **\(.name)**: \(.state)"'
                echo ""
            fi
        fi
        
        # Shares
        local share_count
        share_count=$(echo "$server" | jq '[.shares[]?] | length')
        
        if (( share_count > 0 )); then
            cat <<EOF
### Shares ($share_count total)
EOF
            # Show detailed share info
            while IFS= read -r share; do
                [[ -z "$share" ]] && continue
                
                local share_name share_comment share_size share_used share_free share_cache share_include share_exclude
                share_name=$(echo "$share" | jq -r '.name')
                share_comment=$(echo "$share" | jq -r '.comment // ""')
                share_size=$(echo "$share" | jq -r '.size // 0')
                share_used=$(echo "$share" | jq -r '.used // 0')
                share_free=$(echo "$share" | jq -r '.free // 0')
                share_cache=$(echo "$share" | jq -r '.cache // false')
                share_include=$(echo "$share" | jq -r '.include[]? // ""' | tr '\n' ',' | sed 's/,$//')
                share_exclude=$(echo "$share" | jq -r '.exclude[]? // ""' | tr '\n' ',' | sed 's/,$//')
                
                # Calculate size in GB/TB
                local size_display=""
                # Calculate total from used + free if size is 0
                if (( share_size == 0 && (share_used > 0 || share_free > 0) )); then
                    share_size=$((share_used + share_free))
                fi
                
                if (( share_size > 0 )); then
                    local size_gb=$((share_size / 1024 / 1024))
                    local used_gb=$((share_used / 1024 / 1024))
                    local free_gb=$((share_free / 1024 / 1024))
                    local used_pct=0
                    
                    if (( share_size > 0 )); then
                        used_pct=$((share_used * 100 / share_size))
                    fi
                    
                    if (( size_gb > 1024 )); then
                        local size_tb=$(echo "scale=2; $size_gb / 1024" | bc)
                        local used_tb=$(echo "scale=2; $used_gb / 1024" | bc)
                        size_display="${used_tb}/${size_tb}TB (${used_pct}%)"
                    else
                        size_display="${used_gb}/${size_gb}GB (${used_pct}%)"
                    fi
                fi
                
                # Build output line
                echo -n "- **$share_name**"
                [[ -n "$share_comment" ]] && echo -n ": $share_comment"
                [[ -n "$size_display" ]] && echo -n " | $size_display"
                
                # Show cache preference
                if [[ "$share_cache" == "true" ]]; then
                    echo -n " | 🚀 cache-prefer"
                elif [[ "$share_cache" == "false" ]]; then
                    echo -n " | 💾 array-only"
                fi
                echo ""
                
                # Show include/exclude if set
                if [[ -n "$share_include" ]]; then
                    echo "  - Include: $share_include"
                fi
                if [[ -n "$share_exclude" ]]; then
                    echo "  - Exclude: $share_exclude"
                fi
                
            done < <(echo "$server" | jq -c '.shares[]?' | head -10)
            
            [[ $share_count -gt 10 ]] && echo "- *(+$((share_count - 10)) more)*"
            echo ""
        fi
        
        # OS Details
        local os_hostname os_fqdn os_uptime os_uefi os_kernel
        os_hostname=$(echo "$server" | jq -r '.info.os.hostname // "Unknown"')
        os_fqdn=$(echo "$server" | jq -r '.info.os.fqdn // "Unknown"')
        os_uptime=$(echo "$server" | jq -r '.info.os.uptime // "Unknown"')
        os_uefi=$(echo "$server" | jq -r '.info.os.uefi // false')
        os_kernel=$(echo "$server" | jq -r '.info.os.kernel // "Unknown"')
        
        cat <<EOF
### OS Details
- **Hostname:** $os_hostname
EOF
        [[ "$os_fqdn" != "Unknown" && "$os_fqdn" != "$os_hostname" ]] && echo "- **FQDN:** $os_fqdn"
        echo "- **Kernel:** $os_kernel"
        [[ "$os_uefi" == "true" ]] && echo "- **Boot Mode:** UEFI" || echo "- **Boot Mode:** Legacy BIOS"
        if [[ "$os_uptime" != "Unknown" ]]; then
            # Calculate uptime from ISO timestamp
            local uptime_readable
            uptime_readable=$(date -d "$os_uptime" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$os_uptime")
            echo "- **Booted:** $uptime_readable"
        fi
        echo ""
        
        # Hardware Details
        local cpu_brand cpu_socket cpu_speed mem_modules
        cpu_brand=$(echo "$server" | jq -r '.info.cpu.brand // .info.cpu.model // "Unknown"')
        cpu_socket=$(echo "$server" | jq -r '.info.cpu.socket // "Unknown"')
        cpu_speed=$(echo "$server" | jq -r '.info.cpu.speed // 0')
        mem_modules=$(echo "$server" | jq '[.info.memory.layout[]?] | length')
        
        if [[ "$cpu_brand" != "Unknown" ]] || (( mem_modules > 0 )); then
            cat <<EOF
### Hardware Details
EOF
            if [[ "$cpu_brand" != "Unknown" ]]; then
                echo "- **CPU:** $cpu_brand ($cpu_socket)"
                [[ "$cpu_speed" != "0" ]] && echo "- **Clock:** ${cpu_speed}GHz"
            fi
            
            if (( mem_modules > 0 )); then
                local total_mem_gb
                total_mem_gb=$(echo "$server" | jq '[.info.memory.layout[]?.size // 0] | add / 1024 / 1024 / 1024 | floor')
                echo "- **Memory Modules:** $mem_modules DIMMs (${total_mem_gb}GB total)"
                
                # Show first few modules
                echo "$server" | jq -r '.info.memory.layout[]? | 
                    "  - \((.size / 1024 / 1024 / 1024 | floor))GB \(.type) @ \(.clockSpeed)MHz (\(.manufacturer // "Unknown"))"' | head -4
                
                if (( mem_modules > 4 )); then
                    echo "  - *(+$((mem_modules - 4)) more)*"
                fi
            fi
            echo ""
        fi
        
        # GPU Info
        local gpu_count
        gpu_count=$(echo "$server" | jq '[.info.devices.gpu[]?] | length')
        
        if (( gpu_count > 0 )); then
            cat <<EOF
### GPU Devices ($gpu_count total)
EOF
            echo "$server" | jq -r '.info.devices.gpu[]? | 
                "- \(.vendorname // "Unknown") (\(.typeid // "unknown"))\(if .blacklisted then " | ⚠️ Blacklisted" else "" end)"'
            echo ""
        fi
        
        # USB Devices
        local usb_count
        usb_count=$(echo "$server" | jq '[.info.devices.usb[]?] | length')
        
        if (( usb_count > 0 )); then
            cat <<EOF
### USB Devices ($usb_count total)
EOF
            # Show first 10
            echo "$server" | jq -r '.info.devices.usb[]? | "- \(.name)"' | head -10
            
            if (( usb_count > 10 )); then
                echo "- *(+$((usb_count - 10)) more)*"
            fi
            echo ""
        fi
        
        # PCI Devices
        local pci_count
        pci_count=$(echo "$server" | jq '[.info.devices.pci[]?] | length')
        
        if (( pci_count > 0 )); then
            cat <<EOF
### PCI Devices ($pci_count total)
EOF
            # Show first 10
            echo "$server" | jq -r '.info.devices.pci[]? | 
                "- \(.vendorname // "Unknown"): \(.productname // .typeid // "unknown")\(if .blacklisted == "true" then " | ⚠️ Blacklisted" else "" end)"' | head -10
            
            if (( pci_count > 10 )); then
                echo "- *(+$((pci_count - 10)) more)*"
            fi
            echo ""
        fi
        
        # Health Summary
        cat <<EOF
### Health Summary
EOF
        
        local hot_disks disk_errors unhealthy high_mem
        
        hot_disks=$(echo "$server" | jq -r ".array.disks[]? | select(.temp > $DISK_TEMP_WARN) | .name" | wc -l)
        disk_errors=$(echo "$server" | jq -r '.array.disks[]? | select(.numErrors > 0) | .name' | wc -l)
        unhealthy=$(echo "$server" | jq '[.docker.containers[]? | select(.status | test("unhealthy|restarting"; "i"))] | length')
        
        if (( hot_disks == 0 )) && (( disk_errors == 0 )) && (( unhealthy == 0 )) && (( ${mem_pct%.*} < 90 )); then
            echo "✅ **All systems healthy**"
        else
            [[ $hot_disks -gt 0 ]] && echo "- ⚠️  $hot_disks disk(s) over ${DISK_TEMP_WARN}°C"
            [[ $disk_errors -gt 0 ]] && echo "- ❌ $disk_errors disk(s) with errors"
            [[ $unhealthy -gt 0 ]] && echo "- 🔴 $unhealthy unhealthy container(s)"
            [[ ${mem_pct%.*} -ge 90 ]] && echo "- ⚠️  High memory usage (${mem_pct}%)"
        fi
        
        cat <<EOF

---

EOF
    done
}

# === Main Script ===

main() {
    # Initialize logging (enables log rotation)
    init_logging "$SCRIPT_NAME"
    
    log_info "Starting $SCRIPT_NAME"
    
    # Ensure state directory exists
    ensure_state_dir "$STATE_DIR"
    
    # Collect data
    log_info "Collecting data from Unraid servers..."
    local data
    if ! data=$(collect_data); then
        log_error "Data collection failed"
        exit 1
    fi
    
    # 1. Write JSON state file (timestamped)
    jq -n \
        --argjson timestamp "$TIMESTAMP" \
        --arg script "$SCRIPT_NAME" \
        --arg version "$SCRIPT_VERSION" \
        --argjson data "$data" \
        --arg hostname "$(hostname)" \
        --argjson exec_time "$(($(date +%s) - TIMESTAMP))" \
        '{
            timestamp: $timestamp,
            script: $script,
            version: $version,
            data: $data,
            metadata: {
                hostname: $hostname,
                execution_time: "\($exec_time)s"
            }
        }' > "$JSON_FILE"
    
    log_info "JSON state saved to: $JSON_FILE"
    
    # 2. Update 'latest' symlink (relative path)
    ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"
    
    # 3. Convert to markdown inventory (human-readable)
    generate_markdown_inventory "$data" > "$CURRENT_MD"
    log_info "Markdown inventory saved to: $CURRENT_MD"
    
    # 4. Clean up old state files (keep per retention policy)
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"
    
    # Check for alerts
    local alert_count
    alert_count=$(echo "$data" | jq -r '.alerts | length')
    
    if (( alert_count > 0 )); then
        local alert_msg
        alert_msg=$(echo "$data" | jq -r '.alerts[] | "[\(.severity | ascii_upcase)] \(.server): \(.message)"' | head -10)
        
        notify_alert "Unraid Fleet Alert ($alert_count issues)" "$alert_msg" "normal"
        log_warn "$alert_count alerts generated"
    fi
    
    log_success "$SCRIPT_NAME completed successfully"
}

# Run main function
main "$@"
