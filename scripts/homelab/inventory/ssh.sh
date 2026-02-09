#!/bin/bash
# Script Name: ssh.sh
# Purpose: Discover and catalog all SSH-accessible hosts with their capabilities
# Output: JSON state + Markdown inventory to ~/memory/bank/ssh/
# Cron: 0 */6 * * * (every 6 hours)

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

# Paths
STATE_DIR="${STATE_DIR:-$HOME/memory/bank/$SCRIPT_NAME}"
CURRENT_MD="$STATE_DIR/latest.md"

# Timestamps
TIMESTAMP=$(date +%s)
JSON_FILE="$STATE_DIR/${TIMESTAMP}.json"
LATEST_LINK="$STATE_DIR/latest.json"

# Retention (every 6 hours = 4/day, keep 30 days = 120 files)
STATE_RETENTION="${STATE_RETENTION:-120}"

# Enable Gotify notifications by default
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
    rm -f /tmp/ssh-inv-*.tmp 2>/dev/null || true
}

# === OS Detection Functions ===

# Detect OS type (linux, darwin, windows)
# Args: $1 = hostname
# Returns: JSON with os_type
detect_os_type() {
    local host="$1"
    local os_type="unknown"
    
    # Check uname
    local uname_output=$(remote_cmd "$host" "uname -s" 2>/dev/null || echo "")
    
    case "$uname_output" in
        Linux) os_type="linux" ;;
        Darwin) os_type="darwin" ;;
        *) os_type="unknown" ;;
    esac
    
    echo "$os_type"
}

# Detect Linux distribution
# Args: $1 = hostname
# Returns: JSON with distro info {distro, version, codename}
detect_linux_distro() {
    local host="$1"
    
    # Check for Unraid first (has /etc/unraid-version)
    if remote_cmd "$host" "test -f /etc/unraid-version" 2>/dev/null; then
        # File format is: version="X.Y.Z" - extract just the version number
        local version=$(remote_cmd "$host" "cat /etc/unraid-version" 2>/dev/null | grep -oP '(?<=version=")[^"]+' || echo "unknown")
        echo "{\"distro\":\"Unraid\",\"version\":\"$version\",\"codename\":null}"
        return
    fi
    
    # Parse /etc/os-release
    local os_release=$(remote_cmd "$host" "cat /etc/os-release 2>/dev/null" || echo "")
    
    if [[ -n "$os_release" ]]; then
        local distro=$(echo "$os_release" | grep "^ID=" | cut -d= -f2 | tr -d '"' || echo "unknown")
        local version=$(echo "$os_release" | grep "^VERSION_ID=" | cut -d= -f2 | tr -d '"' || echo "unknown")
        local codename=$(echo "$os_release" | grep "^VERSION_CODENAME=" | cut -d= -f2 | tr -d '"' || echo "null")
        
        # Capitalize distro name
        distro=$(echo "$distro" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
        
        echo "{\"distro\":\"$distro\",\"version\":\"$version\",\"codename\":\"$codename\"}"
    else
        echo "{\"distro\":\"unknown\",\"version\":\"unknown\",\"codename\":null}"
    fi
}

# Detect kernel version
# Args: $1 = hostname
# Returns: kernel version string
detect_kernel() {
    local host="$1"
    remote_cmd "$host" "uname -r" 2>/dev/null || echo "unknown"
}

# Detect if running in Windows Subsystem for Linux
# Args: $1 = hostname
# Returns: JSON with WSL detection {is_wsl, wsl_version}
detect_wsl() {
    local host="$1"
    local is_wsl="false"
    local wsl_version="null"
    
    # Method 1: Check for WSLInterop file (WSL2)
    if remote_cmd "$host" "test -f /proc/sys/fs/binfmt_misc/WSLInterop" 2>/dev/null; then
        is_wsl="true"
        wsl_version="2"
    # Method 2: Check kernel release for "microsoft" or "WSL"
    elif remote_cmd "$host" "uname -r | grep -qi microsoft" 2>/dev/null || \
         remote_cmd "$host" "uname -r | grep -qi wsl" 2>/dev/null; then
        is_wsl="true"
        # Check if it's WSL1 or WSL2
        if remote_cmd "$host" "uname -r | grep -qi 'microsoft.*wsl2'" 2>/dev/null; then
            wsl_version="2"
        else
            wsl_version="1"
        fi
    # Method 3: Check for /mnt/c combined with Windows in /proc/version (Issue 11 fix)
    elif remote_cmd "$host" "test -d /mnt/c && grep -qi windows /proc/version" 2>/dev/null; then
        is_wsl="true"
        wsl_version="unknown"
    fi
    
    # Output valid JSON - quote string values, but null stays unquoted
    if [[ "$wsl_version" == "null" ]]; then
        echo "{\"is_wsl\":$is_wsl,\"wsl_version\":null}"
    else
        echo "{\"is_wsl\":$is_wsl,\"wsl_version\":\"$wsl_version\"}"
    fi
}

# === Capability Detection Functions ===

# Check if Docker is installed and accessible
# Args: $1 = hostname
# Returns: JSON {has_docker, version}
check_docker() {
    local host="$1"
    
    if remote_cmd "$host" "command -v docker" &>/dev/null; then
        local version=$(remote_cmd "$host" "docker --version 2>/dev/null | awk '{print \$3}' | tr -d ','")
        echo "{\"has_docker\":true,\"version\":\"$version\"}"
    else
        echo "{\"has_docker\":false,\"version\":null}"
    fi
}

# Check if systemd is available
# Args: $1 = hostname
# Returns: JSON {has_systemd}
check_systemd() {
    local host="$1"
    
    if remote_cmd "$host" "command -v systemctl && systemctl --version" &>/dev/null; then
        echo "{\"has_systemd\":true}"
    else
        echo "{\"has_systemd\":false}"
    fi
}

# Check various system capabilities
# Args: $1 = hostname
# Returns: JSON with multiple capability flags
check_capabilities() {
    local host="$1"
    
    local caps="{"
    
    # Check for common tools
    local has_jq=$(remote_cmd "$host" "command -v jq" &>/dev/null && echo "true" || echo "false")
    local has_curl=$(remote_cmd "$host" "command -v curl" &>/dev/null && echo "true" || echo "false")
    local has_git=$(remote_cmd "$host" "command -v git" &>/dev/null && echo "true" || echo "false")
    local has_python=$(remote_cmd "$host" "command -v python3" &>/dev/null && echo "true" || echo "false")
    local has_tailscale=$(remote_cmd "$host" "command -v tailscale" &>/dev/null && echo "true" || echo "false")
    
    caps+="\"has_jq\":$has_jq,"
    caps+="\"has_curl\":$has_curl,"
    caps+="\"has_git\":$has_git,"
    caps+="\"has_python\":$has_python,"
    caps+="\"has_tailscale\":$has_tailscale"
    caps+="}"
    
    echo "$caps"
}

# Detect GPU presence and type
# Args: $1 = hostname
# Returns: JSON {has_gpu, gpu_type, gpu_count}
detect_gpu() {
    local host="$1"
    local has_gpu="false"
    local gpu_type="none"
    local gpu_count=0
    
    # Check for NVIDIA GPU
    if remote_cmd "$host" "command -v nvidia-smi" &>/dev/null; then
        has_gpu="true"
        gpu_type="nvidia"
        gpu_count=$(remote_cmd "$host" "nvidia-smi --list-gpus 2>/dev/null | wc -l | tr -d ' '" 2>/dev/null || echo "0")
    # Check for AMD GPU
    elif remote_cmd "$host" "lspci 2>/dev/null | grep -i 'vga.*amd'" &>/dev/null; then
        has_gpu="true"
        gpu_type="amd"
        gpu_count=1
    fi
    
    echo "{\"has_gpu\":$has_gpu,\"gpu_type\":\"$gpu_type\",\"gpu_count\":$gpu_count}"
}

# Detect if running in a VM or container
# Args: $1 = hostname
# Returns: JSON {is_virtual, virt_type}
detect_virtualization() {
    local host="$1"
    local is_virtual="false"
    local virt_type="none"
    
    # Try systemd-detect-virt first
    if remote_cmd "$host" "command -v systemd-detect-virt" &>/dev/null; then
        # Note: systemd-detect-virt returns exit code 1 when it outputs "none"
        # So we capture stdout separately and don't use || fallback
        local result
        result=$(remote_cmd "$host" "systemd-detect-virt" 2>/dev/null | tr -d '\n')
        result="${result:-none}"  # Default to "none" if empty
        if [[ "$result" != "none" && -n "$result" ]]; then
            is_virtual="true"
            virt_type="$result"
        fi
    else
        # Fallback: check common virtualization indicators
        if remote_cmd "$host" "grep -qi hypervisor /proc/cpuinfo" 2>/dev/null; then
            is_virtual="true"
            virt_type="unknown"
        fi
    fi
    
    echo "{\"is_virtual\":$is_virtual,\"virt_type\":\"$virt_type\"}"
}

# Detect package manager
# Args: $1 = hostname
# Returns: JSON {package_manager}
detect_package_manager() {
    local host="$1"
    local pkg_mgr="unknown"
    
    # Check for common package managers in order of prevalence
    if remote_cmd "$host" "command -v apt-get" &>/dev/null; then
        pkg_mgr="apt"
    elif remote_cmd "$host" "command -v dnf" &>/dev/null; then
        pkg_mgr="dnf"
    elif remote_cmd "$host" "command -v yum" &>/dev/null; then
        pkg_mgr="yum"
    elif remote_cmd "$host" "command -v pacman" &>/dev/null; then
        pkg_mgr="pacman"
    elif remote_cmd "$host" "command -v zypper" &>/dev/null; then
        pkg_mgr="zypper"
    elif remote_cmd "$host" "command -v apk" &>/dev/null; then
        pkg_mgr="apk"
    elif remote_cmd "$host" "command -v brew" &>/dev/null; then
        pkg_mgr="brew"
    elif remote_cmd "$host" "command -v slackpkg" &>/dev/null; then
        pkg_mgr="slackpkg"
    elif remote_cmd "$host" "command -v installpkg" &>/dev/null; then
        pkg_mgr="slackware"
    fi
    
    echo "{\"package_manager\":\"$pkg_mgr\"}"
}

# Detect storage subsystems (ZFS, LVM, Btrfs)
# Args: $1 = hostname
# Returns: JSON {has_zfs, has_lvm, has_btrfs, zfs_pools, lvm_vgs}
detect_storage() {
    local host="$1"
    local has_zfs="false"
    local has_lvm="false"
    local has_btrfs="false"
    local zfs_pools="[]"
    local lvm_vgs="[]"
    
    # Check for ZFS
    if remote_cmd "$host" "command -v zpool" &>/dev/null; then
        if remote_cmd "$host" "zpool list -H -o name 2>/dev/null" &>/dev/null; then
            has_zfs="true"
            # Get pool names as JSON array
            local pools=$(remote_cmd "$host" "zpool list -H -o name 2>/dev/null" | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
            zfs_pools="$pools"
        fi
    fi
    
    # Check for LVM
    if remote_cmd "$host" "command -v vgs" &>/dev/null; then
        if remote_cmd "$host" "vgs --noheadings -o vg_name 2>/dev/null" &>/dev/null; then
            has_lvm="true"
            # Get VG names as JSON array
            local vgs=$(remote_cmd "$host" "vgs --noheadings -o vg_name 2>/dev/null | tr -d ' '" | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
            lvm_vgs="$vgs"
        fi
    fi
    
    # Check for Btrfs
    if remote_cmd "$host" "command -v btrfs" &>/dev/null; then
        if remote_cmd "$host" "btrfs filesystem show 2>/dev/null" &>/dev/null; then
            has_btrfs="true"
        fi
    fi
    
    echo "{\"has_zfs\":$has_zfs,\"has_lvm\":$has_lvm,\"has_btrfs\":$has_btrfs,\"zfs_pools\":$zfs_pools,\"lvm_vgs\":$lvm_vgs}"
}

# Detect hypervisor/virtualization host capabilities
# Args: $1 = hostname
# Returns: JSON {is_hypervisor, hypervisor_type, has_libvirt, has_proxmox, has_virtualbox}
detect_hypervisor() {
    local host="$1"
    local is_hypervisor="false"
    local hypervisor_type="none"
    local has_libvirt="false"
    local has_proxmox="false"
    local has_virtualbox="false"
    
    # Check for libvirt/KVM
    if remote_cmd "$host" "command -v virsh" &>/dev/null; then
        has_libvirt="true"
        is_hypervisor="true"
        hypervisor_type="libvirt"
    fi
    
    # Check for Proxmox VE
    if remote_cmd "$host" "test -f /etc/pve/local/pve-ssl.pem" 2>/dev/null || \
       remote_cmd "$host" "command -v pveversion" &>/dev/null; then
        has_proxmox="true"
        is_hypervisor="true"
        hypervisor_type="proxmox"
    fi
    
    # Check for VirtualBox
    if remote_cmd "$host" "command -v VBoxManage" &>/dev/null; then
        has_virtualbox="true"
        is_hypervisor="true"
        if [[ "$hypervisor_type" == "none" ]]; then
            hypervisor_type="virtualbox"
        else
            hypervisor_type="${hypervisor_type}+virtualbox"
        fi
    fi
    
    # Check for Docker as a "hypervisor" for containers
    if remote_cmd "$host" "docker info" &>/dev/null 2>&1; then
        if [[ "$hypervisor_type" == "none" ]]; then
            hypervisor_type="docker"
        fi
    fi
    
    echo "{\"is_hypervisor\":$is_hypervisor,\"hypervisor_type\":\"$hypervisor_type\",\"has_libvirt\":$has_libvirt,\"has_proxmox\":$has_proxmox,\"has_virtualbox\":$has_virtualbox}"
}

# Detect Tailscale presence, IP, and hostname
# Args: $1 = hostname
# Returns: JSON {has_tailscale, tailscale_ip, tailscale_hostname, connected}
detect_tailscale() {
    local host="$1"
    local has_tailscale="false"
    local tailscale_ip="null"
    local tailscale_hostname="null"
    local connected="false"
    
    # Check if tailscale command exists
    if remote_cmd "$host" "command -v tailscale" &>/dev/null; then
        has_tailscale="true"
        
        # Try to get status (will fail if not connected/running)
        local status_output
        status_output=$(remote_cmd "$host" "tailscale status --json 2>/dev/null" 2>/dev/null)
        
        if [[ -n "$status_output" ]]; then
            # Extract Self node info
            local ts_ip=$(echo "$status_output" | jq -r '.Self.TailscaleIPs[0] // null' 2>/dev/null)
            local ts_hostname=$(echo "$status_output" | jq -r '.Self.HostName // .Self.DNSName // null' 2>/dev/null)
            
            if [[ "$ts_ip" != "null" && -n "$ts_ip" ]]; then
                tailscale_ip="\"$ts_ip\""
                connected="true"
            fi
            
            if [[ "$ts_hostname" != "null" && -n "$ts_hostname" ]]; then
                # Strip domain if present (e.g., "hostname.tailnet-name.ts.net" -> "hostname")
                ts_hostname=$(echo "$ts_hostname" | cut -d'.' -f1)
                tailscale_hostname="\"$ts_hostname\""
            fi
        fi
    fi
    
    echo "{\"has_tailscale\":$has_tailscale,\"tailscale_ip\":$tailscale_ip,\"tailscale_hostname\":$tailscale_hostname,\"connected\":$connected}"
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

# === Host Discovery Functions ===

# Discover all SSH-accessible hosts from SSH config
# Returns: array of hostnames (one per line)
discover_ssh_hosts() {
    local hosts=()
    
    # Parse ~/.ssh/config directly for Host entries
    if [[ -f ~/.ssh/config ]]; then
        # Disable glob expansion to prevent * from expanding to files
        set -f
        while IFS= read -r line; do
            # Match "Host hostname" lines (case insensitive)
            if [[ "$line" =~ ^[Hh]ost[[:space:]]+(.+) ]]; then
                # Split on whitespace in case multiple hosts on one line
                for hostname in ${BASH_REMATCH[1]}; do
                    # Skip wildcards and patterns
                    [[ "$hostname" =~ \* ]] && continue
                    [[ "$hostname" =~ \? ]] && continue
                    [[ "$hostname" =~ \! ]] && continue
                    hosts+=("$hostname")
                done
            fi
        done < ~/.ssh/config
        # Re-enable glob expansion
        set +f
    fi
    
    # Deduplicate and output
    printf '%s\n' "${hosts[@]}" | sort -u
}

# Collect all information for a single host
# Args: $1 = hostname
# Returns: JSON object with all host details
collect_host_info() {
    local host="$1"
    
    log_info "Collecting info for $host"
    
    # Test connectivity first
    if ! remote_cmd "$host" "echo ok" &>/dev/null; then
        log_warn "$host is unreachable"
        echo "{\"hostname\":\"$host\",\"reachable\":false}"
        return 1
    fi
    
    # Collect all detection data
    local os_type=$(detect_os_type "$host")
    local kernel=$(detect_kernel "$host")
    local wsl=$(detect_wsl "$host")
    
    # Linux-specific
    local distro="{}"
    if [[ "$os_type" == "linux" ]]; then
        distro=$(detect_linux_distro "$host")
    fi
    
    # Capabilities
    local docker=$(check_docker "$host")
    local tailscale=$(detect_tailscale "$host")
    local systemd=$(check_systemd "$host")
    local caps=$(check_capabilities "$host")
    local gpu=$(detect_gpu "$host")
    local virt=$(detect_virtualization "$host")
    local pkg_mgr=$(detect_package_manager "$host")
    local storage=$(detect_storage "$host")
    local hypervisor=$(detect_hypervisor "$host")
    
    # Build complete JSON object
    cat <<EOF
{
  "hostname": "$host",
  "reachable": true,
  "os_type": "$os_type",
  "kernel": "$kernel",
  "distro": $distro,
  "wsl": $wsl,
  "docker": $docker,
  "tailscale": $tailscale,
  "systemd": $systemd,
  "capabilities": $caps,
  "gpu": $gpu,
  "virtualization": $virt,
  "package_manager": $pkg_mgr,
  "storage": $storage,
  "hypervisor": $hypervisor,
  "last_checked": $(date +%s)
}
EOF
}

# Generate human-readable markdown from JSON
# Args: $1 = JSON content
generate_markdown() {
    local json="$1"
    
    cat <<EOF
# SSH Host Inventory

Generated: $(date)

## Summary

$(echo "$json" | jq -r '
  "Total hosts: \(length)",
  "Reachable: \([.[] | select(.reachable)] | length)",
  "Unreachable: \([.[] | select(.reachable | not)] | length)",
  "",
  "OS Distribution:",
  (group_by(.os_type) | .[] | "  \(.[0].os_type): \(length)")
')

## Hosts

$(echo "$json" | jq -r '.[] | 
  "### \(.hostname)",
  "",
  if .reachable then
    "- **OS**: \(.os_type) \(if .distro.distro then "(\(.distro.distro) \(.distro.version))" else "" end)",
    "- **Kernel**: \(.kernel)",
    (if .package_manager.package_manager and .package_manager.package_manager != "unknown" then "- **Package Manager**: \(.package_manager.package_manager)" else "" end),
    (if .systemd.has_systemd then "- **systemd**: ✓" else "" end),
    (if .wsl.is_wsl then "- **WSL**: Version \(.wsl.wsl_version)" else "" end),
    (if .docker.has_docker then "- **Docker**: \(.docker.version)" else "" end),
    (if .tailscale.has_tailscale then "- **Tailscale**: \(if .tailscale.connected then "\(.tailscale.tailscale_ip) (\(.tailscale.tailscale_hostname))" else "installed, not connected" end)" else "" end),
    (if .gpu.has_gpu then "- **GPU**: \(.gpu.gpu_count)x \(.gpu.gpu_type)" else "" end),
    (if .virtualization.is_virtual then "- **VM Guest**: \(.virtualization.virt_type)" else "" end),
    (if .hypervisor.is_hypervisor then "- **Hypervisor**: \(.hypervisor.hypervisor_type)\(if .hypervisor.has_libvirt then " (libvirt)" else "" end)\(if .hypervisor.has_proxmox then " (Proxmox)" else "" end)\(if .hypervisor.has_virtualbox then " (VirtualBox)" else "" end)" else "" end),
    (if .storage.has_zfs then "- **ZFS**: pools: \(.storage.zfs_pools | join(", "))" else "" end),
    (if .storage.has_lvm and (.storage.lvm_vgs | length) > 0 then "- **LVM**: VGs: \(.storage.lvm_vgs | join(", "))" else "" end),
    (if .storage.has_btrfs then "- **Btrfs**: ✓" else "" end),
    (if (.capabilities.has_jq or .capabilities.has_curl or .capabilities.has_git or .capabilities.has_python) then "- **Tools**: \([.capabilities | to_entries[] | select(.value == true and .key != "has_tailscale") | .key | ltrimstr("has_")] | join(", "))" else "" end),
    ""
  else
    "**Status**: Unreachable",
    ""
  end
')
EOF
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
    
    # Discover hosts
    log_info "Discovering SSH hosts"
    local hosts
    mapfile -t hosts < <(discover_ssh_hosts)
    
    if [[ ${#hosts[@]} -eq 0 ]]; then
        log_warn "No SSH hosts found in ~/.ssh/config"
        exit 0
    fi
    
    log_info "Found ${#hosts[@]} hosts"
    
    # Collect inventory
    local inventory=()
    for host in "${hosts[@]}"; do
        # Capture stdout only - log messages go to stderr
        local info=$(collect_host_info "$host")
        if [[ -n "$info" ]]; then
            inventory+=("$info")
        fi
    done
    
    # Build final JSON
    local json_content=$(printf '%s\n' "${inventory[@]}" | jq -s '.')
    
    # Write JSON state
    echo "$json_content" | jq '.' > "$JSON_FILE"
    update_latest_link "$JSON_FILE" "$LATEST_LINK"
    
    # Generate markdown
    generate_markdown "$json_content" > "$CURRENT_MD"
    
    # Cleanup old state
    cleanup_old_state "$STATE_DIR" "$STATE_RETENTION"
    
    log_success "$SCRIPT_NAME completed successfully"
}

main "$@"
