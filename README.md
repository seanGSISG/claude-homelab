# Claude Homelab

Comprehensive Claude Code skills, agents, and commands for homelab service management.

## Install

Two paths — pick one.

### Plugin path (Claude Code native)

```bash
# In Claude Code:
/plugin marketplace add jmagar/claude-homelab

# Install core (agents, commands, setup + health skills)
/plugin install homelab-core@jmagar-claude-homelab

# Install the services you run (repeat for each)
/plugin install plex@jmagar-claude-homelab
/plugin install radarr@jmagar-claude-homelab
/plugin install sonarr@jmagar-claude-homelab
# ... see full list below

# One-time credential setup
curl -sSL https://raw.githubusercontent.com/jmagar/claude-homelab/main/scripts/setup-creds.sh | bash

# Then in Claude Code — interactive wizard:
/homelab-core:setup
```

### Bash path (fresh machine)

```bash
curl -sSL https://raw.githubusercontent.com/jmagar/claude-homelab/main/scripts/install.sh | bash
```

Clones the repo, sets up credentials, symlinks everything into `~/.claude/`, and verifies the install. Then open Claude Code and run `/homelab-core:setup` to configure your service credentials.

---

## After Install

```bash
/homelab-core:setup    # interactive credential wizard
/homelab-core:health   # unified service health dashboard
```

---

## What's Included

### Core (`homelab-core`)
- **Agents**: agentic-orchestrator, exa-specialist, firecrawl-specialist, notebooklm-specialist
- **Commands**: `/agentic-research`, `/homelab:*`, `/notebooklm:*`
- **Skills**: `/homelab-core:setup` (credential wizard), `/homelab-core:health` (health dashboard)

### Service Plugins (install individually)

| Plugin | Category | What it does |
|--------|----------|-------------|
| `plex` | media | Browse libraries, search, now playing |
| `radarr` | media | Movie management |
| `sonarr` | media | TV show management |
| `overseerr` | media | Media request management |
| `prowlarr` | media | Indexer management |
| `tautulli` | media | Plex analytics |
| `qbittorrent` | downloads | Torrent management |
| `sabnzbd` | downloads | Usenet downloads |
| `unraid` | infrastructure | Unraid server monitoring (GraphQL) |
| `unifi` | infrastructure | UniFi network monitoring |
| `tailscale` | infrastructure | Tailscale VPN management |
| `zfs` | infrastructure | ZFS pool management |
| `fail2ban-swag` | security | Fail2ban + SWAG intrusion prevention |
| `gotify` | utilities | Push notifications |
| `linkding` | utilities | Bookmark management |
| `memos` | utilities | Note-taking |
| `bytestash` | utilities | Code snippet storage |
| `paperless-ngx` | utilities | Document management |
| `radicale` | utilities | Calendar + contacts (CalDAV/CardDAV) |
| `nugs` | utilities | Live music downloads (Nugs.net) |
| `notebooklm` | research | Google NotebookLM integration |
| `gh-address-comments` | development | GitHub PR review comment handling |

---

## Repository Structure

```
claude-homelab/
├── .claude-plugin/
│   ├── marketplace.json         # Plugin catalog (add this repo as a marketplace)
│   └── plugin.json              # homelab-core plugin manifest
├── agents/                      # Specialized AI agents
├── commands/                    # Slash commands (/homelab:*, /notebooklm:*, etc.)
├── lib/
│   └── load-env.sh              # Shared credential loader
├── skills/                      # homelab-core skills
│   ├── setup/SKILL.md           # /homelab-core:setup wizard
│   └── health/                  # /homelab-core:health dashboard
│       ├── SKILL.md
│       └── scripts/check-health.sh
├── service-plugins/             # Per-service plugins (22 services)
│   └── [service]/
│       ├── .claude-plugin/plugin.json
│       ├── skills/[service]/SKILL.md
│       ├── scripts/             # API client scripts
│       └── references/          # API docs, troubleshooting
└── scripts/
    ├── install.sh               # Bash path entry point
    ├── setup-creds.sh           # Credential bootstrap
    ├── setup-symlinks.sh        # Symlink service-plugins/ into ~/.claude/
    └── verify.sh                # Installation health check
```

Credentials live in `~/.claude-homelab/.env` — never committed, always `chmod 600`.

---

## Add your credentials

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
