# Claude Homelab Marketplace

A comprehensive collection of Claude Code skills and agents for homelab service management.

## What's Included

### Core Functionality
- **homelab-core**: Specialized agents and system monitoring commands
  - Agents: agentic-orchestrator, exa-specialist, firecrawl-specialist, notebooklm-specialist
  - Commands: `/agentic-research`, `/firecrawl:*`, `/homelab:*`, `/notebooklm:*`

### Categories

#### 📺 Media Management (6 skills)
- **plex** - Control Plex Media Server
- **radarr** - Movie management with TMDB integration
- **sonarr** - TV show management with TVDB integration
- **overseerr** - Media request system
- **prowlarr** - Indexer search and management
- **tautulli** - Plex analytics and monitoring

#### ⬇️ Download Clients (2 skills)
- **qbittorrent** - Torrent management
- **sabnzbd** - Usenet download management

#### 🏗️ Infrastructure (5 skills)
- **unraid** - Server monitoring via GraphQL API
- **unifi** - Network monitoring and management
- **tailscale** - VPN mesh network management
- **glances** - System health monitoring
- **zfs** - ZFS pool management with Sanoid/Syncoid

#### 🔒 Security (2 skills)
- **authelia** - Authentication monitoring
- **fail2ban-swag** - Intrusion prevention

#### 🛠️ Utilities (8 skills)
- **gotify** - Push notifications
- **linkding** - Bookmark management
- **memos** - Note-taking and knowledge management
- **bytestash** - Code snippet storage
- **paperless-ngx** - Document management with OCR
- **radicale** - CalDAV/CardDAV server
- **nugs** - Live music downloads from Nugs.net

#### 🔍 Research & AI (5 skills)
- **firecrawl** - Web scraping with RAG capabilities
- **exa** - Semantic web search
- **notebooklm** - Google NotebookLM integration
- **openai-docs** - OpenAI documentation access
- **agentic-research** - Multi-agent research playbook
- **agentic-research-orchestration** - Research orchestration

#### 💻 Development (3 skills)
- **gh-address-comments** - GitHub PR review handling
- **validating-plans** - Implementation plan validation
- **clawhub** - ClawHub skill marketplace CLI

## Installation

### Add the Marketplace

**From GitHub:**
```bash
/plugin marketplace add jmagar/claude-homelab
```

**From Local Clone:**
```bash
git clone https://github.com/jmagar/claude-homelab.git ~/claude-homelab
/plugin marketplace add ~/claude-homelab
```

### Install Individual Skills

Install specific skills you need:

```bash
# Install media management tools
/plugin install plex@claude-homelab
/plugin install radarr@claude-homelab
/plugin install sonarr@claude-homelab

# Install system monitoring
/plugin install homelab-core@claude-homelab
/plugin install glances@claude-homelab
/plugin install unifi@claude-homelab

# Install research tools
/plugin install firecrawl@claude-homelab
/plugin install exa@claude-homelab
/plugin install notebooklm@claude-homelab
```

### Install All Skills

Install everything at once (not recommended - install only what you need):

```bash
/plugin install-all claude-homelab
```

## Configuration

All skills require credentials configured in `~/claude-homelab/.env`:

```bash
# Example .env configuration
PLEX_URL="https://plex.example.com:32400"
PLEX_TOKEN="your-plex-token"

RADARR_URL="https://radarr.example.com"
RADARR_API_KEY="your-api-key"

SONARR_URL="https://sonarr.example.com"
SONARR_API_KEY="your-api-key"

# ... etc
```

See `.env.example` in the repository root for a complete template with all services.

## Usage

After installing skills, use them via:

**Commands:**
```bash
# System monitoring
/homelab:system-resources
/homelab:docker-health
/homelab:zfs-health

# Web research
/firecrawl:scrape https://example.com
/firecrawl:query "search query"
/agentic-research "deep research topic"

# NotebookLM
/notebooklm:create "Research Notebook"
/notebooklm:source add <url>
/notebooklm:ask "question about sources"
```

**Skills (auto-invoked by Claude):**
- Say "check Plex" → activates `plex` skill
- Say "add a movie" → activates `radarr` skill
- Say "monitor system health" → activates appropriate monitoring skills

## Documentation

Each skill includes comprehensive documentation:

- **SKILL.md** - Claude-facing skill definition with commands and workflows
- **README.md** - User-facing setup and usage guide
- **references/** - Detailed API/command reference, troubleshooting, examples

Browse skill documentation:
```bash
cd ~/claude-homelab/skills/<skill-name>
cat README.md
```

## Updating

Update all installed skills:

```bash
/plugin marketplace update claude-homelab
/plugin update-all claude-homelab
```

Update specific skills:

```bash
/plugin update plex@claude-homelab
```

## Uninstalling

Remove individual skills:

```bash
/plugin uninstall plex@claude-homelab
```

Remove the marketplace:

```bash
/plugin marketplace remove claude-homelab
```

## Support

- **Repository**: https://github.com/jmagar/claude-homelab
- **Issues**: https://github.com/jmagar/claude-homelab/issues
- **Discussions**: https://github.com/jmagar/claude-homelab/discussions

## License

See LICENSE file in repository root.

## Version

Marketplace Version: 1.0.0

---

**Total Skills**: 32 (1 core + 31 service integrations)
