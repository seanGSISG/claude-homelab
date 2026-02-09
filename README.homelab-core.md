# Homelab Core Plugin

Core functionality for the Claude Homelab marketplace - includes specialized agents and system monitoring commands.

## What's Included

### Agents
- **agentic-orchestrator** - Coordinates multi-agent research operations
- **exa-specialist** - Semantic web search using ExaAI
- **firecrawl-specialist** - Web scraping and crawling specialist
- **notebooklm-specialist** - Google NotebookLM integration specialist

### Commands
- `/agentic-research` - Deep research with multiple agents
- `/firecrawl:*` - Web scraping commands (scrape, crawl, map, query, batch, extract)
- `/homelab:*` - System monitoring (system-resources, docker-health, disk-space, zfs-health)
- `/notebooklm:*` - NotebookLM operations (create, ask, source, generate, download, list)

## Installation

```bash
/plugin install homelab-core@claude-homelab
```

## Setup

### 1. Copy Environment Template

The plugin includes an `.env.example` file with all credential templates. Copy it to set up your environment:

```bash
# Find the plugin installation directory
PLUGIN_DIR=~/.claude/plugins/installed/homelab-core@claude-homelab

# Create your homelab directory if it doesn't exist
mkdir -p ~/claude-homelab

# Copy the environment template
cp "$PLUGIN_DIR/.env.example" ~/claude-homelab/.env

# Set secure permissions
chmod 600 ~/claude-homelab/.env
```

### 2. Configure Credentials

Edit `~/claude-homelab/.env` and add your service credentials:

```bash
# Example services - uncomment and configure as needed

# =============================================================================
# FIRECRAWL (WEB SCRAPING/CRAWLING)
# =============================================================================
FIRECRAWL_API_KEY=fc-your_api_key
FIRECRAWL_API_URL=https://api.firecrawl.dev

# =============================================================================
# EXA (SEMANTIC SEARCH)
# =============================================================================
EXA_API_KEY=your_exa_api_key

# =============================================================================
# NOTEBOOKLM (GOOGLE AI)
# =============================================================================
# Requires Google OAuth - see NotebookLM skill documentation
NOTEBOOKLM_COOKIE=your_cookie_value

# =============================================================================
# GOTIFY (NOTIFICATIONS)
# =============================================================================
GOTIFY_URL=https://your-gotify-url
GOTIFY_TOKEN=your_token

# Add more services as you install additional skills...
```

### 3. View the Full Template

To see all available services and their configuration options:

```bash
cat ~/.claude/plugins/installed/homelab-core@claude-homelab/.env.example
```

Or view it online:
https://github.com/jmagar/claude-homelab/blob/main/.env.example

## Usage

### Research Commands

```bash
# Deep multi-agent research
/agentic-research "topic to research in depth"

# Web scraping
/firecrawl:scrape https://example.com
/firecrawl:crawl https://docs.example.com --max-depth 3
/firecrawl:query "search embedded content"

# NotebookLM
/notebooklm:create "Research Notebook"
/notebooklm:source add <url>
/notebooklm:ask "question about your sources"
```

### System Monitoring

```bash
# System health
/homelab:system-resources
/homelab:docker-health
/homelab:disk-space
/homelab:zfs-health
```

## Installing Additional Skills

Browse available skills:
```bash
/plugin list claude-homelab
```

Install service-specific skills:
```bash
# Media management
/plugin install plex@claude-homelab
/plugin install radarr@claude-homelab
/plugin install sonarr@claude-homelab

# Infrastructure
/plugin install glances@claude-homelab
/plugin install unifi@claude-homelab
/plugin install tailscale@claude-homelab
```

Each skill will use credentials from the same `~/claude-homelab/.env` file.

## Troubleshooting

### Credentials Not Found

If commands report missing credentials:

1. Verify `.env` location:
   ```bash
   ls -la ~/claude-homelab/.env
   ```

2. Check file permissions:
   ```bash
   chmod 600 ~/claude-homelab/.env
   ```

3. Verify environment variables are set:
   ```bash
   grep "SERVICE_URL" ~/claude-homelab/.env
   ```

### Command Not Found

If commands don't work after installation:

1. Restart Claude Code to load new commands
2. Verify plugin is installed:
   ```bash
   /plugin list
   ```

## Documentation

- **Repository**: https://github.com/jmagar/claude-homelab
- **Issues**: https://github.com/jmagar/claude-homelab/issues
- **Full .env.example**: https://github.com/jmagar/claude-homelab/blob/main/.env.example

## Version

Plugin Version: 1.0.0
