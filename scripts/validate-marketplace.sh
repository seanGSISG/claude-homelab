#!/bin/bash
# Validate marketplace.json structure

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKETPLACE_FILE="$REPO_ROOT/.claude-plugin/marketplace.json"

echo "=== Validating Claude Homelab Marketplace ==="
echo

# Check marketplace file exists
if [[ ! -f "$MARKETPLACE_FILE" ]]; then
    echo "❌ ERROR: marketplace.json not found at $MARKETPLACE_FILE"
    exit 1
fi

# Validate JSON syntax
if ! jq empty "$MARKETPLACE_FILE" 2>/dev/null; then
    echo "❌ ERROR: Invalid JSON syntax in marketplace.json"
    exit 1
fi
echo "✅ JSON syntax valid"

# Check required fields
MARKETPLACE_NAME=$(jq -r '.name' "$MARKETPLACE_FILE")
OWNER_NAME=$(jq -r '.owner.name' "$MARKETPLACE_FILE")
PLUGIN_COUNT=$(jq '.plugins | length' "$MARKETPLACE_FILE")

echo "✅ Marketplace name: $MARKETPLACE_NAME"
echo "✅ Owner: $OWNER_NAME"
echo "✅ Total plugins: $PLUGIN_COUNT"
echo

# Validate each plugin source path exists
echo "=== Validating Plugin Sources ==="
echo

FAILED=0
while IFS= read -r plugin_data; do
    NAME=$(echo "$plugin_data" | jq -r '.name')
    SOURCE=$(echo "$plugin_data" | jq -r '.source')
    VERSION=$(echo "$plugin_data" | jq -r '.version')

    # Resolve source path
    if [[ "$SOURCE" == ./* ]]; then
        SOURCE_PATH="$REPO_ROOT/$SOURCE"
    else
        SOURCE_PATH="$SOURCE"
    fi

    # Check if source exists
    if [[ -d "$SOURCE_PATH" ]]; then
        echo "✅ $NAME ($VERSION) - source exists at $SOURCE"
    else
        echo "❌ $NAME ($VERSION) - source NOT FOUND: $SOURCE"
        ((FAILED++)) || true
    fi
done < <(jq -c '.plugins[]' "$MARKETPLACE_FILE")

echo
if [[ $FAILED -eq 0 ]]; then
    echo "✅ All plugin sources valid!"
    echo
    echo "=== Testing Marketplace Installation ==="
    echo
    echo "To test locally:"
    echo "  claude --plugin-dir $REPO_ROOT"
    echo
    echo "To add marketplace:"
    echo "  /plugin marketplace add $REPO_ROOT"
    echo
    echo "To install a plugin:"
    echo "  /plugin install homelab-core@claude-homelab"
    echo "  /plugin install plex@claude-homelab"
    echo
else
    echo "❌ $FAILED plugin source(s) invalid"
    exit 1
fi
