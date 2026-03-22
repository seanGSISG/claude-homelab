#!/usr/bin/env bash
set -euo pipefail

# Script: nlm-bulk-add.sh
# Description: Add multiple URLs to a NotebookLM notebook from file, stdin, or args
# Usage: ./nlm-bulk-add.sh -n <notebook_id> <urls.txt|url1 url2 ...>

usage() {
    cat <<EOF
Usage: $0 -n <notebook_id> <url_file|url1 url2 ...>

Add multiple URLs to a NotebookLM notebook from various sources.

Options:
  -n <notebook_id>    Notebook ID (required)

Input Sources:
  url_file            File with URLs (one per line)
  -                   Read URLs from stdin
  url1 url2 ...       URLs as positional arguments

Features:
  - Skips blank lines and comments (lines starting with #)
  - Reports success/fail count at completion
  - Supports files, stdin, or direct arguments

Examples:
  $0 -n abc123 urls.txt
  cat urls.txt | $0 -n abc123 -
  echo "https://example.com" | $0 -n abc123 -
  $0 -n abc123 https://url1.com https://url2.com

EOF
    exit 1
}

# Check dependencies
command -v notebooklm >/dev/null 2>&1 || {
    echo "Error: notebooklm CLI not found" >&2
    echo "Install from: https://github.com/your-org/notebooklm-cli" >&2
    exit 1
}

# Parse arguments
NOTEBOOK_ID=""
while getopts "n:h" opt; do
    case $opt in
        n) NOTEBOOK_ID="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND-1))

# Validate notebook ID
if [ -z "$NOTEBOOK_ID" ]; then
    echo "Error: Notebook ID is required (-n <notebook_id>)" >&2
    usage
fi

# Determine input source
if [ $# -eq 0 ]; then
    echo "Error: No input provided" >&2
    usage
fi

SUCCESS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

# Function to add a single URL
add_url() {
    local url="$1"

    # Skip empty lines
    [ -z "$url" ] && return 0

    # Skip comments
    [[ "$url" =~ ^[[:space:]]*# ]] && return 0

    ((TOTAL_COUNT++))

    echo "Adding: $url"

    if notebooklm source add -n "$NOTEBOOK_ID" "$url" >/dev/null 2>&1; then
        ((SUCCESS_COUNT++))
        echo "  ✓ Added successfully"
    else
        ((FAIL_COUNT++))
        echo "  ✗ Failed to add" >&2
    fi
}

# Process input based on source
if [ "$1" = "-" ]; then
    # Read from stdin
    while IFS= read -r url; do
        add_url "$url"
    done
elif [ -f "$1" ]; then
    # Read from file
    while IFS= read -r url; do
        add_url "$url"
    done < "$1"
else
    # Treat all args as URLs
    for url in "$@"; do
        add_url "$url"
    done
fi

# Summary
echo ""
echo "========================================="
echo "Bulk Add Summary"
echo "========================================="
echo "Total URLs processed: $TOTAL_COUNT"
echo "Successfully added:   $SUCCESS_COUNT"
echo "Failed to add:        $FAIL_COUNT"
echo "========================================="

# Exit with error if any failed
[ $FAIL_COUNT -eq 0 ] || exit 1
