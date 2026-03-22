#!/bin/bash
# Fix plugin structure for all skills in marketplace
# Converts standalone skills to proper plugin format

set -euo pipefail

cd "$(dirname "$0")/../.."

# List of all skills from marketplace.json (excluding homelab-core and special cases)
SKILLS=(
  "plex" "radarr" "sonarr" "overseerr" "prowlarr" "tautulli"
  "qbittorrent" "sabnzbd"
  "unraid" "unifi" "tailscale" "glances" "zfs"
  "authelia"
  "gotify" "linkding" "memos" "bytestash" "paperless-ngx" "radicale" "nugs"
  "firecrawl" "exa" "notebooklm" "openai-docs"
  "agentic-research" "agentic-research-orchestration"
  "gh-address-comments" "validating-plans" "clawhub"
)

echo "Fixing plugin structure for ${#SKILLS[@]} skills..."
echo

for skill in "${SKILLS[@]}"; do
  echo "Processing: $skill"
  skill_dir="skills/$skill"

  if [[ ! -d "$skill_dir" ]]; then
    echo "  ⚠️  Skipping (directory not found)"
    continue
  fi

  # Check if SKILL.md exists at root
  if [[ ! -f "$skill_dir/SKILL.md" ]]; then
    echo "  ⚠️  Skipping (no SKILL.md at root)"
    continue
  fi

  # Check if already has plugin structure
  if [[ -d "$skill_dir/skills/$skill" ]]; then
    echo "  ✓  Already has proper structure"
    continue
  fi

  # Create plugin.json if it doesn't exist
  if [[ ! -f "$skill_dir/.claude-plugin/plugin.json" ]]; then
    echo "  → Creating .claude-plugin/plugin.json"
    mkdir -p "$skill_dir/.claude-plugin"

    # Extract version from SKILL.md frontmatter
    version=$(grep "^version:" "$skill_dir/SKILL.md" | head -1 | awk '{print $2}' || echo "1.0.0")

    # Get description from marketplace.json
    description=$(jq -r ".plugins[] | select(.name == \"$skill\") | .description" .claude-plugin/marketplace.json)

    cat > "$skill_dir/.claude-plugin/plugin.json" <<EOF
{
  "name": "$skill",
  "description": "$description",
  "version": "$version",
  "author": {
    "name": "jmagar",
    "email": "jmagar@users.noreply.github.com"
  },
  "homepage": "https://github.com/jmagar/claude-homelab",
  "repository": "https://github.com/jmagar/claude-homelab"
}
EOF
  fi

  # Restructure skill directory
  echo "  → Moving SKILL.md to skills/$skill/"
  mkdir -p "$skill_dir/skills/$skill"
  mv "$skill_dir/SKILL.md" "$skill_dir/skills/$skill/"

  echo "  ✓  Complete"
done

echo
echo "All skills processed!"
echo
echo "Next steps:"
echo "1. Test locally: claude --plugin-dir ./service-plugins/gotify"
echo "2. Commit changes: git add . && git commit -m 'fix: restructure all skills for proper plugin format'"
echo "3. Push to repo: git push"
echo "4. On other machine: /plugin marketplace update jmagar/claude-homelab"
echo "5. On other machine: /plugin update gotify@claude-homelab"
