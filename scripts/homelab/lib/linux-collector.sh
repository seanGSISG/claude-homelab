#!/bin/bash
# Linux Remote Collector - Lightweight data collection for remote hosts
# Purpose: Collect system data that can be piped via SSH
# Output: JSON to stdout
# Usage: ssh host "bash -s" < lib/linux-collector.sh

set -euo pipefail

# === Configuration ===
CPU_LOAD_WARN="${CPU_LOAD_WARN:-80}"
CPU_LOAD_CRIT="${CPU_LOAD_CRIT:-95}"
MEM_USAGE_WARN="${MEM_USAGE_WARN:-80}"
MEM_USAGE_CRIT="${MEM_USAGE_CRIT:-90}"
DISK_USAGE_WARN="${DISK_USAGE_WARN:-80}"
DISK_USAGE_CRIT="${DISK_USAGE_CRIT:-90}"

# === Helper Functions ===

# Check if we can use sudo
can_sudo() {
    if command -v sudo &>/dev/null; then
        if [ "$(id -u)" -eq 0 ] || sudo -n true 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Run command with sudo if available
run_privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif can_sudo; then
        sudo "$@"
    else
        return 1
    fi
}

# Detect boot mode (UEFI vs BIOS)
detect_boot_mode() {
    if [ -d /sys/firmware/efi ]; then
        echo "UEFI"
    else
        echo "BIOS"
    fi
}

# === Collection Functions ===

collect_hardware_info() {
    local hw_json="{}"
    
    if command -v dmidecode &>/dev/null && can_sudo; then
        local sys_manufacturer=$(run_privileged dmidecode -s system-manufacturer 2>/dev/null | grep -v "^#" | head -1 || echo "Unknown")
        local sys_product=$(run_privileged dmidecode -s system-product-name 2>/dev/null | grep -v "^#" | head -1 || echo "Unknown")
        local sys_serial=$(run_privileged dmidecode -s system-serial-number 2>/dev/null | grep -v "^#" | head -1 || echo "Unknown")
        
        hw_json=$(jq -n \
            --arg sys_mfg "$sys_manufacturer" \
            --arg sys_prod "$sys_product" \
            --arg sys_serial "$sys_serial" \
            '{
                system: {
                    manufacturer: $sys_mfg,
                    product: $sys_prod,
                    serial: $sys_serial
                }
            }')
    fi
    
    echo "$hw_json"
}

collect_smart_data() {
    local disks_json="[]"
    local -a disk_array=()
    
    if command -v smartctl &>/dev/null && can_sudo; then
        for disk in $(lsblk -d -n -o NAME,TYPE 2>/dev/null | awk '$2=="disk" {print $1}'); do
            local temp="null"
            local health="Unknown"
            local model="Unknown"
            
            local smart_info=$(run_privileged smartctl -i /dev/$disk 2>/dev/null || true)
            local smart_attrs=$(run_privileged smartctl -A /dev/$disk 2>/dev/null || true)
            local smart_health=$(run_privileged smartctl -H /dev/$disk 2>/dev/null || true)
            
            temp=$(echo "$smart_attrs" | grep -E "^194|Temperature_Celsius" | awk '{print $10}' | head -1)
            [ -z "$temp" ] && temp="null"
            
            health=$(echo "$smart_health" | grep -i "SMART overall-health" | awk -F': ' '{print $2}' | xargs)
            [ -z "$health" ] && health="Unknown"
            
            model=$(echo "$smart_info" | grep -E "Device Model:|Model Number:" | head -1 | cut -d: -f2 | xargs)
            [ -z "$model" ] && model="Unknown"
            
            local disk_json=$(jq -n \
                --arg name "$disk" \
                --arg temp "$temp" \
                --arg health "$health" \
                --arg model "$model" \
                '{
                    name: $name,
                    temperature: (if $temp == "null" or $temp == "" then null else ($temp | tonumber) end),
                    health: $health,
                    model: $model
                }')
            
            disk_array+=("$disk_json")
        done
        
        if (( ${#disk_array[@]} > 0 )); then
            disks_json=$(printf '%s\n' "${disk_array[@]}" | jq -s '.')
        fi
    fi
    
    echo "$disks_json"
}

collect_zfs_data() {
    local zfs_json='{"pools":[],"available":false}'
    
    if command -v zpool &>/dev/null; then
        local pools=$(zpool list -H -o name,size,alloc,free,health 2>/dev/null || true)
        
        if [ -n "$pools" ]; then
            local pools_json=$(echo "$pools" | awk '{
                printf "{\"name\":\"%s\",\"size\":\"%s\",\"allocated\":\"%s\",\"free\":\"%s\",\"health\":\"%s\"}\n", $1, $2, $3, $4, $5
            }' | jq -s '.')
            
            zfs_json=$(jq -n --argjson pools "$pools_json" '{pools: $pools, available: true}')
        else
            zfs_json='{"pools":[],"available":true}'
        fi
    fi
    
    echo "$zfs_json"
}

collect_package_versions() {
    local docker_ver="not installed"
    local systemd_ver="not installed"
    local kernel_ver=$(uname -r)
    
    command -v docker &>/dev/null && docker_ver=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo "error")
    command -v systemctl &>/dev/null && systemd_ver=$(systemctl --version 2>/dev/null | head -1 | awk '{print $2}' || echo "error")
    
    jq -n \
        --arg docker "$docker_ver" \
        --arg systemd "$systemd_ver" \
        --arg kernel "$kernel_ver" \
        '{
            docker: $docker,
            systemd: $systemd,
            kernel: $kernel
        }'
}

# === Main Collection ===

collect_system_data() {
    local -a alerts=()
    local data="{}"
    
    # Hostname
    local hostname=$(hostname)
    data=$(echo "$data" | jq --arg val "$hostname" '. + {hostname: $val}')
    
    # OS Info
    if [ -f /etc/os-release ]; then
        local os_name=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d'"' -f2)
        local os_id=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        local os_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        data=$(echo "$data" | jq --arg name "$os_name" --arg id "$os_id" --arg ver "$os_version" \
            '. + {os: {name: $name, id: $id, version: $ver}}')
    fi
    
    # Kernel & Boot Mode
    local kernel=$(uname -r)
    local boot_mode=$(detect_boot_mode)
    data=$(echo "$data" | jq --arg val "$kernel" --arg boot "$boot_mode" '.os += {kernel: $val, boot_mode: $boot}')
    
    # Uptime
    local uptime_seconds=$(cut -d' ' -f1 /proc/uptime | cut -d'.' -f1)
    local boot_time=$(date -d "@$(($(date +%s) - uptime_seconds))" +"%Y-%m-%d %H:%M")
    data=$(echo "$data" | jq --argjson val "$uptime_seconds" --arg boot "$boot_time" \
        '. + {uptime_seconds: $val, boot_time: $boot}')
    
    # Hardware Info
    local hw_info=$(collect_hardware_info)
    if [ "$hw_info" != "{}" ]; then
        data=$(echo "$data" | jq --argjson hw "$hw_info" '. + {hardware: $hw}')
    fi
    
    # CPU Info
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    local cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
    local cpu_threads=$(nproc)
    local load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d'.' -f1)
    [ -z "$cpu_usage" ] && cpu_usage=0
    
    data=$(echo "$data" | jq --arg model "$cpu_model" \
        --argjson cores "$cpu_cores" \
        --argjson threads "$cpu_threads" \
        --arg load "$load_avg" \
        --argjson usage "$cpu_usage" \
        '. + {cpu: {model: $model, cores: $cores, threads: $threads, load_avg: $load, usage_percent: $usage}}')
    
    # Check CPU
    if (( cpu_usage > CPU_LOAD_CRIT )); then
        alerts+=("{\"severity\": \"critical\", \"message\": \"CPU load: ${cpu_usage}%\", \"value\": $cpu_usage}")
    elif (( cpu_usage > CPU_LOAD_WARN )); then
        alerts+=("{\"severity\": \"warning\", \"message\": \"CPU load: ${cpu_usage}%\", \"value\": $cpu_usage}")
    fi
    
    # Memory Info
    local mem_total=$(free -b | awk '/^Mem:/ {print $2}')
    local mem_used=$(free -b | awk '/^Mem:/ {print $3}')
    local mem_available=$(free -b | awk '/^Mem:/ {print $7}')
    local mem_percent=$((mem_used * 100 / mem_total))
    
    local swap_total=$(free -b | awk '/^Swap:/ {print $2}')
    local swap_used=$(free -b | awk '/^Swap:/ {print $3}')
    local swap_percent=0
    [ "$swap_total" -gt 0 ] && swap_percent=$((swap_used * 100 / swap_total))
    
    data=$(echo "$data" | jq --argjson total "$mem_total" --argjson used "$mem_used" \
        --argjson available "$mem_available" --argjson percent "$mem_percent" \
        --argjson swap_total "$swap_total" --argjson swap_used "$swap_used" --argjson swap_percent "$swap_percent" \
        '. + {memory: {total: $total, used: $used, available: $available, percent: $percent, swap: {total: $swap_total, used: $swap_used, percent: $swap_percent}}}')
    
    # Check memory
    if (( mem_percent > MEM_USAGE_CRIT )); then
        alerts+=("{\"severity\": \"critical\", \"message\": \"Memory usage: ${mem_percent}%\", \"value\": $mem_percent}")
    elif (( mem_percent > MEM_USAGE_WARN )); then
        alerts+=("{\"severity\": \"warning\", \"message\": \"Memory usage: ${mem_percent}%\", \"value\": $mem_percent}")
    fi
    
    # Disk Info - handle spaces in filesystem/mount paths
    # Find the percent field (ends with %) and work from there
    # Format: Filesystem Size Used Avail Use% Mounted on
    local disks_json
    disks_json=$(df -BG 2>/dev/null | \
        grep -v "^tmpfs\|^devtmpfs\|^overlay\|^shm\|^run\|^fuse\|^snap\|^/dev/loop\|^Filesystem" | \
        awk '{
            # Find the field ending in % (Use% column)
            pct_idx = 0
            for (i = 1; i <= NF; i++) {
                if ($i ~ /%$/) { pct_idx = i; break }
            }
            if (pct_idx < 5) next  # Need at least: fs, size, used, avail, pct%
            
            # Fields relative to pct_idx
            pcent = $pct_idx
            avail = $(pct_idx - 1)
            used = $(pct_idx - 2)
            size = $(pct_idx - 3)
            
            # Filesystem is fields 1 through (pct_idx - 4)
            fs = $1
            for (i = 2; i <= pct_idx - 4; i++) fs = fs " " $i
            
            # Mount point is fields (pct_idx + 1) through NF
            mount = $(pct_idx + 1)
            for (i = pct_idx + 2; i <= NF; i++) mount = mount " " $i
            
            # Clean up values
            gsub(/G/, "", size); gsub(/G/, "", used); gsub(/G/, "", avail); gsub(/%/, "", pcent)
            gsub(/"/, "\\\"", fs); gsub(/"/, "\\\"", mount)
            
            # Validate numeric fields
            if (size+0 == size && used+0 == used && avail+0 == avail && pcent+0 == pcent) {
                print "{\"filesystem\":\"" fs "\",\"size_gb\":" size ",\"used_gb\":" used ",\"free_gb\":" avail ",\"percent\":" pcent ",\"mount\":\"" mount "\"}"
            }
        }' | jq -s '.' 2>/dev/null || echo "[]")
    
    data=$(echo "$data" | jq --argjson disks "$disks_json" '. + {disks: $disks}')
    
    # Check disk usage
    while IFS= read -r disk; do
        [[ -z "$disk" ]] && continue
        local mount=$(echo "$disk" | jq -r '.mount')
        local percent=$(echo "$disk" | jq -r '.percent')
        
        if (( percent > DISK_USAGE_CRIT )); then
            alerts+=("{\"severity\": \"critical\", \"message\": \"Disk $mount: ${percent}%\", \"value\": $percent}")
        elif (( percent > DISK_USAGE_WARN )); then
            alerts+=("{\"severity\": \"warning\", \"message\": \"Disk $mount: ${percent}%\", \"value\": $percent}")
        fi
    done < <(echo "$disks_json" | jq -c '.[]')
    
    # SMART Data
    local smart_data=$(collect_smart_data)
    if [ "$smart_data" != "[]" ]; then
        data=$(echo "$data" | jq --argjson smart "$smart_data" '. + {smart_disks: $smart}')
    fi
    
    # Network Interfaces
    local interfaces_json=$(ip -j addr show 2>/dev/null | jq '[.[] | select(.ifname != "lo") | {
        name: .ifname, 
        state: .operstate, 
        mac: .address,
        addresses: [.addr_info[] | {family: .family, address: .local}]
    }]' 2>/dev/null || echo '[]')
    
    data=$(echo "$data" | jq --argjson ifaces "$interfaces_json" '. + {network_interfaces: $ifaces}')
    
    # ZFS Data
    local zfs_data=$(collect_zfs_data)
    if echo "$zfs_data" | jq -e '.available' >/dev/null 2>&1; then
        data=$(echo "$data" | jq --argjson zfs "$zfs_data" '. + {zfs: $zfs}')
    fi
    
    # Package Versions
    local versions=$(collect_package_versions)
    data=$(echo "$data" | jq --argjson versions "$versions" '. + {versions: $versions}')
    
    # Docker containers
    if command -v docker &>/dev/null; then
        local docker_json=$(docker ps -a --format '{{json .}}' 2>/dev/null | jq -s '[.[] | {name: .Names, status: .Status, state: .State, image: .Image}]' || echo '[]')
        data=$(echo "$data" | jq --argjson containers "$docker_json" '. + {docker: {containers: $containers}}')
    fi
    
    # Systemd services (failed)
    if command -v systemctl &>/dev/null; then
        local failed_services=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
        data=$(echo "$data" | jq --argjson failed "$failed_services" '. + {systemd: {failed_services: $failed}}')
    fi
    
    # Tailscale status
    if command -v tailscale &>/dev/null; then
        local ts_ip=$(tailscale ip -4 2>/dev/null || echo "")
        local ts_status=$(tailscale status --self --json 2>/dev/null | jq -c '{ip: .Self.TailscaleIPs[0], online: .Self.Online}' || echo '{}')
        data=$(echo "$data" | jq --argjson ts "$ts_status" '. + {tailscale: $ts}')
    fi
    
    # Build final output with alerts
    local alerts_json
    if (( ${#alerts[@]} > 0 )); then
        alerts_json=$(printf '%s\n' "${alerts[@]}" | jq -s '.')
    else
        alerts_json="[]"
    fi
    
    jq -n --argjson data "$data" --argjson alerts "$alerts_json" --argjson ts "$(date +%s)" \
        '{timestamp: $ts, data: $data, alerts: $alerts}'
}

# Run collection and output JSON
collect_system_data
