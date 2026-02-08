# Claude Homelab

Comprehensive Claude Code skills, agents, and commands for homelab service management.

## 🎯 What This Is

A production-ready collection of Claude Code integrations for self-hosted homelab services, providing:

- **30+ Skills** - API wrappers for media servers, download clients, infrastructure, and utilities
- **Agents** - Specialized AI agents for complex multi-step workflows
- **Commands** - Reusable command definitions for common operations
- **Shared Libraries** - Common functionality for credential management and environment loading

## 📁 Repository Structure

```
claude-homelab/
├── README.md                    # This file
├── CLAUDE.md                    # Claude Code development guidelines
├── AGENTS.md                    # Symlink to CLAUDE.md
├── GEMINI.md                    # Symlink to CLAUDE.md
├── .env                         # Credentials (gitignored)
├── .env.example                 # Credential template
├── lib/                         # Shared libraries
│   └── load-env.sh              # Environment variable loading
├── agents/                      # Agent definitions
│   ├── agentic-orchestrator.md
│   ├── exa-specialist.md
│   ├── firecrawl-specialist.md
│   └── notebooklm-specialist.md
├── commands/                    # Command definitions
│   └── agentic-research.md
└── [service-name]/              # Individual skills (see below)
    ├── SKILL.md                 # Skill definition
    ├── README.md                # User documentation
    ├── scripts/                 # Executable scripts
    ├── references/              # Detailed documentation
    └── examples/                # Usage examples
```

## 🚀 Quick Start

### 1. Setup Credentials

Copy the example environment file and add your credentials:

```bash
cp .env.example .env
chmod 600 .env
```

Edit `.env` and add your service credentials. See individual skill README files for required variables.

### 2. Install Dependencies

**For Bash scripts:**
- Most skills work out of the box with standard Unix tools
- Some require `jq`, `curl`, `git` (usually pre-installed)

**For Python scripts:**
```bash
# For skills like radicale
pip install caldav vobject icalendar
```

**For Node.js scripts:**
```bash
# For skills like overseerr
# Node.js 18+ required (ESM modules)
```

### 3. Use a Skill

Each skill provides command-line tools you can run directly:

```bash
# List your Plex libraries
./plex/scripts/plex-api.sh libraries

# Search for a movie in Radarr
./radarr/scripts/radarr.sh search "Inception"

# Check qBittorrent status
./qbittorrent/scripts/qbit-api.sh status
```

Or use with Claude Code for natural language interactions:
- "What's on my Plex server?"
- "Add The Matrix to Radarr"
- "Show me my qBittorrent downloads"

## 📚 Skills Catalog

### Media Management

- **plex** - Plex Media Server control and monitoring
- **tautulli** - Plex analytics and viewing statistics
- **overseerr** - Media request management
- **sonarr** - TV show library management
- **radarr** - Movie library management with collections
- **prowlarr** - Indexer management and search

### Download Clients

- **qbittorrent** - Torrent management
- **sabnzbd** - Usenet download management

### Infrastructure

- **unraid** - Unraid server monitoring via GraphQL
- **unifi** - UniFi network monitoring
- **tailscale** - Tailnet management via CLI/API
- **glances** - System health monitoring

### Utilities

- **gotify** - Push notification system
- **linkding** - Bookmark management
- **memos** - Note and memo management
- **bytestash** - Code snippet storage
- **paperless-ngx** - Document management system
- **radicale** - CalDAV/CardDAV calendar and contacts
- **nugs** - Nugs.net live music downloader

### Security

- **authelia** - Authentication and authorization
- **fail2ban-swag** - Fail2ban integration for SWAG reverse proxy

### Research & AI

- **firecrawl** - Web scraping and crawling with RAG support
- **exa** - Semantic web search via ExaAI
- **notebooklm** - Google NotebookLM integration
- **agentic-research-orchestration** - Multi-agent research workflows
- **openai-docs** - OpenAI documentation access

## 🤖 Agents

Specialized agents for complex workflows:

- **agentic-orchestrator** - Coordinates multi-agent research operations
- **exa-specialist** - Semantic web search using ExaAI
- **firecrawl-specialist** - Web scraping and crawling operations
- **notebooklm-specialist** - AI-powered research via NotebookLM

See `agents/` directory for detailed agent definitions.

## 💻 Commands

Reusable command definitions:

- **agentic-research** - Deep research with multiple AI tools

See `commands/` directory for command definitions.

## 🔐 Security

- **Never commit `.env`** - It's gitignored by default
- **Set restrictive permissions** - `chmod 600 .env`
- **Use HTTPS in production** - Update service URLs from HTTP to HTTPS
- **Rotate credentials regularly** - Just update `.env` file
- **Review skill permissions** - Check if skills are read-only or read-write

## 📖 Documentation

Each skill includes comprehensive documentation:

- **SKILL.md** - Claude Code skill definition with trigger phrases and workflows
- **README.md** - User-facing documentation with setup and usage examples
- **references/api-endpoints.md** - Complete API reference
- **references/quick-reference.md** - Copy-paste command examples
- **references/troubleshooting.md** - Common issues and solutions

## 🛠️ Development

See **[CLAUDE.md](CLAUDE.md)** for:
- Skill development guidelines
- Credential management patterns
- Progressive disclosure documentation
- Code standards and conventions
- Testing and validation procedures

## 🌟 Features

- **Progressive Disclosure** - Skills load only what's needed for efficient context usage
- **Consistent Patterns** - All skills follow the same structure and conventions
- **Type Safety** - Python skills use type hints, Bash scripts use strict mode
- **Error Handling** - Clear error messages with actionable solutions
- **Comprehensive Docs** - Every skill includes quick reference and troubleshooting
- **Natural Language** - Works seamlessly with Claude Code's conversational interface
- **Credential Security** - Centralized `.env` file, never tracked in git

## 🤝 Contributing

When adding new skills:

1. **Use the skill creator** - `/plugin-dev:create-plugin` in Claude Code
2. **Follow conventions** - See CLAUDE.md for detailed guidelines
3. **Include all docs** - SKILL.md, README.md, and references
4. **Test thoroughly** - Verify JSON output and error handling
5. **Update this README** - Add your skill to the catalog

## 📝 License

This repository contains skills and integrations for various homelab services. Each service has its own license - refer to the official service documentation for licensing information.

## 🔗 Links

- **Claude Code** - https://claude.ai/code
- **Homelab Community** - https://www.reddit.com/r/homelab/
- **Self-Hosted Awesome List** - https://github.com/awesome-selfhosted/awesome-selfhosted

---

**Version:** 1.0.0
**Last Updated:** 2026-02-08
**Repository:** https://github.com/jmagar/claude-homelab
