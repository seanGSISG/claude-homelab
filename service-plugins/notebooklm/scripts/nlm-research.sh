#!/usr/bin/env bash
set -euo pipefail

# Script: nlm-research.sh
# Description: Start NotebookLM deep research, wait for completion, and import sources
# Usage: ./nlm-research.sh -n <notebook_id> "research query"

usage() {
    cat <<EOF
Usage: $0 -n <notebook_id> [options] "<research_query>"

Start NotebookLM deep research, poll until complete, and auto-import sources.

Options:
  -n <notebook_id>    Notebook ID (required)
  --mode <mode>       Research mode: deep (default) or fast
  --timeout <seconds> Max wait time in seconds (default: 1800 = 30 min)
  --poll-interval <s> Status check interval (default: 10 seconds)
  -h, --help          Show this help

Features:
  - Starts research with --no-wait
  - Polls using 'notebooklm research status --json'
  - Auto-imports all discovered sources when complete
  - Configurable timeout for long-running research

Examples:
  $0 -n abc123 "AI agent frameworks"
  $0 -n abc123 --mode fast "quick topic overview"
  $0 -n abc123 --timeout 3600 "comprehensive deep dive"

EOF
    exit 1
}

# Check dependencies
command -v notebooklm >/dev/null 2>&1 || {
    echo "Error: notebooklm CLI not found" >&2
    exit 1
}

command -v jq >/dev/null 2>&1 || {
    echo "Error: jq is required for JSON parsing" >&2
    echo "Install: sudo apt-get install jq (or brew install jq)" >&2
    exit 1
}

# Defaults
NOTEBOOK_ID=""
MODE="deep"
TIMEOUT=1800  # 30 minutes default
POLL_INTERVAL=10
QUERY=""

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -n)
            NOTEBOOK_ID="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --poll-interval)
            POLL_INTERVAL="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            QUERY="$1"
            shift
            ;;
    esac
done

# Validate inputs
if [ -z "$NOTEBOOK_ID" ]; then
    echo "Error: Notebook ID is required (-n <notebook_id>)" >&2
    usage
fi

if [ -z "$QUERY" ]; then
    echo "Error: Research query is required" >&2
    usage
fi

echo "========================================="
echo "NotebookLM Deep Research"
echo "========================================="
echo "Notebook:  $NOTEBOOK_ID"
echo "Query:     $QUERY"
echo "Mode:      $MODE"
echo "Timeout:   ${TIMEOUT}s"
echo "========================================="
echo ""

# Start research (non-blocking)
echo "[1/3] Starting research..."
if ! notebooklm research -n "$NOTEBOOK_ID" --mode "$MODE" --no-wait "$QUERY"; then
    echo "Error: Failed to start research" >&2
    exit 2
fi

echo "  ✓ Research started"
echo ""

# Poll for completion
echo "[2/3] Waiting for completion (checking every ${POLL_INTERVAL}s)..."
ELAPSED=0
STATUS="running"

while [ "$STATUS" = "running" ] && [ $ELAPSED -lt $TIMEOUT ]; do
    sleep $POLL_INTERVAL
    ((ELAPSED+=POLL_INTERVAL))

    # Get status as JSON
    STATUS_JSON=$(notebooklm research status -n "$NOTEBOOK_ID" --json 2>/dev/null || echo "{}")
    STATUS=$(echo "$STATUS_JSON" | jq -r '.status // "unknown"')

    echo "  [${ELAPSED}s] Status: $STATUS"

    if [ "$STATUS" = "complete" ]; then
        break
    elif [ "$STATUS" = "failed" ]; then
        echo "Error: Research failed" >&2
        exit 2
    elif [ "$STATUS" = "unknown" ]; then
        echo "Warning: Could not determine status, continuing..." >&2
    fi
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "Error: Research timed out after ${TIMEOUT}s" >&2
    exit 3
fi

echo "  ✓ Research completed in ${ELAPSED}s"
echo ""

# Import sources
echo "[3/3] Importing discovered sources..."
if notebooklm research import -n "$NOTEBOOK_ID"; then
    echo "  ✓ Sources imported successfully"
else
    echo "  ✗ Failed to import sources" >&2
    exit 2
fi

echo ""
echo "========================================="
echo "Research Complete!"
echo "========================================="
