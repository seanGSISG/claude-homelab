#!/usr/bin/env bash
set -euo pipefail

# Script: nlm-generate.sh
# Description: Generate useful artifacts from NotebookLM notebook sources
# Usage: ./nlm-generate.sh -n <notebook_id> --type report,mind-map

usage() {
    cat <<EOF
Usage: $0 -n <notebook_id> [options]

Generate artifacts from NotebookLM notebook sources.

Options:
  -n <notebook_id>    Notebook ID (required)
  --type <types>      Comma-separated artifact types (see below)
  --all               Generate all useful artifact types
  --format <format>   Format for report type (default: briefing-doc)
  --wait              Block until generation completes (default: no-wait)
  -h, --help          Show this help

Artifact Types:
  report              Research report (use --format to specify)
  mind-map            Mind map visualization (JSON)
  data-table          Data comparison table (CSV)
  infographic         Visual infographic (PNG)
  study-guide         Study guide document (MD)
  quiz                Quiz questions (MD)
  flashcards          Flashcard set (MD)
  slide-deck          Presentation slides (PDF)

Report Formats:
  briefing-doc        Executive briefing document (default)
  study-guide         Educational study guide
  comparison-table    Side-by-side comparison

Default Useful Set (used with --all):
  - report (briefing-doc format)
  - mind-map
  - data-table

Examples:
  $0 -n abc123 --all
  $0 -n abc123 --type report,mind-map,data-table
  $0 -n abc123 --type report --format study-guide --wait
  $0 -n abc123 --type infographic,quiz

EOF
    exit 1
}

# Check dependencies
command -v notebooklm >/dev/null 2>&1 || {
    echo "Error: notebooklm CLI not found" >&2
    exit 1
}

# Defaults
NOTEBOOK_ID=""
TYPES=""
GENERATE_ALL=false
REPORT_FORMAT="briefing-doc"
WAIT_FLAG=""

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -n)
            NOTEBOOK_ID="$2"
            shift 2
            ;;
        --type)
            TYPES="$2"
            shift 2
            ;;
        --all)
            GENERATE_ALL=true
            shift
            ;;
        --format)
            REPORT_FORMAT="$2"
            shift 2
            ;;
        --wait)
            WAIT_FLAG="--wait"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            usage
            ;;
    esac
done

# Validate inputs
if [ -z "$NOTEBOOK_ID" ]; then
    echo "Error: Notebook ID is required (-n <notebook_id>)" >&2
    usage
fi

# Determine which types to generate
if [ "$GENERATE_ALL" = true ]; then
    TYPES="report,mind-map,data-table"
elif [ -z "$TYPES" ]; then
    echo "Error: Must specify --type or --all" >&2
    usage
fi

echo "========================================="
echo "NotebookLM Artifact Generation"
echo "========================================="
echo "Notebook:  $NOTEBOOK_ID"
echo "Types:     $TYPES"
echo "Wait mode: ${WAIT_FLAG:-no-wait}"
echo "========================================="
echo ""

# Convert comma-separated types to array
IFS=',' read -ra TYPE_ARRAY <<< "$TYPES"

SUCCESS_COUNT=0
FAIL_COUNT=0
ARTIFACT_IDS=()

# Generate each artifact type
for TYPE in "${TYPE_ARRAY[@]}"; do
    echo "Generating: $TYPE"

    case "$TYPE" in
        report)
            CMD="notebooklm generate report -n \"$NOTEBOOK_ID\" --format \"$REPORT_FORMAT\" $WAIT_FLAG --json"
            ;;
        mind-map)
            CMD="notebooklm generate mind-map -n \"$NOTEBOOK_ID\" $WAIT_FLAG --json"
            ;;
        data-table)
            CMD="notebooklm generate data-table -n \"$NOTEBOOK_ID\" \"compare key findings\" $WAIT_FLAG --json"
            ;;
        infographic)
            CMD="notebooklm generate infographic -n \"$NOTEBOOK_ID\" $WAIT_FLAG --json"
            ;;
        study-guide)
            CMD="notebooklm generate study-guide -n \"$NOTEBOOK_ID\" $WAIT_FLAG --json"
            ;;
        quiz)
            CMD="notebooklm generate quiz -n \"$NOTEBOOK_ID\" $WAIT_FLAG --json"
            ;;
        flashcards)
            CMD="notebooklm generate flashcards -n \"$NOTEBOOK_ID\" $WAIT_FLAG --json"
            ;;
        slide-deck)
            CMD="notebooklm generate slide-deck -n \"$NOTEBOOK_ID\" $WAIT_FLAG --json"
            ;;
        *)
            echo "  ✗ Unknown artifact type: $TYPE" >&2
            ((FAIL_COUNT++))
            continue
            ;;
    esac

    # Execute generation
    if OUTPUT=$(eval "$CMD" 2>&1); then
        ((SUCCESS_COUNT++))

        # Extract artifact ID if JSON output
        if command -v jq >/dev/null 2>&1; then
            ARTIFACT_ID=$(echo "$OUTPUT" | jq -r '.id // empty' 2>/dev/null || echo "")
            if [ -n "$ARTIFACT_ID" ]; then
                ARTIFACT_IDS+=("$ARTIFACT_ID")
                echo "  ✓ Generated (ID: $ARTIFACT_ID)"
            else
                echo "  ✓ Generated"
            fi
        else
            echo "  ✓ Generated"
        fi
    else
        ((FAIL_COUNT++))
        echo "  ✗ Failed: $OUTPUT" >&2
    fi
done

echo ""
echo "========================================="
echo "Generation Summary"
echo "========================================="
echo "Successful: $SUCCESS_COUNT"
echo "Failed:     $FAIL_COUNT"

if [ ${#ARTIFACT_IDS[@]} -gt 0 ]; then
    echo ""
    echo "Artifact IDs (for download):"
    for ID in "${ARTIFACT_IDS[@]}"; do
        echo "  - $ID"
    done
fi

echo "========================================="

# Exit with error if any failed
[ $FAIL_COUNT -eq 0 ] || exit 1
