#!/usr/bin/env bash
set -euo pipefail

# Script: nlm-download.sh
# Description: Download all generated artifacts from NotebookLM notebook
# Usage: ./nlm-download.sh -n <notebook_id> -o ./output/

usage() {
    cat <<EOF
Usage: $0 -n <notebook_id> -o <output_dir> [options]

Download generated artifacts from a NotebookLM notebook to organized subdirectories.

Options:
  -n <notebook_id>    Notebook ID (required)
  -o <output_dir>     Output directory (required)
  --type <types>      Comma-separated types to download (default: all)
  --all               Download all available artifacts
  --latest            Download only latest of each type (default)
  -h, --help          Show this help

Artifact Types:
  report              Research reports (.md or .pdf)
  mind-map            Mind maps (.json)
  data-table          Data tables (.csv)
  infographic         Infographics (.png)
  study-guide         Study guides (.md)
  quiz                Quizzes (.md)
  flashcards          Flashcards (.md)
  slide-deck          Slide decks (.pdf)

Directory Structure:
  <output_dir>/
    ├── reports/
    ├── mind-maps/
    ├── data-tables/
    ├── infographics/
    ├── study-guides/
    ├── quizzes/
    ├── flashcards/
    └── slide-decks/

Examples:
  $0 -n abc123 -o ./research-artifacts/
  $0 -n abc123 -o ./output/ --type report,mind-map
  $0 -n abc123 -o ./artifacts/ --all

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
OUTPUT_DIR=""
TYPES=""
DOWNLOAD_ALL=false
LATEST_ONLY=true

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -n)
            NOTEBOOK_ID="$2"
            shift 2
            ;;
        -o)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --type)
            TYPES="$2"
            shift 2
            ;;
        --all)
            DOWNLOAD_ALL=true
            LATEST_ONLY=false
            shift
            ;;
        --latest)
            LATEST_ONLY=true
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

if [ -z "$OUTPUT_DIR" ]; then
    echo "Error: Output directory is required (-o <output_dir>)" >&2
    usage
fi

# Default types if not specified
if [ -z "$TYPES" ] && [ "$DOWNLOAD_ALL" = false ]; then
    TYPES="report,mind-map,data-table"
fi

echo "========================================="
echo "NotebookLM Artifact Download"
echo "========================================="
echo "Notebook:   $NOTEBOOK_ID"
echo "Output Dir: $OUTPUT_DIR"
echo "Types:      ${TYPES:-all}"
echo "Mode:       $([ "$LATEST_ONLY" = true ] && echo "latest only" || echo "all versions")"
echo "========================================="
echo ""

# Create output directory structure
mkdir -p "$OUTPUT_DIR"/{reports,mind-maps,data-tables,infographics,study-guides,quizzes,flashcards,slide-decks}

# Map types to subdirectories and extensions
declare -A TYPE_DIRS=(
    [report]="reports"
    [mind-map]="mind-maps"
    [data-table]="data-tables"
    [infographic]="infographics"
    [study-guide]="study-guides"
    [quiz]="quizzes"
    [flashcards]="flashcards"
    [slide-deck]="slide-decks"
)

declare -A TYPE_EXTS=(
    [report]=".md"
    [mind-map]=".json"
    [data-table]=".csv"
    [infographic]=".png"
    [study-guide]=".md"
    [quiz]=".md"
    [flashcards]=".md"
    [slide-deck]=".pdf"
)

SUCCESS_COUNT=0
FAIL_COUNT=0

# Download artifacts
download_type() {
    local TYPE="$1"
    local SUBDIR="${TYPE_DIRS[$TYPE]}"
    local EXT="${TYPE_EXTS[$TYPE]}"

    echo "Downloading: $TYPE → $SUBDIR/"

    local LATEST_FLAG=""
    [ "$LATEST_ONLY" = true ] && LATEST_FLAG="--latest"

    # Download artifact(s)
    local OUTPUT_PATH="$OUTPUT_DIR/$SUBDIR/${TYPE}${EXT}"

    if notebooklm artifact download -n "$NOTEBOOK_ID" --type "$TYPE" $LATEST_FLAG --output "$OUTPUT_PATH" 2>/dev/null; then
        ((SUCCESS_COUNT++))
        echo "  ✓ Downloaded to $SUBDIR/"
    else
        # Not necessarily an error - artifact type may not exist
        echo "  → No artifacts of type '$TYPE' found (skipping)"
    fi
}

# Process types
if [ -n "$TYPES" ]; then
    IFS=',' read -ra TYPE_ARRAY <<< "$TYPES"
    for TYPE in "${TYPE_ARRAY[@]}"; do
        if [ -n "${TYPE_DIRS[$TYPE]:-}" ]; then
            download_type "$TYPE"
        else
            echo "Warning: Unknown type '$TYPE', skipping" >&2
        fi
    done
else
    # Download all types
    for TYPE in "${!TYPE_DIRS[@]}"; do
        download_type "$TYPE"
    done
fi

echo ""
echo "========================================="
echo "Download Summary"
echo "========================================="
echo "Successful: $SUCCESS_COUNT"
echo "Skipped:    $FAIL_COUNT"
echo "Location:   $OUTPUT_DIR"
echo "========================================="
