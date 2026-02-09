#!/bin/bash
# Logging Library with Rotation
# Provides structured logging with automatic log rotation

# Default log settings (override before sourcing)
LOG_DIR="${LOG_DIR:-$HOME/workspace/homelab/logs}"
LOG_MAX_SIZE="${LOG_MAX_SIZE:-10485760}"  # 10MB in bytes
LOG_MAX_FILES="${LOG_MAX_FILES:-2}"       # Keep current + 1 rotated

# Initialize logging for a script
# Usage: init_logging "script-name"
init_logging() {
    local script_name="${1:-unknown}"
    
    # Set global log file path
    export LOG_FILE="$LOG_DIR/${script_name}.log"
    export LOG_FILE_OLD="$LOG_DIR/${script_name}.log.1"
    
    # Ensure log directory exists
    mkdir -p "$LOG_DIR"
    
    # Check if rotation needed
    rotate_log_if_needed
}

# Rotate log if it exceeds max size
rotate_log_if_needed() {
    if [[ ! -f "$LOG_FILE" ]]; then
        return 0
    fi
    
    local size
    size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
    
    if (( size > LOG_MAX_SIZE )); then
        # Remove old rotated log if it exists
        [[ -f "$LOG_FILE_OLD" ]] && rm -f "$LOG_FILE_OLD"
        
        # Rotate current log
        mv "$LOG_FILE" "$LOG_FILE_OLD"
        
        # Start fresh log
        touch "$LOG_FILE"
        
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] LOG: Rotated log file (size: ${size} bytes)" >> "$LOG_FILE"
    fi
}

# Write log entry with timestamp and level
# Usage: log_write "LEVEL" "message"
log_write() {
    local level="$1"
    shift
    local message="$*"
    
    # Rotate if needed before writing
    rotate_log_if_needed
    
    # Write to log file
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $level: $message" >> "$LOG_FILE"
}

# Structured logging functions
log_info() {
    log_write "INFO" "$*"
    echo "[INFO] $*" >&2
}

log_warn() {
    log_write "WARN" "$*"
    echo "[WARN] $*" >&2
}

log_error() {
    log_write "ERROR" "$*"
    echo "[ERROR] $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        log_write "DEBUG" "$*"
        echo "[DEBUG] $*" >&2
    fi
}

log_success() {
    log_write "SUCCESS" "$*"
    echo "[SUCCESS] $*" >&2
}

# Log with custom level
log_custom() {
    local level="$1"
    shift
    log_write "$level" "$*"
}

# Get log file stats
get_log_stats() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo '{"exists": false}'
        return 1
    fi
    
    local size
    local lines
    local age
    
    size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
    lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
    age=$(stat -f%B "$LOG_FILE" 2>/dev/null || stat -c%Y "$LOG_FILE" 2>/dev/null || echo "0")
    
    local age_readable
    age_readable=$(( $(date +%s) - age ))
    
    cat <<EOF
{
  "exists": true,
  "path": "$LOG_FILE",
  "size_bytes": $size,
  "size_mb": $(echo "scale=2; $size / 1048576" | bc),
  "lines": $lines,
  "age_seconds": $age_readable,
  "max_size_mb": $(echo "scale=2; $LOG_MAX_SIZE / 1048576" | bc),
  "needs_rotation": $(( size > LOG_MAX_SIZE ))
}
EOF
}

# Tail recent log entries
# Usage: log_tail [lines]
log_tail() {
    local lines="${1:-50}"
    
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "No log file found: $LOG_FILE" >&2
        return 1
    fi
    
    tail -n "$lines" "$LOG_FILE"
}

# Search log file
# Usage: log_search "pattern" [lines]
log_search() {
    local pattern="$1"
    local lines="${2:-100}"
    
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "No log file found: $LOG_FILE" >&2
        return 1
    fi
    
    grep -i "$pattern" "$LOG_FILE" | tail -n "$lines"
}

# Clean up old logs (for maintenance scripts)
# Usage: cleanup_old_logs "script-name" days
cleanup_old_logs() {
    local script_name="$1"
    local days="${2:-7}"
    
    find "$LOG_DIR" -name "${script_name}*.log*" -type f -mtime +"$days" -delete
}

# Get all log files for a script
list_log_files() {
    local script_name="${1:-*}"
    
    find "$LOG_DIR" -name "${script_name}*.log*" -type f 2>/dev/null | sort
}

# Archive old logs to compressed file
# Usage: archive_logs "script-name" "archive.tar.gz"
archive_logs() {
    local script_name="$1"
    local archive_file="$2"
    
    if [[ -z "$archive_file" ]]; then
        echo "ERROR: Archive file path required" >&2
        return 1
    fi
    
    local log_files
    log_files=$(list_log_files "$script_name")
    
    if [[ -z "$log_files" ]]; then
        echo "No log files found for: $script_name" >&2
        return 1
    fi
    
    tar -czf "$archive_file" $log_files
    echo "Archived logs to: $archive_file"
}

# Export functions
export -f init_logging
export -f rotate_log_if_needed
export -f log_write
export -f log_info
export -f log_warn
export -f log_error
export -f log_debug
export -f log_success
export -f log_custom
export -f get_log_stats
export -f log_tail
export -f log_search
export -f cleanup_old_logs
export -f list_log_files
export -f archive_logs
