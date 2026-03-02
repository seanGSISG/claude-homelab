#!/bin/bash
# Glances REST API helper script
# Usage: glances-api.sh <command> [args...]
# API Version: 4

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Usage function (defined early for --help)
usage() {
    cat <<EOF
Glances REST API CLI

Usage: $(basename "$0") <command> [options]

System Overview:
  dashboard               Comprehensive system overview
  quicklook               Quick system summary (CPU, mem, swap, load)
  status                  API status check
  plugins                 List available plugins

System Info:
  system                  Hostname, OS, platform info
  uptime                  System uptime
  core                    CPU core count (physical/logical)

CPU:
  cpu                     Overall CPU usage
  percpu                  Per-core CPU usage
  load                    Load average (1/5/15 min)

Memory:
  mem                     Memory usage
  memswap                 Swap usage

Disk:
  fs                      Filesystem usage (mount points)
  diskio                  Disk I/O rates
  raid                    RAID array status
  smart                   S.M.A.R.T. disk health

Network:
  network                 Network interface traffic
  ip                      IP addresses
  wifi                    WiFi signal strength
  connections             TCP connection states

Sensors:
  sensors                 Temperature, fan, battery
  gpu                     GPU stats

Processes:
  processlist [--top N]   Process list (default: all, --top for top N by CPU)
  processcount            Process counts by state

Containers:
  containers [--running]  Docker/Podman containers

Alerts:
  alert                   Active alerts/warnings
  amps                    Application monitoring

Advanced:
  plugin <name> [field]   Get raw plugin data

Examples:
  $(basename "$0") dashboard
  $(basename "$0") cpu
  $(basename "$0") mem
  $(basename "$0") fs
  $(basename "$0") processlist --top 10
  $(basename "$0") containers --running
  $(basename "$0") plugin network rx_bytes
EOF
}

# Show help without requiring config
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" || -z "${1:-}" ]]; then
    usage
    exit 0
fi

# Load credentials from .env
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$HOME/.homelab-skills/load-env.sh"
load_env_file || exit 1
validate_env_vars "GLANCES_URL"  # Username/password optional for auth-less instances

# Map to script's internal variable names (may be empty)
GLANCES_USER="${GLANCES_USERNAME:-}"
GLANCES_PASS="${GLANCES_PASSWORD:-}"

# Remove trailing slash
GLANCES_URL="${GLANCES_URL%/}"
API_BASE="${GLANCES_URL}/api/4"

# API call helper
api() {
    local endpoint="$1"
    shift
    
    local auth_opts=()
    if [[ -n "$GLANCES_USER" && -n "$GLANCES_PASS" ]]; then
        auth_opts=(-u "${GLANCES_USER}:${GLANCES_PASS}")
    fi
    
    curl -sS "${auth_opts[@]}" \
        -H "Content-Type: application/json" \
        "$@" \
        "${API_BASE}${endpoint}"
}

# Human-readable byte formatting
format_bytes() {
    local bytes=$1
    if (( bytes >= 1099511627776 )); then
        echo "$(echo "scale=2; $bytes / 1099511627776" | bc) TB"
    elif (( bytes >= 1073741824 )); then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    elif (( bytes >= 1048576 )); then
        echo "$(echo "scale=2; $bytes / 1048576" | bc) MB"
    elif (( bytes >= 1024 )); then
        echo "$(echo "scale=2; $bytes / 1024" | bc) KB"
    else
        echo "$bytes B"
    fi
}

# Commands

cmd_status() {
    api "/status" -w "\n" 2>/dev/null || echo '{"error": "Could not connect to Glances server"}'
}

cmd_plugins() {
    api "/pluginslist"
}

cmd_quicklook() {
    api "/quicklook" | jq '{
        cpu_percent: .cpu,
        cpu_name: .cpu_name,
        mem_percent: .mem,
        swap_percent: .swap,
        load_1min: (if .load then .load else null end)
    }'
}

cmd_system() {
    api "/system" | jq '{
        hostname: .hostname,
        os_name: .os_name,
        os_version: .os_version,
        platform: .platform,
        linux_distro: .linux_distro,
        hr_name: .hr_name
    }'
}

cmd_uptime() {
    api "/uptime"
}

cmd_core() {
    api "/core" | jq '{
        physical_cores: .phys,
        logical_cores: .log
    }'
}

cmd_cpu() {
    api "/cpu" | jq '{
        total: .total,
        user: .user,
        system: .system,
        idle: .idle,
        iowait: .iowait,
        steal: .steal,
        nice: .nice,
        irq: .irq,
        ctx_switches: .ctx_switches,
        interrupts: .interrupts,
        cpucore: .cpucore
    }'
}

cmd_percpu() {
    api "/percpu" | jq '[.[] | {
        cpu_number: .cpu_number,
        total: .total,
        user: .user,
        system: .system,
        idle: .idle,
        iowait: .iowait
    }]'
}

cmd_load() {
    api "/load" | jq '{
        load_1min: .min1,
        load_5min: .min5,
        load_15min: .min15,
        cpucore: .cpucore
    }'
}

cmd_mem() {
    api "/mem" | jq '{
        total: .total,
        available: .available,
        used: .used,
        free: .free,
        percent: .percent,
        active: .active,
        inactive: .inactive,
        buffers: .buffers,
        cached: .cached,
        shared: .shared
    }'
}

cmd_memswap() {
    api "/memswap" | jq '{
        total: .total,
        used: .used,
        free: .free,
        percent: .percent,
        sin: .sin,
        sout: .sout
    }'
}

cmd_fs() {
    api "/fs" | jq '[.[] | {
        device_name: .device_name,
        fs_type: .fs_type,
        mnt_point: .mnt_point,
        size: .size,
        used: .used,
        free: .free,
        percent: .percent
    }]'
}

cmd_diskio() {
    api "/diskio" | jq '[.[] | {
        disk_name: .disk_name,
        read_bytes: .read_bytes,
        write_bytes: .write_bytes,
        read_count: .read_count,
        write_count: .write_count
    }]'
}

cmd_raid() {
    api "/raid"
}

cmd_smart() {
    api "/smart"
}

cmd_network() {
    api "/network" | jq '[.[] | {
        interface_name: .interface_name,
        rx_bytes: .bytes_recv,
        tx_bytes: .bytes_sent,
        rx_rate: .bytes_recv_rate_per_sec,
        tx_rate: .bytes_sent_rate_per_sec,
        speed: .speed,
        is_up: .is_up
    }]'
}

cmd_ip() {
    api "/ip"
}

cmd_wifi() {
    api "/wifi"
}

cmd_connections() {
    api "/connections"
}

cmd_sensors() {
    api "/sensors" | jq '[.[] | {
        label: .label,
        value: .value,
        unit: .unit,
        type: .type,
        warning: .warning,
        critical: .critical
    }]'
}

cmd_gpu() {
    api "/gpu"
}

cmd_processlist() {
    local top=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --top|-t) top="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    if [[ -n "$top" ]]; then
        api "/processlist" | jq --argjson n "$top" '[.[:$n] | .[] | {
            pid: .pid,
            name: .name,
            username: .username,
            cpu_percent: .cpu_percent,
            memory_percent: .memory_percent,
            status: .status,
            nice: .nice,
            num_threads: .num_threads,
            cmdline: (.cmdline // "" | if type == "array" then join(" ") else . end)
        }]'
    else
        api "/processlist" | jq '[.[] | {
            pid: .pid,
            name: .name,
            username: .username,
            cpu_percent: .cpu_percent,
            memory_percent: .memory_percent,
            status: .status,
            nice: .nice,
            num_threads: .num_threads
        }]'
    fi
}

cmd_processcount() {
    api "/processcount" | jq '{
        total: .total,
        running: .running,
        sleeping: .sleeping,
        stopped: .stopped,
        zombie: .zombie,
        thread: .thread,
        pid_max: .pid_max
    }'
}

cmd_containers() {
    local running_only=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --running|-r) running_only=true; shift ;;
            *) shift ;;
        esac
    done
    
    if [[ "$running_only" == "true" ]]; then
        api "/containers" | jq '[.[] | select(.status == "running") | {
            name: .name,
            id: (.id | .[0:12]),
            status: .status,
            image: .image,
            cpu_percent: .cpu_percent,
            memory_usage: .memory_usage,
            memory_limit: .memory_limit,
            network_rx: .network_rx,
            network_tx: .network_tx,
            io_rx: .io_rx,
            io_wx: .io_wx,
            uptime: .uptime,
            engine: .engine
        }]'
    else
        api "/containers" | jq '[.[] | {
            name: .name,
            id: (.id | .[0:12]),
            status: .status,
            image: .image,
            cpu_percent: .cpu_percent,
            memory_usage: .memory_usage,
            memory_limit: .memory_limit,
            uptime: .uptime,
            engine: .engine
        }]'
    fi
}

cmd_alert() {
    api "/alert" | jq '[.[] | {
        begin: .begin,
        end: .end,
        state: .state,
        type: .type,
        max: .max,
        avg: .avg,
        min: .min,
        desc: .desc,
        top: .top
    }]'
}

cmd_amps() {
    api "/amps" | jq '[.[] | {
        name: .name,
        result: .result,
        count: .count,
        countmin: .countmin,
        countmax: .countmax,
        refresh: .refresh
    }]'
}

cmd_plugin() {
    local plugin_name="${1:-}"
    local field="${2:-}"
    
    if [[ -z "$plugin_name" ]]; then
        echo '{"error": "Plugin name required"}' >&2
        exit 1
    fi
    
    if [[ -n "$field" ]]; then
        api "/${plugin_name}/${field}"
    else
        api "/${plugin_name}"
    fi
}

cmd_dashboard() {
    echo "{"
    
    # System info
    echo '"system":'
    api "/system" | jq -c '{hostname: .hostname, os: .os_name, platform: .platform}'
    echo ","
    
    # Uptime
    echo '"uptime":'
    api "/uptime"
    echo ","
    
    # CPU
    echo '"cpu":'
    api "/cpu" | jq -c '{total: .total, user: .user, system: .system, idle: .idle, iowait: .iowait, cores: .cpucore}'
    echo ","
    
    # Load
    echo '"load":'
    api "/load" | jq -c '{min1: .min1, min5: .min5, min15: .min15}'
    echo ","
    
    # Memory
    echo '"memory":'
    api "/mem" | jq -c '{total: .total, used: .used, free: .free, available: .available, percent: .percent}'
    echo ","
    
    # Swap
    echo '"swap":'
    api "/memswap" | jq -c '{total: .total, used: .used, free: .free, percent: .percent}'
    echo ","
    
    # Filesystem
    echo '"filesystems":'
    api "/fs" | jq -c '[.[] | {mount: .mnt_point, size: .size, used: .used, free: .free, percent: .percent}]'
    echo ","
    
    # Network
    echo '"network":'
    api "/network" | jq -c '[.[] | {interface: .interface_name, rx_rate: .bytes_recv_rate_per_sec, tx_rate: .bytes_sent_rate_per_sec, is_up: .is_up}]'
    echo ","
    
    # Containers (if any)
    echo '"containers":'
    api "/containers" | jq -c '[.[] | {name: .name, status: .status, cpu: .cpu_percent, memory: .memory_usage}] | if length == 0 then [] else . end'
    echo ","
    
    # Alerts
    echo '"alerts":'
    api "/alert" | jq -c 'if length == 0 then [] else [.[] | {state: .state, type: .type, desc: .desc}] end'
    echo ","
    
    # Top 5 processes by CPU
    echo '"top_processes":'
    api "/processlist" | jq -c '[.[:5] | .[] | {name: .name, cpu: .cpu_percent, mem: .memory_percent}]'
    
    echo "}"
}

# Main dispatch
case "${1:-}" in
    status) cmd_status ;;
    plugins) cmd_plugins ;;
    quicklook|quick) cmd_quicklook ;;
    system) cmd_system ;;
    uptime) cmd_uptime ;;
    core|cores) cmd_core ;;
    cpu) cmd_cpu ;;
    percpu) cmd_percpu ;;
    load) cmd_load ;;
    mem|memory) cmd_mem ;;
    memswap|swap) cmd_memswap ;;
    fs|filesystem|disk) cmd_fs ;;
    diskio) cmd_diskio ;;
    raid) cmd_raid ;;
    smart) cmd_smart ;;
    network|net) cmd_network ;;
    ip) cmd_ip ;;
    wifi) cmd_wifi ;;
    connections|conn) cmd_connections ;;
    sensors|temps) cmd_sensors ;;
    gpu) cmd_gpu ;;
    processlist|ps|processes) shift; cmd_processlist "$@" ;;
    processcount) cmd_processcount ;;
    containers|docker) shift; cmd_containers "$@" ;;
    alert|alerts) cmd_alert ;;
    amps) cmd_amps ;;
    plugin|raw) shift; cmd_plugin "$@" ;;
    dashboard|all) cmd_dashboard ;;
    *) echo "Unknown command: $1" >&2; usage; exit 1 ;;
esac
