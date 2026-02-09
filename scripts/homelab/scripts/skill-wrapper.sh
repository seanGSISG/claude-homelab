#!/bin/bash
# Universal wrapper for skill scripts - guarantees output visibility
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: skill-wrapper.sh <path-to-script> [script-args...]"
    exit 1
fi

SCRIPT_PATH="$1"
shift  # Remove script path, leave remaining args

# Validate script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Error: Script not found: $SCRIPT_PATH"
    exit 1
fi

# Capture output and explicitly print
output=$("$SCRIPT_PATH" "$@" 2>&1)
printf '%s\n' "$output"
