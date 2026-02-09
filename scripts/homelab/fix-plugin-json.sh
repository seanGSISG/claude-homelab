#!/bin/bash
# Remove invalid fields from plugin.json files
# tags and category belong in marketplace.json, not plugin.json

set -euo pipefail

cd "$(dirname "$0")/../.."

# Find all plugin.json files
find skills -name "plugin.json" -path "*/.claude-plugin/plugin.json" | while read -r file; do
  echo "Fixing: $file"

  # Remove tags and category fields using jq
  jq 'del(.tags, .category)' "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
done

echo "All plugin.json files fixed!"
