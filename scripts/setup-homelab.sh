#!/bin/bash
# Setup script for Claude Homelab
# Initializes .env file and validates configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Target directory for .env (hidden directory in home)
HOMELAB_DIR="${HOME}/.claude-homelab"
ENV_FILE="${HOMELAB_DIR}/.env"
ENV_EXAMPLE="${REPO_ROOT}/.env.example"

echo -e "${BLUE}=== Claude Homelab Setup ===${NC}"
echo

# Check if running from plugin installation
if [[ "$REPO_ROOT" == *"/.claude/plugins/installed/"* ]]; then
    echo -e "${GREEN}✓ Running from installed plugin${NC}"
    PLUGIN_INSTALL=true
else
    echo -e "${GREEN}✓ Running from repository clone${NC}"
    PLUGIN_INSTALL=false
fi

# Create homelab directory if it doesn't exist
if [[ ! -d "$HOMELAB_DIR" ]]; then
    echo -e "${YELLOW}Creating directory: $HOMELAB_DIR${NC}"
    mkdir -p "$HOMELAB_DIR"
fi

# Check if .env already exists
if [[ -f "$ENV_FILE" ]]; then
    echo -e "${YELLOW}⚠ .env file already exists at: $ENV_FILE${NC}"
    read -p "Do you want to backup and recreate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP="${ENV_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
        echo -e "${YELLOW}Backing up to: $BACKUP${NC}"
        cp "$ENV_FILE" "$BACKUP"
    else
        echo -e "${GREEN}Keeping existing .env file${NC}"
        echo -e "${BLUE}To view the template: cat $ENV_EXAMPLE${NC}"
        exit 0
    fi
fi

# Copy .env.example to .env
if [[ ! -f "$ENV_EXAMPLE" ]]; then
    echo -e "${RED}✗ .env.example not found at: $ENV_EXAMPLE${NC}"
    exit 1
fi

echo -e "${GREEN}Copying .env.example to $ENV_FILE${NC}"
cp "$ENV_EXAMPLE" "$ENV_FILE"

# Set secure permissions
chmod 600 "$ENV_FILE"
echo -e "${GREEN}✓ Set secure permissions (600) on .env${NC}"
echo

# Interactive configuration (optional)
echo -e "${BLUE}=== Interactive Configuration ===${NC}"
echo
echo "Would you like to configure services now?"
echo "You can also edit $ENV_FILE manually later."
echo
read -p "Configure now? (y/N) " -n 1 -r
echo
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Let's configure some common services...${NC}"
    echo

    # Firecrawl
    echo -e "${YELLOW}[Firecrawl - Web Scraping]${NC}"
    read -p "Do you have a Firecrawl API key? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter Firecrawl API key: " FIRECRAWL_KEY
        sed -i "s|FIRECRAWL_API_KEY=.*|FIRECRAWL_API_KEY=$FIRECRAWL_KEY|g" "$ENV_FILE"
        sed -i "s|#FIRECRAWL_API_KEY=|FIRECRAWL_API_KEY=|g" "$ENV_FILE"
        echo -e "${GREEN}✓ Firecrawl configured${NC}"
    fi
    echo

    # Gotify
    echo -e "${YELLOW}[Gotify - Notifications]${NC}"
    read -p "Do you have a Gotify server? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter Gotify URL: " GOTIFY_URL
        read -p "Enter Gotify token: " GOTIFY_TOKEN
        sed -i "s|GOTIFY_URL=.*|GOTIFY_URL=$GOTIFY_URL|g" "$ENV_FILE"
        sed -i "s|GOTIFY_TOKEN=.*|GOTIFY_TOKEN=$GOTIFY_TOKEN|g" "$ENV_FILE"
        sed -i "s|#GOTIFY_URL=|GOTIFY_URL=|g" "$ENV_FILE"
        sed -i "s|#GOTIFY_TOKEN=|GOTIFY_TOKEN=|g" "$ENV_FILE"
        echo -e "${GREEN}✓ Gotify configured${NC}"
    fi
    echo

    # Plex
    echo -e "${YELLOW}[Plex Media Server]${NC}"
    read -p "Do you have a Plex server? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter Plex URL (e.g., http://192.168.1.100:32400): " PLEX_URL
        read -p "Enter Plex token: " PLEX_TOKEN
        sed -i "s|PLEX_URL=.*|PLEX_URL=$PLEX_URL|g" "$ENV_FILE"
        sed -i "s|PLEX_TOKEN=.*|PLEX_TOKEN=$PLEX_TOKEN|g" "$ENV_FILE"
        sed -i "s|#PLEX_URL=|PLEX_URL=|g" "$ENV_FILE"
        sed -i "s|#PLEX_TOKEN=|PLEX_TOKEN=|g" "$ENV_FILE"
        echo -e "${GREEN}✓ Plex configured${NC}"
    fi
    echo
fi

# Summary
echo -e "${BLUE}=== Setup Complete ===${NC}"
echo
echo -e "${GREEN}✓ Configuration file created: $ENV_FILE${NC}"
echo -e "${GREEN}✓ Permissions set to 600 (owner read/write only)${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo
echo "1. Edit your configuration:"
echo -e "   ${BLUE}nano $ENV_FILE${NC}"
echo
echo "2. View all available services:"
echo -e "   ${BLUE}cat $ENV_EXAMPLE${NC}"
echo
echo "3. Install additional skills:"
echo -e "   ${BLUE}/plugin install plex@claude-homelab${NC}"
echo -e "   ${BLUE}/plugin install radarr@claude-homelab${NC}"
echo
echo "4. Test your configuration:"
echo -e "   ${BLUE}/homelab:system-resources${NC}"
echo
echo -e "${GREEN}Happy homelabbing! 🏠🤖${NC}"
