#!/bin/bash
# Validate API documentation completeness and quality
# Checks for required sections, proper formatting, and tier-appropriate files

set -euo pipefail

SERVICES=(overseerr sonarr radarr prowlarr gotify
          qbittorrent plex sabnzbd tailscale linkding)

ERRORS=0
WARNINGS=0

echo "Validating API documentation..."
echo ""

for service in "${SERVICES[@]}"; do
  REF_DIR="skills/$service/references"
  API_DOC="$REF_DIR/api-endpoints.md"

  echo "Checking $service..."

  # Check references directory exists
  if [[ ! -d "$REF_DIR" ]]; then
    echo "  ❌ Missing references/ directory"
    ((ERRORS++))
    continue
  fi

  # Check api-endpoints.md exists
  if [[ ! -f "$API_DOC" ]]; then
    echo "  ❌ Missing api-endpoints.md"
    ((ERRORS++))
    continue
  fi

  # Check required sections
  required_sections=(
    "Authentication"
    "Base URL"
    "Quick Start"
    "Endpoints"
  )

  missing_sections=()
  for section in "${required_sections[@]}"; do
    if ! grep -qi "$section" "$API_DOC"; then
      missing_sections+=("$section")
      ((ERRORS++))
    fi
  done

  if [[ ${#missing_sections[@]} -gt 0 ]]; then
    echo "  ❌ Missing sections: ${missing_sections[*]}"
  fi

  # Check for curl examples
  if ! grep -q '```bash' "$API_DOC"; then
    echo "  ⚠️  No bash code blocks (curl examples) found"
    ((WARNINGS++))
  fi

  # Check markdown validity (if markdownlint available)
  if command -v markdownlint &>/dev/null; then
    if ! markdownlint "$API_DOC" 2>/dev/null; then
      echo "  ⚠️  Markdown formatting issues (run markdownlint for details)"
      ((WARNINGS++))
    fi
  fi

  # Check file size (too small = likely incomplete)
  lines=$(wc -l < "$API_DOC")
  if (( lines < 50 )); then
    echo "  ⚠️  Documentation seems incomplete ($lines lines, expected 50+)"
    ((WARNINGS++))
  fi

  # Check for tier-specific files
  case "$service" in
    overseerr|sonarr|radarr|prowlarr)  # Tier 3
      if [[ ! -f "$REF_DIR/quick-reference.md" ]]; then
        echo "  ⚠️  Missing quick-reference.md (Tier 3 service)"
        ((WARNINGS++))
      fi
      if [[ ! -f "$REF_DIR/troubleshooting.md" ]]; then
        echo "  ⚠️  Missing troubleshooting.md (Tier 3 service)"
        ((WARNINGS++))
      fi
      ;;
    qbittorrent|plex)  # Tier 2
      if [[ ! -f "$REF_DIR/quick-reference.md" ]]; then
        echo "  ⚠️  Missing quick-reference.md (Tier 2 service)"
        ((WARNINGS++))
      fi
      if [[ ! -f "$REF_DIR/troubleshooting.md" ]]; then
        echo "  ⚠️  Missing troubleshooting.md (Tier 2 service)"
        ((WARNINGS++))
      fi
      ;;
  esac

  # If no errors for this service, show success
  if [[ ${#missing_sections[@]} -eq 0 ]]; then
    echo "  ✅ Valid ($lines lines)"
  fi

  echo ""
done

echo "================================"
echo "Validation Summary"
echo "================================"
echo "Services checked: ${#SERVICES[@]}"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if (( ERRORS == 0 && WARNINGS == 0 )); then
  echo "✅ All documentation validated successfully!"
  exit 0
elif (( ERRORS == 0 )); then
  echo "✅ No errors found (but $WARNINGS warnings)"
  exit 0
else
  echo "❌ Found $ERRORS errors and $WARNINGS warnings"
  exit 1
fi
