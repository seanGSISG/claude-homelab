#!/bin/bash
# Remove invalid fields from SKILL.md frontmatter
# version and homepage belong in plugin.json, not SKILL.md

set -euo pipefail

cd "$(dirname "$0")/../.."

# Find all SKILL.md files
find skills -name "SKILL.md" -path "*/skills/*/SKILL.md" | while read -r file; do
  echo "Fixing: $file"

  # Remove version and homepage lines from frontmatter using sed
  # Only remove lines that are exactly "version: ..." or "homepage: ..." (no leading whitespace)
  sed -i '/^version:/d; /^homepage:/d' "$file"
done

echo "All SKILL.md files fixed!"
