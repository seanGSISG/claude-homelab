# Claude Homelab

Comprehensive Claude Code skills, agents, and commands for homelab service management.

## 🎯 What This Is

A production-ready collection of Claude Code integrations for self-hosted homelab services, providing:

- **30+ Skills** - API wrappers for media servers, download clients, infrastructure, and utilities
- **Agents** - Specialized AI agents for complex multi-step workflows
- **Commands** - Reusable command definitions for common operations
- **Shared Libraries** - Common functionality for credential management and environment loading

## Repository Structure

```
claude-homelab/
├── .env.example                 # Credential template
├── lib/                         # Shared libraries
│   └── load-env.sh              # Environment variable loading
├── scripts/                     # Setup and install scripts
│   ├── install.sh               # One-liner installer
│   ├── setup-symlinks.sh        # Symlink skills into ~/.claude/
│   ├── setup-homelab.sh         # Interactive credential setup
│   └── verify-symlinks.sh       # Verify symlink health
├── agents/                      # Agent definitions
├── commands/                    # Slash command definitions
│   ├── homelab/                 # /homelab:* commands
│   ├── firecrawl/               # /firecrawl:* commands
│   └── notebooklm/              # /notebooklm:* commands
└── skills/                      # Individual skills (30+)
    └── [service]/
        ├── SKILL.md             # Skill definition
        ├── README.md            # User documentation
        ├── scripts/             # Executable scripts
        └── references/          # API docs, troubleshooting
```

Credentials live in `~/.claude-homelab/.env` (created by the installer).

## Quick Start

### One-liner install

```bash
curl -sSL https://raw.githubusercontent.com/jmagar/claude-homelab/main/scripts/install.sh | bash
```

This clones the repo, symlinks skills/agents/commands into `~/.claude/`, and stubs your credentials file.

### Manual install

```bash
git clone https://github.com/jmagar/claude-homelab.git ~/claude-homelab
cd ~/claude-homelab
./scripts/setup-symlinks.sh
```

### Add your credentials

```bash
$EDITOR ~/.claude-homelab/.env
```

Fill in the services you use — each skill's README lists the required variables.

### Use with Claude Code

Restart Claude Code after installing to pick up the new skills, then:

- "What's on my Plex server?"
- "Add The Matrix to Radarr"
- "Show me my qBittorrent downloads"
- `/homelab:system-resources`
- `/homelab:docker-health`

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

## Security

- **Credentials live in `~/.claude-homelab/.env`** — never in the repo
- **Permissions are set automatically** — `chmod 600` by the installer
- **Use HTTPS** — update service URLs from HTTP to HTTPS
- **Rotate credentials regularly** — edit `~/.claude-homelab/.env`

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
