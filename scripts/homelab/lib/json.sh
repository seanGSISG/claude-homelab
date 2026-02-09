#!/bin/bash
# JSON Helper Library
# Provides functions for building JSON objects and arrays

# Note: Not setting shell options here - library is meant to be sourced
# The calling script should set its own options

# Escape special characters in strings for JSON
# Usage: json_escape "string with \"quotes\" and \n newlines"
# Returns: Escaped string safe for JSON
json_escape() {
    local input="$1"

    # Use jq for proper JSON string escaping
    printf '%s' "$input" | jq -R -s '.'
}

# Build JSON object from key-value pairs
# Usage: json_object "key1" "value1" "key2" "value2" ...
# Returns: JSON object string
# Note: All values are treated as strings. For complex values, pass pre-formatted JSON.
json_object() {
    local -a args=()
    local -a pairs=()

    # Process arguments in pairs
    while (( $# >= 2 )); do
        local key="$1"
        local value="$2"
        shift 2

        # Add to jq args
        args+=("--arg" "$key" "$value")

        # Build key reference for jq expression
        pairs+=("$key: \$$key")
    done

    if (( ${#pairs[@]} == 0 )); then
        echo "{}"
        return 0
    fi

    # Build jq expression
    local expr=$(IFS=,; echo "{${pairs[*]}}")

    # Execute jq to build object
    jq -n "${args[@]}" "$expr"
}

# Build JSON array from items
# Usage: json_array "item1" "item2" "item3" ...
# Returns: JSON array string
# Note: Items are treated as strings. For objects/arrays, pass pre-formatted JSON.
json_array() {
    local -a items=()

    # Collect all arguments
    for item in "$@"; do
        items+=("$item")
    done

    if (( ${#items[@]} == 0 )); then
        echo "[]"
        return 0
    fi

    # Use jq to build array from arguments
    local -a args=()
    local -a refs=()
    local i=0

    for item in "${items[@]}"; do
        local var="item$i"
        args+=("--arg" "$var" "$item")
        refs+=("\$$var")
        ((i++))
    done

    local expr=$(IFS=,; echo "[${refs[*]}]")
    jq -n "${args[@]}" "$expr"
}

# Build JSON array from existing JSON objects/arrays
# Usage: json_array_of_json "json_obj1" "json_obj2" ...
# Returns: JSON array containing the objects
# Note: Unlike json_array, this expects valid JSON strings as input
json_array_of_json() {
    if (( $# == 0 )); then
        echo "[]"
        return 0
    fi

    # Combine JSON items into array using jq -s
    printf '%s\n' "$@" | jq -s '.'
}

# Build JSON object with JSON values (not just strings)
# Usage: json_object_with_json "key1" '{"nested": "object"}' "key2" '[1,2,3]'
# Returns: JSON object with properly formatted values
json_object_with_json() {
    local -a args=()
    local -a pairs=()

    # Process arguments in pairs
    while (( $# >= 2 )); do
        local key="$1"
        local value="$2"
        shift 2

        # Add to jq args as JSON (--argjson)
        args+=("--argjson" "$key" "$value")

        # Build key reference for jq expression
        pairs+=("$key: \$$key")
    done

    if (( ${#pairs[@]} == 0 )); then
        echo "{}"
        return 0
    fi

    # Build jq expression
    local expr=$(IFS=,; echo "{${pairs[*]}}")

    # Execute jq to build object
    jq -n "${args[@]}" "$expr"
}

# Export functions
export -f json_escape
export -f json_object
export -f json_array
export -f json_array_of_json
export -f json_object_with_json
