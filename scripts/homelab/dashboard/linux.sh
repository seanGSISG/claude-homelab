#!/bin/bash
# Linux Dashboard - Ubuntu/Linux System Monitoring  
# Purpose: Monitor system health, hardware, services, and resources
# Output: JSON state + Markdown inventory
# Cron: 0 * * * * (hourly)
# Modes: local (default), remote (all SSH hosts), --host=<name> (specific host)

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_VERSION="1.0.0"  # Script version for tracking changes

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

# Remote collection mode
REMOTE_MODE="${REMOTE_MODE:-false}"
SPECIFIC_HOST=""
SSH_INVENTORY_FILE="$HOME/memory/bank/ssh/latest.json"
COLLECTOR_SCRIPT="$REPO_ROOT/lib/linux-collector.sh"

# Source shared libraries
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/notify.sh"
source "$REPO_ROOT/lib/state.sh"
source "$REPO_ROOT/lib/remote-exec.sh"

# Thresholds
CPU_LOAD_WARN="${CPU_LOAD_WARN:-80}"
CPU_LOAD_CRIT="${CPU_LOAD_CRIT:-95}"
MEM_USAGE_WARN="${MEM_USAGE_WARN:-80}"
MEM_USAGE_CRIT="${MEM_USAGE_CRIT:-90}"
DISK_USAGE_WARN="${DISK_USAGE_WARN:-80}"
DISK_USAGE_CRIT="${DISK_USAGE_CRIT:-90}"
DISK_TEMP_WARN="${DISK_TEMP_WARN:-45}"
DISK_TEMP_CRIT="${DISK_TEMP_CRIT:-55}"

# === Cleanup ===
trap 'echo "ERROR: Script failed on line $LINENO" >&2' ERR
trap 'cleanup' EXIT

cleanup() {
    rm -f /tmp/sys-inv-*.tmp 2>/dev/null || true
}

# === Helper Functions ===

# Check if we can use sudo
can_sudo() {
    if command -v sudo &>/dev/null; then
        # Check if we can sudo without password or if we're root
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

# === Hardware Collection Functions ===

# Collect DMI/SMBIOS hardware info
collect_hardware_info() {
    local hw_json="{}"
    
    if command -v dmidecode &>/dev/null && can_sudo; then
        # System info
        local sys_manufacturer=$(run_privileged dmidecode -s system-manufacturer 2>/dev/null | grep -v "^#" | head -1 || echo "Unknown")
        local sys_product=$(run_privileged dmidecode -s system-product-name 2>/dev/null | grep -v "^#" | head -1 || echo "Unknown")
        local sys_serial=$(run_privileged dmidecode -s system-serial-number 2>/dev/null | grep -v "^#" | head -1 || echo "Unknown")
        local sys_uuid=$(run_privileged dmidecode -s system-uuid 2>/dev/null | grep -v "^#" | head -1 || echo "Unknown")
        
        # Baseboard info
        local board_manufacturer=$(run_privileged dmidecode -s baseboard-manufacturer 2>/dev/null | grep -v "^#" | head -1 || echo "Unknown")
        local board_product=$(run_privileged dmidecode -s baseboard-product-name 2>/dev/null | grep -v "^#" | head -1 || echo "Unknown")
        local board_version=$(run_privileged dmidecode -s baseboard-version 2>/dev/null | grep -v "^#" | head -1 || echo "Unknown")
        local board_serial=$(run_privileged dmidecode -s baseboard-serial-number 2>/dev/null | grep -v "^#" | head -1 || echo "Unknown")
        
        hw_json=$(jq -n \
            --arg sys_mfg "$sys_manufacturer" \
            --arg sys_prod "$sys_product" \
            --arg sys_serial "$sys_serial" \
            --arg sys_uuid "$sys_uuid" \
            --arg board_mfg "$board_manufacturer" \
            --arg board_prod "$board_product" \
            --arg board_ver "$board_version" \
            --arg board_serial "$board_serial" \
            '{
                system: {
                    manufacturer: $sys_mfg,
                    product: $sys_prod,
                    serial: $sys_serial,
                    uuid: $sys_uuid
                },
                baseboard: {
                    manufacturer: $board_mfg,
                    product: $board_prod,
                    version: $board_ver,
                    serial: $board_serial
                }
            }')
    fi
    
    echo "$hw_json"
}

# Collect memory module details from DMI
collect_memory_modules() {
    local mem_modules="[]"
    
    if command -v dmidecode &>/dev/null && can_sudo; then
        # Parse memory modules with proper JSON escaping
        mem_modules=$(run_privileged dmidecode -t memory 2>/dev/null | awk '
            BEGIN { count=0 }
            /^Memory Device$/ { 
                # Print previous record if it had data
                if (count > 0 && has_size) {
                    printf "%s{\"size\":\"%s\"", (printed>0?",":""), size
                    if (type != "") printf ",\"type\":\"%s\"", type
                    if (speed != "") printf ",\"speed\":\"%s\"", speed
                    if (mfg != "") printf ",\"manufacturer\":\"%s\"", mfg
                    if (pn != "") printf ",\"part_number\":\"%s\"", pn
                    if (loc != "") printf ",\"locator\":\"%s\"", loc
                    print "}"
                    printed++
                }
                count++
                has_size=0
                size=""; type=""; speed=""; mfg=""; pn=""; loc=""
            }
            /^\tSize:/ && !/No Module Installed/ { 
                gsub(/^\tSize: /, "")
                size=$0
                has_size=1
            }
            /^\tType:/ && !/Unknown/ && !/Type Detail/ {
                gsub(/^\tType: /, "")
                type=$0
            }
            /^\tSpeed:/ && !/Unknown/ && !/Configured/ {
                gsub(/^\tSpeed: /, "")
                speed=$0
            }
            /^\tManufacturer:/ && !/Unknown/ && !/NOT AVAILABLE/ {
                gsub(/^\tManufacturer: /, "")
                mfg=$0
            }
            /^\tPart Number:/ && !/Unknown/ && !/NOT AVAILABLE/ {
                gsub(/^\tPart Number: /, "")
                gsub(/^[ \t]+|[ \t]+$/, "")
                pn=$0
            }
            /^\tLocator:/ && !/Bank/ {
                gsub(/^\tLocator: /, "")
                loc=$0
            }
            END { 
                # Print last record if it had data
                if (has_size) {
                    printf "%s{\"size\":\"%s\"", (printed>0?",":""), size
                    if (type != "") printf ",\"type\":\"%s\"", type
                    if (speed != "") printf ",\"speed\":\"%s\"", speed
                    if (mfg != "") printf ",\"manufacturer\":\"%s\"", mfg
                    if (pn != "") printf ",\"part_number\":\"%s\"", pn
                    if (loc != "") printf ",\"locator\":\"%s\"", loc
                    print "}"
                }
            }
        ' | { echo "["; cat; echo "]"; } | jq -c 'map(select(.size != null and .size != ""))' 2>/dev/null || echo "[]")
    fi
    
    echo "$mem_modules"
}

# Detect boot mode (UEFI vs BIOS)
detect_boot_mode() {
    if [ -d /sys/firmware/efi ]; then
        echo "UEFI"
    else
        echo "BIOS"
    fi
}

# Collect SMART disk data
collect_smart_data() {
    local disks_json="[]"
    local -a disk_array=()
    
    if command -v smartctl &>/dev/null && can_sudo; then
        for disk in $(lsblk -d -n -o NAME,TYPE 2>/dev/null | awk '$2=="disk" {print $1}'); do
            local temp="null"
            local health="Unknown"
            local errors=0
            local model="Unknown"
            local serial="Unknown"
            local spinning="unknown"
            
            # Get SMART info
            local smart_info=$(run_privileged smartctl -i /dev/$disk 2>/dev/null || true)
            local smart_attrs=$(run_privileged smartctl -A /dev/$disk 2>/dev/null || true)
            local smart_health=$(run_privileged smartctl -H /dev/$disk 2>/dev/null || true)
            
            # Get temperature (try multiple attributes)
            temp=$(echo "$smart_attrs" | grep -E "^194|Temperature_Celsius|Airflow_Temperature" | awk '{print $10}' | head -1)
            [ -z "$temp" ] && temp=$(echo "$smart_attrs" | grep -i "temperature" | awk '{print $10}' | head -1)
            [ -z "$temp" ] && temp="null"
            
            # Get health status
            health=$(echo "$smart_health" | grep -i "SMART overall-health" | awk -F': ' '{print $2}' | xargs)
            [ -z "$health" ] && health="Unknown"
            
            # Get error count from error log
            local error_output=$(run_privileged smartctl -l error /dev/$disk 2>/dev/null || true)
            errors=$(echo "$error_output" | grep -i "ATA Error Count:" | awk '{print $4}')
            [ -z "$errors" ] && errors=$(echo "$error_output" | grep -Eo "^[0-9]+ error" | head -1 | awk '{print $1}')
            [ -z "$errors" ] && errors=0
            
            # Get model and serial
            model=$(echo "$smart_info" | grep -E "Device Model:|Model Number:" | head -1 | cut -d: -f2 | xargs)
            [ -z "$model" ] && model="Unknown"
            serial=$(echo "$smart_info" | grep "Serial Number:" | cut -d: -f2 | xargs)
            [ -z "$serial" ] && serial="Unknown"
            
            # Detect spin state (for HDDs)
            local power_mode=$(run_privileged smartctl -n standby /dev/$disk 2>&1 || true)
            if echo "$power_mode" | grep -qi "STANDBY"; then
                spinning="standby"
            elif echo "$power_mode" | grep -qi "ACTIVE\|IDLE"; then
                spinning="spinning"
            else
                spinning="unknown"
            fi
            
            # Build JSON for this disk
            local disk_json=$(jq -n \
                --arg name "$disk" \
                --arg temp "$temp" \
                --arg health "$health" \
                --argjson errors "$errors" \
                --arg model "$model" \
                --arg serial "$serial" \
                --arg spinning "$spinning" \
                '{
                    name: $name,
                    temperature: (if $temp == "null" or $temp == "" then null else ($temp | tonumber) end),
                    health: $health,
                    errors: $errors,
                    model: $model,
                    serial: $serial,
                    spin_state: $spinning
                }')
            
            disk_array+=("$disk_json")
        done
        
        if (( ${#disk_array[@]} > 0 )); then
            disks_json=$(printf '%s\n' "${disk_array[@]}" | jq -s '.')
        fi
    fi
    
    echo "$disks_json"
}

# Collect ZFS pool data
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

# Collect libvirt VMs
collect_vms() {
    local vms_json='{"domains":[],"available":false}'

    if command -v virsh &>/dev/null; then
        # Get list of all VMs (running and stopped)
        local vms=$(virsh list --all 2>/dev/null | tail -n +3 | head -n -1 | awk 'NF > 0 {
            # Extract ID, name, and state
            id = ($1 == "-" ? "null" : $1)
            state = ""
            # Everything after the second field is the state
            for (i=3; i<=NF; i++) state = state $i " "
            gsub(/^[ \t]+|[ \t]+$/, "", state)
            # Name is the second field
            name = $2
            gsub(/"/, "\\\"", name)
            gsub(/"/, "\\\"", state)
            printf "{\"id\":%s,\"name\":\"%s\",\"state\":\"%s\"}\n", id, name, state
        }' | jq -s '.' 2>/dev/null || echo "[]")

        if [ "$vms" != "[]" ]; then
            vms_json=$(jq -n --argjson domains "$vms" '{domains: $domains, available: true}')
        else
            vms_json='{"domains":[],"available":true}'
        fi
    fi

    echo "$vms_json"
}

# Collect CPU voltage readings
collect_cpu_voltage() {
    local voltage_json="null"

    # Try to read CPU voltage from hwmon
    local voltage_files=(/sys/class/hwmon/*/in*_input)
    if [ -e "${voltage_files[0]}" ]; then
        # Read first available voltage sensor
        for vfile in "${voltage_files[@]}"; do
            if [ -r "$vfile" ]; then
                # Voltage is in millivolts, convert to volts
                local mv=$(cat "$vfile" 2>/dev/null || echo "0")
                local volts=$(echo "scale=3; $mv / 1000" | bc 2>/dev/null || echo "0")
                voltage_json="$volts"
                break
            fi
        done
    fi

    echo "$voltage_json"
}

# Collect USB devices
collect_usb_devices() {
    local usb_json="[]"
    
    if command -v lsusb &>/dev/null; then
        usb_json=$(lsusb 2>/dev/null | while read -r line; do
            bus=$(echo "$line" | awk '{print $2}')
            device=$(echo "$line" | awk '{print $4}' | tr -d ':')
            # Get everything after "ID xxxx:xxxx "
            name=$(echo "$line" | sed 's/.*ID [0-9a-f]*:[0-9a-f]* //')
            # Escape quotes for JSON
            name=$(echo "$name" | sed 's/"/\\"/g')
            echo "{\"bus\":\"$bus\",\"device\":\"$device\",\"name\":\"$name\"}"
        done | jq -s '.' 2>/dev/null || echo "[]")
    fi
    
    echo "$usb_json"
}

# Collect PCI devices
collect_pci_devices() {
    local pci_json="[]"
    
    if command -v lspci &>/dev/null; then
        pci_json=$(lspci 2>/dev/null | awk '{
            slot=$1;
            # Get everything after the slot
            idx=index($0, " ");
            if (idx > 0) {
                name=substr($0, idx+1);
                gsub(/"/, "\\\"", name);
                printf "{\"slot\":\"%s\",\"name\":\"%s\"}\n", slot, name
            }
        }' | jq -s '.' 2>/dev/null || echo "[]")
    fi
    
    echo "$pci_json"
}

# Collect package versions
collect_package_versions() {
    local docker_ver="not installed"
    local systemd_ver="not installed"
    local openssl_ver="not installed"
    local kernel_ver=$(uname -r)
    
    command -v docker &>/dev/null && docker_ver=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo "error")
    command -v systemctl &>/dev/null && systemd_ver=$(systemctl --version 2>/dev/null | head -1 | awk '{print $2}' || echo "error")
    command -v openssl &>/dev/null && openssl_ver=$(openssl version 2>/dev/null | awk '{print $2}' || echo "error")
    
    jq -n \
        --arg docker "$docker_ver" \
        --arg systemd "$systemd_ver" \
        --arg kernel "$kernel_ver" \
        --arg openssl "$openssl_ver" \
        '{
            docker: $docker,
            systemd: $systemd,
            kernel: $kernel,
            openssl: $openssl
        }'
}

# === Main Data Collection ===

# Collect system data
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
    
    # Kernel
    local kernel=$(uname -r)
    data=$(echo "$data" | jq --arg val "$kernel" '.os += {kernel: $val}')
    
    # Boot Mode
    local boot_mode=$(detect_boot_mode)
    data=$(echo "$data" | jq --arg val "$boot_mode" '.os += {boot_mode: $val}')
    
    # Uptime
    local uptime_seconds=$(cut -d' ' -f1 /proc/uptime | cut -d'.' -f1)
    local boot_time=$(date -d "@$(($(date +%s) - uptime_seconds))" +"%Y-%m-%d %H:%M")
    data=$(echo "$data" | jq --argjson val "$uptime_seconds" --arg boot "$boot_time" \
        '. + {uptime_seconds: $val, boot_time: $boot}')
    
    # Hardware Info (DMI/SMBIOS)
    local hw_info=$(collect_hardware_info)
    if [ "$hw_info" != "{}" ]; then
        data=$(echo "$data" | jq --argjson hw "$hw_info" '. + {hardware: $hw}')
    fi
    
    # Memory Modules
    local mem_modules=$(collect_memory_modules)
    if [ "$mem_modules" != "[]" ]; then
        data=$(echo "$data" | jq --argjson modules "$mem_modules" '. + {memory_modules: $modules}')
    fi
    
    # CPU Info (enhanced)
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    local cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
    local cpu_threads=$(nproc)
    local cpu_sockets=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
    [ "$cpu_sockets" -eq 0 ] && cpu_sockets=1
    local cores_per_socket=$((cpu_cores / cpu_sockets))

    # CPU speeds
    local cpu_cur_mhz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null | awk '{printf "%.0f", $1/1000}' || echo "0")
    local cpu_min_mhz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null | awk '{printf "%.0f", $1/1000}' || echo "0")
    local cpu_max_mhz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null | awk '{printf "%.0f", $1/1000}' || echo "0")

    # CPU voltage
    local cpu_voltage=$(collect_cpu_voltage)

    # Socket type from lscpu
    local cpu_socket="Unknown"
    if command -v lscpu &>/dev/null; then
        cpu_socket=$(lscpu 2>/dev/null | grep -i "Socket(s):" | awk '{print $2}')
        [ -z "$cpu_socket" ] && cpu_socket="Unknown"
    fi

    local load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d'.' -f1)
    [ -z "$cpu_usage" ] && cpu_usage=0

    data=$(echo "$data" | jq --arg model "$cpu_model" \
        --argjson cores "$cpu_cores" \
        --argjson threads "$cpu_threads" \
        --argjson sockets "$cpu_sockets" \
        --argjson cores_per_socket "$cores_per_socket" \
        --arg socket_type "$cpu_socket" \
        --argjson cur_mhz "$cpu_cur_mhz" \
        --argjson min_mhz "$cpu_min_mhz" \
        --argjson max_mhz "$cpu_max_mhz" \
        --argjson voltage "$cpu_voltage" \
        --arg load "$load_avg" \
        --argjson usage "$cpu_usage" \
        '. + {cpu: {
            model: $model,
            cores: $cores,
            threads: $threads,
            sockets: $sockets,
            cores_per_socket: $cores_per_socket,
            socket_type: $socket_type,
            speed_mhz: {current: $cur_mhz, min: $min_mhz, max: $max_mhz},
            voltage: $voltage,
            load_avg: $load,
            usage_percent: $usage
        }}')
    
    # Check CPU load
    if (( cpu_usage > CPU_LOAD_CRIT )); then
        alerts+=("{\"severity\": \"critical\", \"message\": \"CPU load: ${cpu_usage}% (critical)\", \"value\": $cpu_usage}")
    elif (( cpu_usage > CPU_LOAD_WARN )); then
        alerts+=("{\"severity\": \"warning\", \"message\": \"CPU load: ${cpu_usage}% (warning)\", \"value\": $cpu_usage}")
    fi
    
    # Memory Info (enhanced with swap)
    local mem_total=$(free -b | awk '/^Mem:/ {print $2}')
    local mem_used=$(free -b | awk '/^Mem:/ {print $3}')
    local mem_free=$(free -b | awk '/^Mem:/ {print $4}')
    local mem_available=$(free -b | awk '/^Mem:/ {print $7}')
    local mem_percent=$((mem_used * 100 / mem_total))
    
    # Swap stats
    local swap_total=$(free -b | awk '/^Swap:/ {print $2}')
    local swap_used=$(free -b | awk '/^Swap:/ {print $3}')
    local swap_free=$(free -b | awk '/^Swap:/ {print $4}')
    local swap_percent=0
    [ "$swap_total" -gt 0 ] && swap_percent=$((swap_used * 100 / swap_total))
    
    data=$(echo "$data" | jq --argjson total "$mem_total" --argjson used "$mem_used" \
        --argjson free "$mem_free" --argjson available "$mem_available" --argjson percent "$mem_percent" \
        --argjson swap_total "$swap_total" --argjson swap_used "$swap_used" \
        --argjson swap_free "$swap_free" --argjson swap_percent "$swap_percent" \
        '. + {memory: {
            total: $total, used: $used, free: $free, available: $available, percent: $percent,
            swap: {total: $swap_total, used: $swap_used, free: $swap_free, percent: $swap_percent}
        }}')
    
    # Check memory usage
    if (( mem_percent > MEM_USAGE_CRIT )); then
        alerts+=("{\"severity\": \"critical\", \"message\": \"Memory usage: ${mem_percent}% (critical)\", \"value\": $mem_percent}")
    elif (( mem_percent > MEM_USAGE_WARN )); then
        alerts+=("{\"severity\": \"warning\", \"message\": \"Memory usage: ${mem_percent}% (warning)\", \"value\": $mem_percent}")
    fi
    
    # Disk Info (filesystem) - handle spaces in filesystem/mount paths
    local disks_json=$(df -BG | grep -v "^tmpfs\|^devtmpfs\|^overlay\|^shm\|^run\|^fuse\|^snap\|^/dev/loop" | \
        awk 'NR>1 {
            # Find the field ending in % (Use% column)
            pct_idx = 0
            for (i = 1; i <= NF; i++) { if ($i ~ /%$/) { pct_idx = i; break } }
            if (pct_idx < 5) next
            pcent = $pct_idx; avail = $(pct_idx - 1); used = $(pct_idx - 2); size = $(pct_idx - 3)
            fs = $1; for (i = 2; i <= pct_idx - 4; i++) fs = fs " " $i
            mount = $(pct_idx + 1); for (i = pct_idx + 2; i <= NF; i++) mount = mount " " $i
            gsub(/G/, "", size); gsub(/G/, "", used); gsub(/G/, "", avail); gsub(/%/, "", pcent)
            gsub(/"/, "\\\"", fs); gsub(/"/, "\\\"", mount)
            if (size+0 == size && used+0 == used && avail+0 == avail && pcent+0 == pcent) {
                print "{\"filesystem\":\"" fs "\",\"size_gb\":" size ",\"used_gb\":" used ",\"free_gb\":" avail ",\"percent\":" pcent ",\"mount\":\"" mount "\"}"
            }
        }' | jq -s '.')
    
    data=$(echo "$data" | jq --argjson disks "$disks_json" '. + {disks: $disks}')
    
    # Check disk usage
    while IFS= read -r disk; do
        [[ -z "$disk" ]] && continue
        local mount=$(echo "$disk" | jq -r '.mount')
        local percent=$(echo "$disk" | jq -r '.percent')
        
        if (( percent > DISK_USAGE_CRIT )); then
            alerts+=("{\"severity\": \"critical\", \"message\": \"Disk $mount: ${percent}% (critical)\", \"value\": $percent}")
        elif (( percent > DISK_USAGE_WARN )); then
            alerts+=("{\"severity\": \"warning\", \"message\": \"Disk $mount: ${percent}% (warning)\", \"value\": $percent}")
        fi
    done < <(echo "$disks_json" | jq -c '.[]')
    
    # SMART Disk Data
    local smart_data=$(collect_smart_data)
    if [ "$smart_data" != "[]" ]; then
        data=$(echo "$data" | jq --argjson smart "$smart_data" '. + {smart_disks: $smart}')
        
        # Check disk temperatures
        while IFS= read -r disk; do
            [[ -z "$disk" ]] && continue
            local disk_name=$(echo "$disk" | jq -r '.name')
            local temp=$(echo "$disk" | jq -r '.temperature // 0')
            local health=$(echo "$disk" | jq -r '.health')
            local errors=$(echo "$disk" | jq -r '.errors // 0')
            
            # Temperature alerts
            if [ "$temp" != "null" ] && [ "$temp" != "0" ]; then
                if (( temp > DISK_TEMP_CRIT )); then
                    alerts+=("{\"severity\": \"critical\", \"message\": \"Disk $disk_name temperature: ${temp}°C (critical)\", \"value\": $temp}")
                elif (( temp > DISK_TEMP_WARN )); then
                    alerts+=("{\"severity\": \"warning\", \"message\": \"Disk $disk_name temperature: ${temp}°C (warning)\", \"value\": $temp}")
                fi
            fi
            
            # Health alerts
            if [ "$health" = "FAILED" ]; then
                alerts+=("{\"severity\": \"critical\", \"message\": \"Disk $disk_name SMART health: FAILED\", \"value\": 1}")
            fi
            
            # Error alerts
            if (( errors > 0 )); then
                alerts+=("{\"severity\": \"warning\", \"message\": \"Disk $disk_name has $errors SMART errors\", \"value\": $errors}")
            fi
        done < <(echo "$smart_data" | jq -c '.[]')
    fi
    
    # Network Interfaces (enhanced with MAC, speed, model/vendor)
    local interfaces_json=$(ip -j addr show 2>/dev/null | jq '[.[] | select(.ifname != "lo") | {
        name: .ifname,
        state: .operstate,
        mac: .address,
        addresses: [.addr_info[] | {family: .family, address: .local}]
    }]')

    # Add interface speeds, model, and vendor
    local enhanced_ifaces="[]"
    while IFS= read -r iface; do
        [[ -z "$iface" ]] && continue
        local iface_name=$(echo "$iface" | jq -r '.name')
        local speed="unknown"
        local driver="unknown"
        local model="unknown"

        # Try to get speed from sysfs
        if [ -f "/sys/class/net/$iface_name/speed" ]; then
            speed=$(cat "/sys/class/net/$iface_name/speed" 2>/dev/null || echo "unknown")
            [ "$speed" = "-1" ] && speed="unknown"
        fi

        # Use ethtool for driver/model info and speed fallback
        if command -v ethtool &>/dev/null; then
            local ethtool_out=$(ethtool -i "$iface_name" 2>/dev/null || true)

            if [ -n "$ethtool_out" ]; then
                # Get driver name
                driver=$(echo "$ethtool_out" | grep "^driver:" | awk '{print $2}' || echo "unknown")

                # Try to get bus info as model identifier
                local bus_info=$(echo "$ethtool_out" | grep "^bus-info:" | awk '{print $2}' || echo "")
                [ -n "$bus_info" ] && model="$bus_info"
            fi

            # Try speed from ethtool if not found in sysfs
            if [ "$speed" = "unknown" ]; then
                speed=$(ethtool "$iface_name" 2>/dev/null | grep "Speed:" | awk '{print $2}' | sed 's/Mb\/s//;s/Unknown!/unknown/' || echo "unknown")
            fi
        fi

        local updated_iface=$(echo "$iface" | jq \
            --arg speed "$speed" \
            --arg driver "$driver" \
            --arg model "$model" \
            '. + {speed_mbps: $speed, driver: $driver, model: $model}')
        enhanced_ifaces=$(echo "$enhanced_ifaces" | jq --argjson iface "$updated_iface" '. + [$iface]')
    done < <(echo "$interfaces_json" | jq -c '.[]')

    data=$(echo "$data" | jq --argjson ifaces "$enhanced_ifaces" '. + {network_interfaces: $ifaces}')
    
    # USB Devices
    local usb_devices=$(collect_usb_devices)
    if [ "$usb_devices" != "[]" ]; then
        data=$(echo "$data" | jq --argjson usb "$usb_devices" '. + {usb_devices: $usb}')
    fi
    
    # PCI Devices
    local pci_devices=$(collect_pci_devices)
    if [ "$pci_devices" != "[]" ]; then
        data=$(echo "$data" | jq --argjson pci "$pci_devices" '. + {pci_devices: $pci}')
    fi
    
    # ZFS Data
    local zfs_data=$(collect_zfs_data)
    if echo "$zfs_data" | jq -e '.available' >/dev/null 2>&1; then
        data=$(echo "$data" | jq --argjson zfs "$zfs_data" '. + {zfs: $zfs}')
        
        # Check ZFS pool health
        while IFS= read -r pool; do
            [[ -z "$pool" ]] && continue
            local pool_name=$(echo "$pool" | jq -r '.name')
            local pool_health=$(echo "$pool" | jq -r '.health')
            
            if [ "$pool_health" != "ONLINE" ]; then
                alerts+=("{\"severity\": \"critical\", \"message\": \"ZFS pool $pool_name health: $pool_health\", \"value\": 1}")
            fi
        done < <(echo "$zfs_data" | jq -c '.pools[]')
    fi
    
    # Package Versions
    local versions=$(collect_package_versions)
    data=$(echo "$data" | jq --argjson versions "$versions" '. + {versions: $versions}')
    
    # Docker containers
    if command -v docker &>/dev/null; then
        local docker_json=$(docker ps -a --format '{{json .}}' 2>/dev/null | jq -s '[.[] | {name: .Names, status: .Status, state: .State, image: .Image}]' || echo '[]')
        data=$(echo "$data" | jq --argjson containers "$docker_json" '. + {docker: {containers: $containers}}')
        
        # Check for exited/unhealthy containers
        local exited=$(echo "$docker_json" | jq '[.[] | select(.state == "exited")] | length')
        if (( exited > 0 )); then
            local exited_list=$(echo "$docker_json" | jq -r '[.[] | select(.state == "exited") | .name] | join(", ")')
            alerts+=("{\"severity\": \"warning\", \"message\": \"$exited exited containers: $exited_list\", \"value\": $exited}")
        fi
        
        local unhealthy=$(echo "$docker_json" | jq '[.[] | select(.status | test("unhealthy|restarting"; "i"))] | length')
        if (( unhealthy > 0 )); then
            local unhealthy_list=$(echo "$docker_json" | jq -r '[.[] | select(.status | test("unhealthy|restarting"; "i")) | .name] | join(", ")')
            alerts+=("{\"severity\": \"warning\", \"message\": \"$unhealthy unhealthy containers: $unhealthy_list\", \"value\": $unhealthy}")
        fi
    fi
    
    # Systemd services (failed)
    if command -v systemctl &>/dev/null; then
        local failed_services=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
        data=$(echo "$data" | jq --argjson failed "$failed_services" '. + {systemd: {failed_services: $failed}}')
        
        if (( failed_services > 0 )); then
            alerts+=("{\"severity\": \"warning\", \"message\": \"$failed_services failed systemd services\", \"value\": $failed_services}")
        fi
    fi
    
    # GPU Info
    if command -v nvidia-smi &>/dev/null; then
        local gpu_json=$(nvidia-smi --query-gpu=name,memory.total,memory.used,temperature.gpu,driver_version --format=csv,noheader 2>/dev/null | \
            awk -F', ' '{print "{\"name\":\"" $1 "\",\"memory_total\":\"" $2 "\",\"memory_used\":\"" $3 "\",\"temperature\":\"" $4 "\",\"driver\":\"" $5 "\"}"}' | jq -s '.' || echo '[]')
        data=$(echo "$data" | jq --argjson gpus "$gpu_json" '. + {gpu: $gpus}')
    elif command -v lspci &>/dev/null; then
        local gpu_info=$(lspci 2>/dev/null | grep -iE "vga|3d|display" | head -1)
        if [[ -n "$gpu_info" ]]; then
            data=$(echo "$data" | jq --arg info "$gpu_info" '. + {gpu: [{name: $info}]}')
        fi
    fi
    
    # Tailscale status
    if command -v tailscale &>/dev/null; then
        local ts_status=$(tailscale status --self --json 2>/dev/null || echo '{}')
        data=$(echo "$data" | jq --argjson ts "$ts_status" '. + {tailscale: $ts}')
    fi

    # VMs (libvirt)
    local vms_data=$(collect_vms)
    if echo "$vms_data" | jq -e '.available' >/dev/null 2>&1; then
        data=$(echo "$data" | jq --argjson vms "$vms_data" '. + {vms: $vms}')

        # Check for stopped VMs as potential alerts
        local stopped_vms=$(echo "$vms_data" | jq '[.domains[]? | select(.state | test("shut off|paused"; "i"))] | length')
        if (( stopped_vms > 0 )); then
            local vm_list=$(echo "$vms_data" | jq -r '[.domains[]? | select(.state | test("shut off|paused"; "i")) | .name] | join(", ")')
            alerts+=("{\"severity\": \"info\", \"message\": \"$stopped_vms VM(s) not running: $vm_list\", \"value\": $stopped_vms}")
        fi
    fi

    # Build final output with alerts
    local alerts_json
    if (( ${#alerts[@]} > 0 )); then
        alerts_json=$(printf '%s\n' "${alerts[@]}" | jq -s '.')
    else
        alerts_json="[]"
    fi
    
    jq -n --argjson data "$data" --argjson alerts "$alerts_json" \
        '{data: $data, alerts: $alerts}'
}

# Generate markdown inventory
generate_markdown_inventory() {
    local json_data="$1"
    
    local hostname=$(echo "$json_data" | jq -r '.data.hostname')
    local os_name=$(echo "$json_data" | jq -r '.data.os.name // "Unknown"')
    local kernel=$(echo "$json_data" | jq -r '.data.os.kernel // "Unknown"')
    local boot_time=$(echo "$json_data" | jq -r '.data.boot_time // "Unknown"')
    local boot_mode=$(echo "$json_data" | jq -r '.data.os.boot_mode // "Unknown"')
    
    cat <<EOF
# Linux Dashboard: $hostname
Generated: $(date)

## System Information
- **Hostname:** $hostname
- **OS:** $os_name
- **Kernel:** $kernel
- **Boot Mode:** $boot_mode
- **Booted:** $boot_time

EOF
    
    # Hardware Info
    if echo "$json_data" | jq -e '.data.hardware' >/dev/null 2>&1; then
        local sys_mfg=$(echo "$json_data" | jq -r '.data.hardware.system.manufacturer // "Unknown"')
        local sys_prod=$(echo "$json_data" | jq -r '.data.hardware.system.product // "Unknown"')
        local sys_serial=$(echo "$json_data" | jq -r '.data.hardware.system.serial // "Unknown"')
        local board_mfg=$(echo "$json_data" | jq -r '.data.hardware.baseboard.manufacturer // "Unknown"')
        local board_prod=$(echo "$json_data" | jq -r '.data.hardware.baseboard.product // "Unknown"')
        
        cat <<EOF
## Hardware
- **System:** $sys_mfg $sys_prod
- **Serial:** $sys_serial
- **Baseboard:** $board_mfg $board_prod

EOF
    fi
    
    # CPU
    local cpu_model=$(echo "$json_data" | jq -r '.data.cpu.model')
    local cpu_cores=$(echo "$json_data" | jq -r '.data.cpu.cores')
    local cpu_threads=$(echo "$json_data" | jq -r '.data.cpu.threads // .data.cpu.cores')
    local cpu_sockets=$(echo "$json_data" | jq -r '.data.cpu.sockets // 1')
    local cpu_usage=$(echo "$json_data" | jq -r '.data.cpu.usage_percent')
    local cpu_load=$(echo "$json_data" | jq -r '.data.cpu.load_avg')
    local cpu_cur=$(echo "$json_data" | jq -r '.data.cpu.speed_mhz.current // 0')
    local cpu_max=$(echo "$json_data" | jq -r '.data.cpu.speed_mhz.max // 0')
    
    cat <<EOF
## CPU
- **Model:** $cpu_model
- **Topology:** $cpu_cores cores / $cpu_threads threads ($cpu_sockets socket(s))
- **Speed:** ${cpu_cur}MHz current / ${cpu_max}MHz max
- **Usage:** ${cpu_usage}%
- **Load Average:** $cpu_load

EOF
    
    # Memory
    local mem_total_gb=$(echo "$json_data" | jq -r '(.data.memory.total // 0) / 1024 / 1024 / 1024 | floor')
    local mem_used_gb=$(echo "$json_data" | jq -r '(.data.memory.used // 0) / 1024 / 1024 / 1024 | floor')
    local mem_free_gb=$(echo "$json_data" | jq -r '(.data.memory.free // 0) / 1024 / 1024 / 1024 | floor')
    local mem_percent=$(echo "$json_data" | jq -r '.data.memory.percent // 0')
    local swap_total_gb=$(echo "$json_data" | jq -r '(.data.memory.swap.total // 0) / 1024 / 1024 / 1024 | floor')
    local swap_used_gb=$(echo "$json_data" | jq -r '(.data.memory.swap.used // 0) / 1024 / 1024 / 1024 | floor')
    local swap_percent=$(echo "$json_data" | jq -r '.data.memory.swap.percent // 0')
    
    cat <<EOF
## Memory
- **Total:** ${mem_total_gb}GB
- **Used:** ${mem_used_gb}GB (${mem_percent}%)
- **Free:** ${mem_free_gb}GB
- **Swap:** ${swap_used_gb}GB / ${swap_total_gb}GB (${swap_percent}%)

EOF
    
    # Memory Modules
    local module_count=$(echo "$json_data" | jq '[.data.memory_modules[]?] | length')
    if (( module_count > 0 )); then
        cat <<EOF
## Memory Modules ($module_count DIMMs)
EOF
        echo "$json_data" | jq -r '.data.memory_modules[]? | "- \(.size) \(.type // "Unknown") @ \(.speed // "Unknown") (\(.manufacturer // "Unknown")) - \(.locator // "Unknown")"'
        echo ""
    fi
    
    # Filesystem Disks
    local disk_count=$(echo "$json_data" | jq '[.data.disks[]?] | length')
    
    cat <<EOF
## Filesystems ($disk_count total)
EOF
    echo "$json_data" | jq -r '.data.disks[]? | "- **\(.mount)**: \(.used_gb)GB / \(.size_gb)GB used (\(.percent)%) | \(.filesystem)"'
    echo ""
    
    # SMART Disk Info
    local smart_count=$(echo "$json_data" | jq '[.data.smart_disks[]?] | length')
    if (( smart_count > 0 )); then
        cat <<EOF
## Physical Disks - SMART ($smart_count total)
EOF
        echo "$json_data" | jq -r '.data.smart_disks[]? | 
            "- **\(.name)** (\(.model)): \(if .temperature then "\(.temperature)°C" else "N/A" end) | \(.health) | \(if .spin_state == "spinning" then "⚡ spinning" elif .spin_state == "standby" then "💤 standby" else "" end)\(if .errors > 0 then " | ❌ \(.errors) errors" else "" end)"'
        echo ""
    fi
    
    # ZFS Pools
    if echo "$json_data" | jq -e '.data.zfs.available' >/dev/null 2>&1; then
        local zfs_pool_count=$(echo "$json_data" | jq '[.data.zfs.pools[]?] | length')
        if (( zfs_pool_count > 0 )); then
            cat <<EOF
## ZFS Pools ($zfs_pool_count total)
EOF
            echo "$json_data" | jq -r '.data.zfs.pools[]? | "- **\(.name)**: \(.size) total | \(.allocated) used | \(.free) free | \(.health)"'
            echo ""
        fi
    fi
    
    # Network
    local net_count=$(echo "$json_data" | jq '[.data.network_interfaces[]?] | length')
    
    if (( net_count > 0 )); then
        cat <<EOF
## Network Interfaces ($net_count total)
EOF
        echo "$json_data" | jq -r '.data.network_interfaces[]? | 
            "- **\(.name)**: \(.state) | MAC: \(.mac // "N/A") | Speed: \(.speed_mbps // "unknown")Mbps | \(.addresses | map(.address) | join(", "))"'
        echo ""
    fi
    
    # USB Devices
    local usb_count=$(echo "$json_data" | jq '[.data.usb_devices[]?] | length')
    if (( usb_count > 0 )); then
        cat <<EOF
## USB Devices ($usb_count total)
EOF
        echo "$json_data" | jq -r '.data.usb_devices[]? | "- Bus \(.bus) Device \(.device): \(.name)"' | head -15
        (( usb_count > 15 )) && echo "- *(+$((usb_count - 15)) more)*"
        echo ""
    fi
    
    # PCI Devices
    local pci_count=$(echo "$json_data" | jq '[.data.pci_devices[]?] | length')
    if (( pci_count > 0 )); then
        cat <<EOF
## PCI Devices ($pci_count total)
EOF
        echo "$json_data" | jq -r '.data.pci_devices[]? | "- \(.slot): \(.name)"' | head -15
        (( pci_count > 15 )) && echo "- *(+$((pci_count - 15)) more)*"
        echo ""
    fi
    
    # Docker
    if echo "$json_data" | jq -e '.data.docker' >/dev/null 2>&1; then
        local docker_total=$(echo "$json_data" | jq '[.data.docker.containers[]?] | length')
        local docker_running=$(echo "$json_data" | jq '[.data.docker.containers[]? | select(.state == "running")] | length')
        local docker_exited=$(echo "$json_data" | jq '[.data.docker.containers[]? | select(.state == "exited")] | length')
        
        cat <<EOF
## Docker Containers
- **Total:** $docker_total ($docker_running running, $docker_exited stopped)

EOF
        
        if (( docker_exited > 0 )); then
            echo "**⚠️  Exited Containers:**"
            echo "$json_data" | jq -r '.data.docker.containers[]? | select(.state == "exited") | "- \(.name): \(.status)"'
            echo ""
        fi
        
        local docker_unhealthy=$(echo "$json_data" | jq '[.data.docker.containers[]? | select(.status | test("unhealthy|restarting"; "i"))] | length')
        if (( docker_unhealthy > 0 )); then
            echo "**⚠️  Unhealthy Containers:**"
            echo "$json_data" | jq -r '.data.docker.containers[]? | select(.status | test("unhealthy|restarting"; "i")) | "- \(.name): \(.status)"'
            echo ""
        fi
    fi
    
    # GPU
    if echo "$json_data" | jq -e '.data.gpu' >/dev/null 2>&1; then
        local gpu_count=$(echo "$json_data" | jq '[.data.gpu[]?] | length')
        cat <<EOF
## GPU ($gpu_count total)
EOF
        echo "$json_data" | jq -r '.data.gpu[]? | "- \(.name // "Unknown")\(if .temperature then " | \(.temperature)°C" else "" end)\(if .driver then " | Driver: \(.driver)" else "" end)"'
        echo ""
    fi
    
    # Tailscale
    if echo "$json_data" | jq -e '.data.tailscale.Self' >/dev/null 2>&1; then
        local ts_ip=$(echo "$json_data" | jq -r '.data.tailscale.Self.TailscaleIPs[0] // "N/A"')
        local ts_online=$(echo "$json_data" | jq -r '.data.tailscale.Self.Online // false')
        
        cat <<EOF
## Tailscale
- **IP:** $ts_ip
- **Status:** $(if [[ "$ts_online" == "true" ]]; then echo "🟢 Online"; else echo "🔴 Offline"; fi)

EOF
    fi
    
    # Systemd
    if echo "$json_data" | jq -e '.data.systemd' >/dev/null 2>&1; then
        local failed=$(echo "$json_data" | jq -r '.data.systemd.failed_services // 0')
        cat <<EOF
## Systemd Services
- **Failed:** $failed

EOF
    fi
    
    # Package Versions
    if echo "$json_data" | jq -e '.data.versions' >/dev/null 2>&1; then
        local docker_ver=$(echo "$json_data" | jq -r '.data.versions.docker // "N/A"')
        local systemd_ver=$(echo "$json_data" | jq -r '.data.versions.systemd // "N/A"')
        local kernel_ver=$(echo "$json_data" | jq -r '.data.versions.kernel // "N/A"')
        local openssl_ver=$(echo "$json_data" | jq -r '.data.versions.openssl // "N/A"')
        
        cat <<EOF
## Package Versions
- **Kernel:** $kernel_ver
- **Docker:** $docker_ver
- **systemd:** $systemd_ver
- **OpenSSL:** $openssl_ver

EOF
    fi
    
    # Health Summary
    local alert_count=$(echo "$json_data" | jq '[.alerts[]?] | length')
    
    cat <<EOF
## Health Summary
EOF
    
    if (( alert_count == 0 )); then
        echo "✅ **All systems healthy**"
    else
        echo "⚠️  **$alert_count alert(s):**"
        echo "$json_data" | jq -r '.alerts[]? | "- [\(.severity | ascii_upcase)] \(.message)"'
    fi
    
    echo ""
}

# === Remote Collection Functions ===

# Get list of Linux hosts from ssh-inventory
get_linux_hosts() {
    if [[ ! -f "$SSH_INVENTORY_FILE" ]]; then
        log_warn "SSH inventory not found: $SSH_INVENTORY_FILE"
        echo ""
        return
    fi
    
    # Extract reachable Linux hosts from inventory
    jq -r '.[] | select(.os_type == "linux" and .reachable == true) | .hostname' "$SSH_INVENTORY_FILE" 2>/dev/null || echo ""
}

# Collect data from a single remote host using the collector script
collect_remote_host() {
    local host="$1"
    local result
    
    log_debug "Collecting from remote host: $host"
    
    # Stream the collector script to the remote host
    if result=$(timeout 120 ssh $SSH_OPTIONS "$host" "bash -s" < "$COLLECTOR_SCRIPT" 2>/dev/null); then
        # Validate JSON
        if echo "$result" | jq -e . >/dev/null 2>&1; then
            # Add ssh_target field to data
            echo "$result" | jq --arg target "$host" '.data.ssh_target = $target'
            return 0
        else
            log_warn "Invalid JSON from $host"
            return 1
        fi
    else
        log_warn "Remote collection failed for $host"
        return 1
    fi
}

# Collect data from all remote Linux hosts
collect_all_remote_hosts() {
    local hosts
    local -a results=()
    local -a failed_hosts=()
    local -a all_alerts=()
    
    hosts=$(get_linux_hosts)
    
    if [[ -z "$hosts" ]]; then
        log_error "No Linux hosts found in inventory"
        return 1
    fi
    
    local host_count=$(echo "$hosts" | wc -l)
    log_info "Collecting from $host_count remote Linux hosts..."
    
    while IFS= read -r host; do
        [[ -z "$host" ]] && continue
        
        log_info "  → $host"
        
        local host_data
        if host_data=$(collect_remote_host "$host"); then
            results+=("$host_data")
            
            # Collect alerts with host prefix
            local host_alerts=$(echo "$host_data" | jq -c --arg h "$host" '.alerts[]? | .message = "[\($h)] " + .message')
            if [[ -n "$host_alerts" ]]; then
                while IFS= read -r alert; do
                    [[ -n "$alert" ]] && all_alerts+=("$alert")
                done <<< "$host_alerts"
            fi
            
            log_success "    ✓ collected"
        else
            failed_hosts+=("$host")
            log_warn "    ✗ failed"
        fi
    done <<< "$hosts"
    
    # Build combined JSON using temp files to avoid "argument list too long"
    local tmp_hosts="/tmp/linux-dash-hosts-$$.json"
    local tmp_alerts="/tmp/linux-dash-alerts-$$.json"
    local tmp_failed="/tmp/linux-dash-failed-$$.json"
    
    # Write hosts to temp file
    if (( ${#results[@]} > 0 )); then
        printf '%s\n' "${results[@]}" | jq -s '[.[] | {
            hostname: .data.hostname,
            ssh_target: .data.ssh_target,
            data: .data,
            alerts: .alerts
        }]' > "$tmp_hosts"
    else
        echo "[]" > "$tmp_hosts"
    fi
    
    # Write alerts to temp file
    if (( ${#all_alerts[@]} > 0 )); then
        printf '%s\n' "${all_alerts[@]}" | jq -s '.' > "$tmp_alerts"
    else
        echo "[]" > "$tmp_alerts"
    fi
    
    # Write failed hosts to temp file
    if (( ${#failed_hosts[@]} > 0 )); then
        printf '%s\n' "${failed_hosts[@]}" | jq -R . | jq -s '.' > "$tmp_failed"
    else
        echo "[]" > "$tmp_failed"
    fi
    
    # Combine using file inputs
    jq -n \
        --slurpfile hosts "$tmp_hosts" \
        --slurpfile alerts "$tmp_alerts" \
        --slurpfile failed "$tmp_failed" \
        '{
            mode: "multi-host",
            hosts: $hosts[0],
            alerts: $alerts[0],
            failed_hosts: $failed[0]
        }'
    
    # Cleanup temp files
    rm -f "$tmp_hosts" "$tmp_alerts" "$tmp_failed"
}

# Generate markdown for multi-host dashboard
generate_multihost_markdown() {
    local json_data="$1"
    local host_count=$(echo "$json_data" | jq '.hosts | length')
    local failed_count=$(echo "$json_data" | jq '.failed_hosts | length')
    local alert_count=$(echo "$json_data" | jq '.alerts | length')
    
    cat <<EOF
# Linux Dashboard - Multi-Host View
Generated: $(date)

## Summary
- **Hosts Collected:** $host_count
- **Failed Hosts:** $failed_count
- **Total Alerts:** $alert_count

EOF

    # Failed hosts warning
    if (( failed_count > 0 )); then
        echo "## ⚠️  Failed Hosts"
        echo "$json_data" | jq -r '.failed_hosts[]? | "- \(.)"'
        echo ""
    fi
    
    # Per-host summary table
    cat <<EOF
## Host Overview

| Host | OS | CPU% | Mem% | Alerts |
|------|-----|------|------|--------|
EOF
    echo "$json_data" | jq -r '.hosts[]? | "| \(.hostname) | \(.data.os.name // "Unknown" | split(" ")[0:2] | join(" ")) | \(.data.cpu.usage_percent // 0)% | \(.data.memory.percent // 0)% | \(.alerts | length) |"'
    echo ""

    # Per-host details
    echo "$json_data" | jq -c '.hosts[]?' | while IFS= read -r host_json; do
        [[ -z "$host_json" ]] && continue
        
        local hostname=$(echo "$host_json" | jq -r '.hostname')
        local os_name=$(echo "$host_json" | jq -r '.data.os.name // "Unknown"')
        local kernel=$(echo "$host_json" | jq -r '.data.os.kernel // "Unknown"')
        local cpu_model=$(echo "$host_json" | jq -r '.data.cpu.model // "Unknown"')
        local cpu_usage=$(echo "$host_json" | jq -r '.data.cpu.usage_percent // 0')
        local cpu_load=$(echo "$host_json" | jq -r '.data.cpu.load_avg // "N/A"')
        local mem_percent=$(echo "$host_json" | jq -r '.data.memory.percent // 0')
        local mem_total_gb=$(echo "$host_json" | jq -r '(.data.memory.total // 0) / 1024 / 1024 / 1024 | floor')
        local uptime_days=$(echo "$host_json" | jq -r '(.data.uptime_seconds // 0) / 86400 | floor')
        local docker_count=$(echo "$host_json" | jq -r '[.data.docker.containers[]?] | length')
        local host_alerts=$(echo "$host_json" | jq -r '.alerts | length')
        
        cat <<EOF
---
## 🖥️  $hostname

- **OS:** $os_name | **Kernel:** $kernel
- **CPU:** $cpu_model
- **CPU Usage:** ${cpu_usage}% | **Load:** $cpu_load
- **Memory:** ${mem_percent}% of ${mem_total_gb}GB
- **Uptime:** ${uptime_days} days
- **Docker Containers:** $docker_count
EOF

        # Disk summary
        local disk_count=$(echo "$host_json" | jq '[.data.disks[]?] | length')
        if (( disk_count > 0 )); then
            echo ""
            echo "**Filesystems:**"
            echo "$host_json" | jq -r '.data.disks[]? | "- \(.mount): \(.percent)% used (\(.used_gb)GB/\(.size_gb)GB)"'
        fi
        
        # ZFS summary
        local zfs_pool_count=$(echo "$host_json" | jq '[.data.zfs.pools[]?] | length')
        if (( zfs_pool_count > 0 )); then
            echo ""
            echo "**ZFS Pools:**"
            echo "$host_json" | jq -r '.data.zfs.pools[]? | "- \(.name): \(.health) (\(.allocated) / \(.size))"'
        fi
        
        # Alerts for this host
        if (( host_alerts > 0 )); then
            echo ""
            echo "**⚠️  Alerts:**"
            echo "$host_json" | jq -r '.alerts[]? | "- [\(.severity | ascii_upcase)] \(.message)"'
        fi
        
        echo ""
    done
    
    # Global alerts summary
    if (( alert_count > 0 )); then
        cat <<EOF
---
## 🚨 All Alerts

EOF
        echo "$json_data" | jq -r '.alerts[]? | "- [\(.severity | ascii_upcase)] \(.message)"'
    else
        echo "---"
        echo "## ✅ All Systems Healthy"
    fi
    
    echo ""
}

# === Main Script ===

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --local           Collect only from localhost (default)
  --remote          Collect from all Linux hosts in ssh-inventory
  --host=<name>     Collect from a specific remote host
  -h, --help        Show this help

Environment:
  REMOTE_MODE=true  Same as --remote
  
Examples:
  $0                 # Local collection only
  $0 --remote        # All Linux hosts
  $0 --host=tootie   # Specific host only
EOF
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --local)
                REMOTE_MODE="false"
                shift
                ;;
            --remote)
                REMOTE_MODE="true"
                shift
                ;;
            --host=*)
                SPECIFIC_HOST="${1#--host=}"
                REMOTE_MODE="single"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Initialize logging
    init_logging "$SCRIPT_NAME"
    
    log_info "Starting $SCRIPT_NAME (mode: ${REMOTE_MODE})"
    
    # Ensure state directory exists
    ensure_state_dir "$STATE_DIR"
    
    # Check for collector script in remote mode
    if [[ "$REMOTE_MODE" == "true" || "$REMOTE_MODE" == "single" ]]; then
        if [[ ! -f "$COLLECTOR_SCRIPT" ]]; then
            log_error "Collector script not found: $COLLECTOR_SCRIPT"
            exit 1
        fi
    fi
    
    local data_file="/tmp/linux-dash-data-$$.json"
    local is_multihost="false"
    
    if [[ "$REMOTE_MODE" == "true" ]]; then
        # Collect from all remote hosts
        log_info "Collecting from all remote Linux hosts..."
        if ! collect_all_remote_hosts > "$data_file"; then
            log_error "Remote collection failed"
            rm -f "$data_file"
            exit 1
        fi
        is_multihost="true"
        
    elif [[ "$REMOTE_MODE" == "single" ]]; then
        # Collect from specific host
        log_info "Collecting from specific host: $SPECIFIC_HOST"
        if ! collect_remote_host "$SPECIFIC_HOST" > "$data_file"; then
            log_error "Collection from $SPECIFIC_HOST failed"
            rm -f "$data_file"
            exit 1
        fi
        
    else
        # Local collection only (original behavior)
        log_info "Collecting local system data..."
        if ! collect_system_data > "$data_file"; then
            log_error "Data collection failed"
            rm -f "$data_file"
            exit 1
        fi
    fi
    
    # Write JSON state file (timestamped) using file input to avoid arg length limits
    if [[ "$is_multihost" == "true" ]]; then
        # Multi-host format
        jq \
            --argjson timestamp "$TIMESTAMP" \
            --arg script "$SCRIPT_NAME" \
            --arg version "$SCRIPT_VERSION" \
            --argjson exec_time "$(($(date +%s) - TIMESTAMP))" \
            '{
                timestamp: $timestamp,
                script: $script,
                version: $version,
                mode: "multi-host",
                hosts: .hosts,
                alerts: .alerts,
                failed_hosts: .failed_hosts,
                metadata: {
                    collected_from: "remote",
                    execution_time: "\($exec_time)s"
                }
            }' "$data_file" > "$JSON_FILE"
    else
        # Single-host format (original)
        jq \
            --argjson timestamp "$TIMESTAMP" \
            --arg script "$SCRIPT_NAME" \
            --arg version "$SCRIPT_VERSION" \
            --arg hostname "$(hostname)" \
            --argjson exec_time "$(($(date +%s) - TIMESTAMP))" \
            '{
                timestamp: $timestamp,
                script: $script,
                version: $version,
                data: .data,
                alerts: .alerts,
                metadata: {
                    hostname: $hostname,
                    execution_time: "\($exec_time)s"
                }
            }' "$data_file" > "$JSON_FILE"
    fi
    
    log_info "JSON state saved to: $JSON_FILE"
    
    # Update 'latest' symlink (relative path)
    ln -sf "$(basename "$JSON_FILE")" "$LATEST_LINK"
    
    # Convert to markdown inventory (read from file to avoid arg length limits)
    if [[ "$is_multihost" == "true" ]]; then
        generate_multihost_markdown "$(cat "$data_file")" > "$CURRENT_MD"
    else
        generate_markdown_inventory "$(cat "$data_file")" > "$CURRENT_MD"
    fi
    log_info "Markdown inventory saved to: $CURRENT_MD"
    
    # Clean up old state files
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"
    
    # Check for alerts
    local alert_count=$(jq -r '.alerts | length' "$data_file")
    
    if (( alert_count > 0 )); then
        local alert_msg
        if [[ "$is_multihost" == "true" ]]; then
            alert_msg=$(jq -r '.alerts[] | "[\(.severity | ascii_upcase)] \(.message)"' "$data_file" | head -10)
            notify_alert "Linux Dashboard: $alert_count issues across hosts" "$alert_msg" "normal"
        else
            alert_msg=$(jq -r '.alerts[] | "[\(.severity | ascii_upcase)] \(.message)"' "$data_file" | head -10)
            notify_alert "System Alert: $(hostname) ($alert_count issues)" "$alert_msg" "normal"
        fi
        log_warn "$alert_count alerts generated"
    fi
    
    # Cleanup temp data file
    rm -f "$data_file"
    
    log_success "$SCRIPT_NAME completed successfully"
}

# Run main function
main "$@"
