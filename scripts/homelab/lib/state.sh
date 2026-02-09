#!/bin/bash
# State File Management Library
# Helper functions for managing timestamped JSON state files

# Get the most recent state file in a directory
# Usage: get_last_state "/path/to/state/dir"
# Returns: Path to most recent file, or empty if none found
get_last_state() {
    local state_dir="$1"
    
    if [[ ! -d "$state_dir" ]]; then
        return 1
    fi
    
    # Find most recent .json file (excluding latest symlink)
    find "$state_dir" -maxdepth 1 -type f -name "*.json" -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn \
        | head -1 \
        | awk '{print $2}'
}

# Clean up old state files, keeping only the N most recent
# Usage: cleanup_old_state "/path/to/state/dir" 168
# Params:
#   $1 - State directory path
#   $2 - Number of files to retain
cleanup_old_state() {
    local state_dir="$1"
    local retention="${2:-168}"  # Default 168 files
    
    if [[ ! -d "$state_dir" ]]; then
        return 0
    fi
    
    # Count current files (excluding latest symlink)
    local file_count
    file_count=$(find "$state_dir" -maxdepth 1 -type f -name "*.json" | wc -l)
    
    if (( file_count <= retention )); then
        # Nothing to clean up
        return 0
    fi
    
    # Calculate how many to delete
    local to_delete=$((file_count - retention))
    
    # Delete oldest files
    find "$state_dir" -maxdepth 1 -type f -name "*.json" -printf '%T@ %p\n' \
        | sort -n \
        | head -"$to_delete" \
        | awk '{print $2}' \
        | xargs -r rm -f
    
    echo "Cleaned up $to_delete old state files (keeping $retention most recent)"
}

# Compare two JSON state files and output differences
# Usage: compare_states "/path/to/old.json" "/path/to/new.json"
# Returns: JSON diff output via jq
compare_states() {
    local old_file="$1"
    local new_file="$2"
    
    if [[ ! -f "$old_file" ]] || [[ ! -f "$new_file" ]]; then
        echo "ERROR: Both files must exist for comparison" >&2
        return 1
    fi
    
    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq is required for state comparison" >&2
        return 1
    fi
    
    # Use jq to create a diff
    jq -n \
        --argfile old "$old_file" \
        --argfile new "$new_file" \
        '{
            old_timestamp: $old.timestamp,
            new_timestamp: $new.timestamp,
            changes: (
                $new | to_entries | 
                map(select(.key != "timestamp" and .key != "metadata"))
            )
        }'
}

# Get state file by relative offset (0=latest, 1=previous, etc.)
# Usage: get_state_at_offset "/path/to/state/dir" 1
# Returns: Path to file at offset, or empty if not found
get_state_at_offset() {
    local state_dir="$1"
    local offset="${2:-0}"
    
    if [[ ! -d "$state_dir" ]]; then
        return 1
    fi
    
    # Get Nth most recent file
    find "$state_dir" -maxdepth 1 -type f -name "*.json" -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn \
        | sed -n "$((offset + 1))p" \
        | awk '{print $2}'
}

# Count total state files in directory
# Usage: count_states "/path/to/state/dir"
# Returns: Count of .json files
count_states() {
    local state_dir="$1"
    
    if [[ ! -d "$state_dir" ]]; then
        echo "0"
        return 0
    fi
    
    find "$state_dir" -maxdepth 1 -type f -name "*.json" | wc -l
}

# Get age of oldest state file in seconds
# Usage: get_oldest_state_age "/path/to/state/dir"
# Returns: Age in seconds, or empty if no files
get_oldest_state_age() {
    local state_dir="$1"
    local now
    now=$(date +%s)
    
    if [[ ! -d "$state_dir" ]]; then
        return 1
    fi
    
    local oldest_timestamp
    oldest_timestamp=$(find "$state_dir" -maxdepth 1 -type f -name "*.json" -printf '%T@\n' 2>/dev/null \
        | sort -n \
        | head -1 \
        | cut -d. -f1)
    
    if [[ -z "$oldest_timestamp" ]]; then
        return 1
    fi
    
    echo $((now - oldest_timestamp))
}

# Archive old state files to compressed archive
# Usage: archive_old_states "/path/to/state/dir" 168 "/path/to/archive.tar.gz"
# Params:
#   $1 - State directory
#   $2 - Number of recent files to keep (rest are archived)
#   $3 - Archive file path
archive_old_states() {
    local state_dir="$1"
    local retention="${2:-168}"
    local archive_file="$3"
    
    if [[ ! -d "$state_dir" ]]; then
        echo "ERROR: State directory does not exist: $state_dir" >&2
        return 1
    fi
    
    if [[ -z "$archive_file" ]]; then
        echo "ERROR: Archive file path required" >&2
        return 1
    fi
    
    # Count current files
    local file_count
    file_count=$(count_states "$state_dir")
    
    if (( file_count <= retention )); then
        echo "No files to archive (have $file_count, keeping $retention)"
        return 0
    fi
    
    # Get list of files to archive
    local to_archive=$((file_count - retention))
    local temp_list
    temp_list=$(mktemp)
    
    find "$state_dir" -maxdepth 1 -type f -name "*.json" -printf '%T@ %p\n' \
        | sort -n \
        | head -"$to_archive" \
        | awk '{print $2}' > "$temp_list"
    
    # Create archive
    tar -czf "$archive_file" -T "$temp_list" 2>/dev/null
    
    # Remove archived files
    xargs -r rm -f < "$temp_list"
    
    rm -f "$temp_list"
    
    echo "Archived $to_archive files to: $archive_file"
}

# Extract statistics from state files (requires jq)
# Usage: get_state_stats "/path/to/state/dir"
# Returns: JSON with statistics
get_state_stats() {
    local state_dir="$1"
    
    if [[ ! -d "$state_dir" ]]; then
        echo '{"error": "Directory not found"}'
        return 1
    fi
    
    if ! command -v jq &>/dev/null; then
        echo '{"error": "jq required"}'
        return 1
    fi
    
    local count
    count=$(count_states "$state_dir")
    
    local oldest_age
    oldest_age=$(get_oldest_state_age "$state_dir" || echo "0")
    
    local total_size
    total_size=$(du -sb "$state_dir" 2>/dev/null | awk '{print $1}')
    
    jq -n \
        --arg count "$count" \
        --arg oldest_age "$oldest_age" \
        --arg total_size "$total_size" \
        --arg dir "$state_dir" \
        '{
            directory: $dir,
            file_count: ($count | tonumber),
            oldest_age_seconds: ($oldest_age | tonumber),
            oldest_age_hours: (($oldest_age | tonumber) / 3600 | floor),
            total_size_bytes: ($total_size | tonumber),
            total_size_mb: (($total_size | tonumber) / 1048576 | floor)
        }'
}

# Ensure state directory structure exists
# Usage: ensure_state_dir "/path/to/state/dir"
ensure_state_dir() {
    local state_dir="$1"
    
    if [[ -z "$state_dir" ]]; then
        echo "ERROR: State directory path required" >&2
        return 1
    fi
    
    mkdir -p "$state_dir" || {
        echo "ERROR: Failed to create state directory: $state_dir" >&2
        return 1
    }
}

# Rotate state files (keep N most recent, compress older)
# Usage: rotate_states "/path/to/state/dir" 168 30
# Params:
#   $1 - State directory
#   $2 - Number of recent files to keep uncompressed
#   $3 - Number of older files to keep compressed
rotate_states() {
    local state_dir="$1"
    local keep_recent="${2:-168}"
    local keep_compressed="${3:-30}"
    
    # Archive files beyond keep_recent
    local archive_file="$state_dir/archive-$(date +%Y%m%d).tar.gz"
    archive_old_states "$state_dir" "$keep_recent" "$archive_file"
    
    # Clean up old archives (keep only keep_compressed archives)
    find "$state_dir" -maxdepth 1 -type f -name "archive-*.tar.gz" -printf '%T@ %p\n' \
        | sort -rn \
        | tail -n +$((keep_compressed + 1)) \
        | awk '{print $2}' \
        | xargs -r rm -f
}
