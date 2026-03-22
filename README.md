# Claude Homelab

Claude Code skills, agents, and commands for self-hosted homelab service management. Talk to your Plex server, add movies to Radarr, monitor your Unraid array, check what's downloading — all through natural conversation in Claude Code.

---

## Table of Contents

- [How It Works](#how-it-works)
- [Install](#install)
  - [Plugin Path (Claude Code native)](#plugin-path-claude-code-native)
  - [Bash Path (fresh machine)](#bash-path-fresh-machine)
- [After Install: First-Time Setup](#after-install-first-time-setup)
- [Credential Management](#credential-management)
- [Service Plugins](#service-plugins)
- [Homelab-Core: What Gets Installed](#homelab-core-what-gets-installed)
  - [Skills](#skills)
  - [Agents](#agents)
  - [Commands](#commands)
- [Repository Structure](#repository-structure)
- [How Skills Work](#how-skills-work)
- [How the Plugin System Works](#how-the-plugin-system-works)
- [Bash Path Deep Dive](#bash-path-deep-dive)
- [Verification](#verification)
- [Adding a New Service Plugin](#adding-a-new-service-plugin)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

---

## How It Works

This repo provides two things:

1. **A Claude Code plugin marketplace** — a private registry of installable plugins, each wrapping a homelab service with skills, scripts, and documentation that Claude understands.

2. **A bash install path** — a traditional `curl | bash` installer that clones the repo and symlinks everything into `~/.claude/` so Claude Code discovers it automatically.

Both paths end at the same state: Claude Code knows about your homelab services, has their API wrappers, and can act on natural language requests like "what's currently downloading?" or "add Dune Part Two to Radarr."

**Credentials never touch the repo.** They live in `~/.claude-homelab/.env` (chmod 600), written there during setup, and read at runtime by service scripts.

---

## Install

Two paths — pick one.

### Plugin Path (Claude Code native)

The plugin path uses Claude Code's built-in plugin system. Plugins are copied to `~/.claude/plugins/cache/` when installed. No git clone, no symlinks.

```
# Step 1: Register this repo as a plugin marketplace
/plugin marketplace add jmagar/claude-homelab

# Step 2: Install the core plugin (agents, commands, setup wizard, health dashboard)
/plugin install homelab-core@jmagar-claude-homelab

# Step 3: Install only the services you actually run
/plugin install plex@jmagar-claude-homelab
/plugin install radarr@jmagar-claude-homelab
/plugin install sonarr@jmagar-claude-homelab
/plugin install overseerr@jmagar-claude-homelab
/plugin install prowlarr@jmagar-claude-homelab
/plugin install tautulli@jmagar-claude-homelab
/plugin install qbittorrent@jmagar-claude-homelab
/plugin install sabnzbd@jmagar-claude-homelab
/plugin install unraid@jmagar-claude-homelab
/plugin install unifi@jmagar-claude-homelab
/plugin install tailscale@jmagar-claude-homelab
/plugin install zfs@jmagar-claude-homelab
/plugin install fail2ban-swag@jmagar-claude-homelab
/plugin install gotify@jmagar-claude-homelab
/plugin install linkding@jmagar-claude-homelab
/plugin install memos@jmagar-claude-homelab
/plugin install bytestash@jmagar-claude-homelab
/plugin install paperless-ngx@jmagar-claude-homelab
/plugin install radicale@jmagar-claude-homelab
/plugin install nugs@jmagar-claude-homelab
/plugin install notebooklm@jmagar-claude-homelab
/plugin install gh-address-comments@jmagar-claude-homelab

# Step 4: Bootstrap the credentials file (one-time, plugin path only)
curl -sSL https://raw.githubusercontent.com/jmagar/claude-homelab/main/scripts/setup-creds.sh | bash

# Step 5: Run the interactive credential wizard inside Claude Code
/homelab-core:setup
```

**Why the separate `setup-creds.sh` for the plugin path?**
The plugin path copies files into Claude Code's plugin cache — it doesn't clone the repo to a known location on disk. The `setup-creds.sh` script creates `~/.claude-homelab/.env` (from the template) and installs `load-env.sh` to `~/.claude-homelab/`. This one-time step is needed before the service scripts can read credentials. After that, `/homelab-core:setup` walks you through filling in the actual values.

### Bash Path (fresh machine)

```bash
curl -sSL https://raw.githubusercontent.com/jmagar/claude-homelab/main/scripts/install.sh | bash
```

This does everything in one shot:

1. Checks that `git`, `jq`, and `curl` are installed
2. Clones the repo to `~/claude-homelab/` (or `git pull` if it already exists)
3. Runs `scripts/setup-creds.sh` — creates `~/.claude-homelab/.env` and installs `load-env.sh`
4. Runs `scripts/setup-symlinks.sh` — symlinks all service plugins, agents, and commands into `~/.claude/`
5. Runs `scripts/verify.sh` — confirms everything is in place
6. Prints next steps

After the script completes, open Claude Code and run:

```
/homelab-core:setup
```

---

## After Install: First-Time Setup

Regardless of which install path you used, the credential setup step is the same:

```
/homelab-core:setup
```

This is an **interactive wizard built into Claude Code** — not a bash script. When you invoke it, Claude walks you through:

1. Asks which services you run (grouped by category: Media, Downloads, Infrastructure, Utilities)
2. For each selected service, tells you exactly where to find the credential (e.g., "Radarr API key: Settings → General → API Key")
3. Asks you to paste the value
4. Writes it to `~/.claude-homelab/.env` immediately using `sed -i` — credential values are never echoed back or logged
5. Confirms each save before moving to the next service
6. Offers to run `/homelab-core:health` when complete to verify everything is reachable

You can re-run `/homelab-core:setup` at any time to update credentials for a specific service. It will only touch the keys for the service you select — nothing else in the file is modified.

Then check your services are reachable:

```
/homelab-core:health
```

This produces a dashboard like:

```
Service Health Dashboard
========================
Media           plex         ✓ reachable    https://plex.example.com:32400
                radarr       ✓ reachable    https://radarr.example.com
                sonarr       ⚠ unreachable  https://sonarr.example.com
                overseerr    ○ not configured

Downloads       qbittorrent  ✓ reachable    https://qbit.example.com
                sabnzbd      ✓ reachable    https://sabnzbd.example.com

Infrastructure  unraid       ✓ reachable    https://unraid.example.com/graphql
                unifi        ✓ reachable    https://unifi.example.com
                tailscale    ✓ reachable    (API)

Utilities       gotify       ✓ reachable    https://gotify.example.com
                linkding     ○ not configured
                memos        ✓ reachable    https://memos.example.com

Summary: 9 reachable  ·  1 unreachable  ·  3 not configured
```

**Status icons:**
- `✓ reachable` — URL responded with any HTTP code (including 401/403 — the service is up, credentials are a separate concern)
- `⚠ unreachable` — URL configured but timed out or connection refused after 5 seconds
- `○ not configured` — No URL set in `.env` (or set to a placeholder value)

After showing the dashboard, Claude offers context-sensitive help:
- Unreachable services: offers to help diagnose (check URL, test connection)
- Not-configured services: offers to run `/homelab-core:setup` for those specific services

---

## Credential Management

All credentials live in a single file: **`~/.claude-homelab/.env`**

This file is:
- Created by `setup-creds.sh` from the `.env.example` template in the repo
- Always `chmod 600` — readable only by your user
- Never committed to git (listed in `.gitignore`)
- Read at runtime by service scripts via `source`

### Manual editing

```bash
$EDITOR ~/.claude-homelab/.env
```

The file uses standard shell variable syntax:

```bash
# Single-instance services
PLEX_URL=https://plex.example.com:32400
PLEX_TOKEN=your_plex_token

RADARR_URL=https://radarr.example.com
RADARR_API_KEY=your_radarr_api_key

# Unraid (supports two servers; SERVER2 is optional)
UNRAID_SERVER1_NAME=your_server1_name
UNRAID_SERVER1_URL=https://your-unraid-server1/graphql
UNRAID_SERVER1_API_KEY=your_api_key

UNRAID_SERVER2_NAME=your_server2_name
UNRAID_SERVER2_URL=https://your-unraid-server2/graphql
UNRAID_SERVER2_API_KEY=your_api_key
```

### How scripts load credentials

Every service script sources `~/.claude-homelab/load-env.sh`, which provides three functions:

```bash
source "$HOME/.claude-homelab/load-env.sh"

# Load the .env file (auto-exports all variables into the environment)
load_env_file

# Validate specific variables exist and are non-empty
validate_env_vars "PLEX_URL" "PLEX_TOKEN"

# Combined: load + validate in one call
load_service_credentials "plex" "PLEX_URL" "PLEX_TOKEN"
```

`load-env.sh` is installed to `~/.claude-homelab/load-env.sh` by both install paths:
- **Bash path**: `setup-symlinks.sh` copies it from `lib/load-env.sh`
- **Plugin path**: `setup-creds.sh` copies it (from the repo if available, or fetches from GitHub)

The canonical source is `lib/load-env.sh` in this repo. If you need to update it, edit the source there and re-run `setup-symlinks.sh` (bash path) or `setup-creds.sh` (plugin path).

---

## Service Plugins

Install only the services you run. Each plugin is independent — install as many or as few as you need.

### Media

| Plugin | Install command | What it does | Credentials needed |
|--------|----------------|--------------|-------------------|
| `plex` | `/plugin install plex@jmagar-claude-homelab` | Browse libraries, search content, check active sessions, get now-playing info | `PLEX_URL`, `PLEX_TOKEN` |
| `radarr` | `/plugin install radarr@jmagar-claude-homelab` | Search and add movies, manage quality profiles, check download queue, manage collections | `RADARR_URL`, `RADARR_API_KEY` |
| `sonarr` | `/plugin install sonarr@jmagar-claude-homelab` | Search and add TV shows, manage seasons/episodes, monitor missing episodes | `SONARR_URL`, `SONARR_API_KEY` |
| `overseerr` | `/plugin install overseerr@jmagar-claude-homelab` | Submit and track media requests, check request status, manage user requests | `OVERSEERR_URL`, `OVERSEERR_API_KEY` |
| `prowlarr` | `/plugin install prowlarr@jmagar-claude-homelab` | Search indexers, manage indexer health, test indexer connectivity | `PROWLARR_URL`, `PROWLARR_API_KEY` |
| `tautulli` | `/plugin install tautulli@jmagar-claude-homelab` | Plex viewing statistics, playback history, user analytics, popular content reports | `TAUTULLI_URL`, `TAUTULLI_API_KEY` |

### Downloads

| Plugin | Install command | What it does | Credentials needed |
|--------|----------------|--------------|-------------------|
| `qbittorrent` | `/plugin install qbittorrent@jmagar-claude-homelab` | List active torrents, check download progress, pause/resume, manage categories | `QBITTORRENT_URL`, `QBITTORRENT_USERNAME`, `QBITTORRENT_PASSWORD` |
| `sabnzbd` | `/plugin install sabnzbd@jmagar-claude-homelab` | Monitor Usenet download queue, check speeds, manage NZB queue | `SABNZBD_URL`, `SABNZBD_API_KEY` |

### Infrastructure

| Plugin | Install command | What it does | Credentials needed |
|--------|----------------|--------------|-------------------|
| `unraid` | `/plugin install unraid@jmagar-claude-homelab` | Query array status, disk health, Docker containers, VMs, system info via GraphQL API. Supports two servers. | `UNRAID_*_URL`, `UNRAID_*_API_KEY` |
| `unifi` | `/plugin install unifi@jmagar-claude-homelab` | Monitor network devices, active clients, bandwidth usage, alerts | `UNIFI_URL`, `UNIFI_USERNAME`, `UNIFI_PASSWORD`, `UNIFI_SITE` |
| `tailscale` | `/plugin install tailscale@jmagar-claude-homelab` | List tailnet devices, check connectivity, manage ACLs, view device details | `TAILSCALE_API_KEY`, `TAILSCALE_TAILNET` |
| `zfs` | `/plugin install zfs@jmagar-claude-homelab` | Check pool health, scrub status, snapshot management, dataset info — uses local CLI, no credentials needed | (none) |

### Security

| Plugin | Install command | What it does | Credentials needed |
|--------|----------------|--------------|-------------------|
| `fail2ban-swag` | `/plugin install fail2ban-swag@jmagar-claude-homelab` | Check fail2ban jail status, banned IPs, SWAG proxy logs, unban IPs | (SSH/local access) |

### Utilities

| Plugin | Install command | What it does | Credentials needed |
|--------|----------------|--------------|-------------------|
| `gotify` | `/plugin install gotify@jmagar-claude-homelab` | Send push notifications to your phone/devices, list applications, view message history | `GOTIFY_URL`, `GOTIFY_TOKEN` |
| `linkding` | `/plugin install linkding@jmagar-claude-homelab` | Add, search, and manage bookmarks — full CRUD via REST API | `LINKDING_URL`, `LINKDING_API_KEY` |
| `memos` | `/plugin install memos@jmagar-claude-homelab` | Create and search notes, manage tags, attach resources | `MEMOS_URL`, `MEMOS_API_TOKEN` |
| `bytestash` | `/plugin install bytestash@jmagar-claude-homelab` | Store, search, and share code snippets — supports multi-file snippets and expiring share links | `BYTESTASH_URL`, `BYTESTASH_API_KEY` |
| `paperless-ngx` | `/plugin install paperless-ngx@jmagar-claude-homelab` | Upload documents, full-text search, manage tags, correspondents, and document types | `PAPERLESS_URL`, `PAPERLESS_API_TOKEN` |
| `radicale` | `/plugin install radicale@jmagar-claude-homelab` | Manage CalDAV calendars and CardDAV contacts — create events, search contacts | `RADICALE_URL`, `RADICALE_USERNAME`, `RADICALE_PASSWORD` |
| `nugs` | `/plugin install nugs@jmagar-claude-homelab` | Download live music from Nugs.net, browse concerts, manage downloads | Config at `~/.nugs/config.json` |

### Research & Development

| Plugin | Install command | What it does | Credentials needed |
|--------|----------------|--------------|-------------------|
| `notebooklm` | `/plugin install notebooklm@jmagar-claude-homelab` | Programmatic access to Google NotebookLM — create notebooks, add sources, generate audio overviews | Google account (browser-based) |
| `gh-address-comments` | `/plugin install gh-address-comments@jmagar-claude-homelab` | Pull all PR review comments from GitHub, address them systematically, mark resolved | `GITHUB_TOKEN` |

---

## Homelab-Core: What Gets Installed

`homelab-core` is the foundation plugin — install it first. It provides skills, agents, and commands that work regardless of which service plugins you have.

### Skills

Skills are loaded by Claude Code when you invoke them. They run inside the Claude session — no subprocess, no script execution required for the skill itself (though skills can invoke scripts).

**`/homelab-core:setup`** — Interactive credential wizard

Triggered by phrases like: "setup credentials", "configure plex", "add my API key", "setup homelab", "I just installed homelab-core", or any mention of needing to configure a specific service.

Walks you through credential setup one service at a time. Knows where to find each credential (Settings → General → API Key, etc.). Writes to `~/.claude-homelab/.env` without echoing values back. Re-runnable — when you run it again, it asks which service you want to update and only modifies those keys.

**`/homelab-core:health`** — Unified service health dashboard

Triggered by phrases like: "check health", "service status", "what's running", "is plex up", "verify my setup", "homelab health".

Runs `skills/health/scripts/check-health.sh`, which curl-checks every configured service with a 5-second timeout and outputs a JSON array. Claude parses that JSON and renders the formatted dashboard. After presenting results, Claude offers targeted help based on what it found.

### Agents

Agents are specialized Claude sub-instances for complex, multi-step workflows. They run as subprocesses with defined tool access and don't share context with the main session.

**`agentic-orchestrator`** — Multi-agent research coordinator

Coordinates complex research tasks that need multiple tools and sources. Spawns specialist agents (Exa, Firecrawl, NotebookLM) in parallel, collects their results, and synthesizes a comprehensive answer. Use this when a research task is too large or multi-faceted for a single agent.

**`exa-specialist`** — Semantic web search

Uses ExaAI's semantic search API to find conceptually related content across the web. Better than keyword search for technical research — understands meaning, not just string matching. Results are auto-indexed into a Qdrant vector database via the Axon RAG system for later retrieval.

**`firecrawl-specialist`** — Web scraping and crawling

Scrapes websites to clean markdown, crawls entire documentation domains, extracts structured data. Used by the orchestrator to deeply index reference material. Output is automatically embedded and stored in the vector database.

**`notebooklm-specialist`** — AI-powered research via NotebookLM

Adds sources to Google NotebookLM, conducts grounded Q&A, generates artifacts (audio overviews, study guides, briefing documents). Used for long-form research synthesis where you need to deeply understand a body of material.

### Commands

Commands are slash commands available in Claude Code's command palette (`/`). They provide pre-built workflows invokable with a single command.

**`/homelab:system-resources`** — Check CPU usage, RAM, temperature sensors, system load averages

**`/homelab:docker-health`** — Status of all running Docker containers: health checks, uptime, restart counts

**`/homelab:disk-space`** — Disk usage analysis across all mounts, largest directories, inode usage

**`/homelab:zfs-health`** — ZFS pool health, scrub status and schedule, recent errors, dataset usage

**`/agentic-research <topic>`** — Launches the full multi-agent deep research workflow for a topic

**`/notebooklm:create`** — Create a new NotebookLM notebook

**`/notebooklm:ask`** — Ask questions grounded in your notebook sources

**`/notebooklm:source`** — Add URLs or documents as sources to a notebook

**`/notebooklm:generate`** — Generate artifacts (audio overview, study guide, briefing doc, FAQ)

**`/notebooklm:download`** — Download generated artifacts to local files

**`/notebooklm:list`** — List notebooks, sources, or artifacts

**`/notebooklm:research`** — Run web research and automatically import results into a notebook

---

## Repository Structure

```
claude-homelab/
│
├── .claude-plugin/
│   ├── marketplace.json        # Plugin catalog — tells Claude Code what plugins this repo offers
│   └── plugin.json             # homelab-core plugin manifest — makes the repo root the homelab-core plugin
│
├── agents/                     # Agent definition files (homelab-core content)
│   ├── agentic-orchestrator.md # Dispatched as subagent for multi-source research
│   ├── exa-specialist.md       # Semantic web search via ExaAI
│   ├── firecrawl-specialist.md # Web scraping and crawling
│   └── notebooklm-specialist.md # AI research via Google NotebookLM
│
├── commands/                   # Slash command definitions (homelab-core content)
│   ├── agentic-research.md     # /agentic-research
│   ├── homelab/                # /homelab:* namespace
│   │   ├── system-resources.md # /homelab:system-resources
│   │   ├── docker-health.md    # /homelab:docker-health
│   │   ├── disk-space.md       # /homelab:disk-space
│   │   └── zfs-health.md       # /homelab:zfs-health
│   └── notebooklm/             # /notebooklm:* namespace
│       ├── create.md           # /notebooklm:create
│       ├── ask.md              # /notebooklm:ask
│       ├── source.md           # /notebooklm:source
│       ├── generate.md         # /notebooklm:generate
│       ├── download.md         # /notebooklm:download
│       ├── list.md             # /notebooklm:list
│       └── research.md         # /notebooklm:research
│
├── lib/
│   └── load-env.sh             # Shared credential loading library
│                               # Installed to ~/.claude-homelab/load-env.sh by both install paths
│
├── skills/                     # homelab-core skills (two skills, discovered as /homelab-core:*)
│   ├── setup/
│   │   └── SKILL.md            # /homelab-core:setup — interactive credential wizard
│   └── health/
│       ├── SKILL.md            # /homelab-core:health — service health dashboard
│       └── scripts/
│           └── check-health.sh # Curl-checks all configured services, outputs JSON array
│
├── service-plugins/            # Per-service plugins (22 services, each independent)
│   └── [service]/              # e.g., plex/, radarr/, sonarr/, unraid/, ...
│       ├── .claude-plugin/
│       │   └── plugin.json     # Plugin manifest: name, description, version, author
│       ├── skills/
│       │   └── [service]/
│       │       └── SKILL.md    # Skill definition — Claude reads this when the skill triggers
│       ├── scripts/            # Bash/Python/Node scripts that make actual API calls
│       │   └── *.sh / *.mjs    # Executable, source load-env.sh, output JSON
│       └── references/         # Documentation loaded by Claude on demand
│           ├── api-endpoints.md      # Complete API reference
│           ├── quick-reference.md    # Copy-paste examples
│           └── troubleshooting.md    # Common issues and fixes
│
└── scripts/                    # Install and maintenance scripts
    ├── install.sh              # Bash path entry point (target of curl | bash)
    ├── setup-creds.sh          # Creates ~/.claude-homelab/.env — used by both install paths
    ├── setup-symlinks.sh       # Bash path only: symlinks everything into ~/.claude/
    └── verify.sh               # Checks both install paths — reports status and errors
```

---

## How Skills Work

Understanding how skills work explains why things are structured the way they are.

### Discovery

Claude Code discovers skills by scanning `~/.claude/skills/` for directories. Within each directory it found, it looks for a `skills/<name>/SKILL.md` file — specifically one level deeper in a `skills/` subdirectory.

For a service plugin named `plex`, the full path Claude Code looks for is:

```
~/.claude/skills/plex/skills/plex/SKILL.md
```

This is why every service plugin has the nested `skills/<name>/` structure inside `service-plugins/<name>/`. The outer directory is the plugin root (what gets symlinked or copied); the inner `skills/<name>/SKILL.md` is where the skill definition lives per the spec.

For homelab-core skills, the same rule applies — `skills/setup/SKILL.md` and `skills/health/SKILL.md` are discovered relative to the homelab-core plugin root (the repo root itself).

### Loading: progressive disclosure

Skills use a three-level loading system to keep Claude Code's context window efficient:

**Level 1 — Metadata (always in context, ~100 words)**
The `name` and `description` fields from SKILL.md frontmatter. Always loaded at session start for every installed skill. Used to decide *when* to activate the skill. The description includes specific trigger phrases so Claude knows when a user request should invoke this skill.

**Level 2 — SKILL.md body (loaded when the skill triggers)**
The markdown content of SKILL.md. Contains the workflow instructions Claude follows, API syntax with examples, and pointers to reference files for more detail. Kept under 500 lines. Only loaded when the skill is active — doesn't pollute context otherwise.

**Level 3 — Reference files (loaded on demand)**
The `references/` directory. API endpoint lists, troubleshooting guides, quick reference sheets. No size limit — these can be as long as needed. Only loaded when Claude decides it needs the detail (e.g., you ask about a specific API parameter).

Scripts in `scripts/` are executed directly and never need to be read into context.

### How a skill invocation flows

1. You type: "what movies does my Radarr have?"
2. Claude scans skill metadata — finds radarr's description matches
3. Claude loads `service-plugins/radarr/skills/radarr/SKILL.md` into context
4. The SKILL.md tells Claude to run `scripts/radarr.sh list`
5. Claude executes the script
6. The script sources `~/.claude-homelab/load-env.sh`, loads `RADARR_URL` and `RADARR_API_KEY`, makes the API call, returns JSON
7. Claude reads the JSON and formats a human-readable response

### Scripts

Service scripts follow consistent conventions:
- Bash (`set -euo pipefail`), Python (type hints), or Node.js (ESM, async/await)
- Source `~/.claude-homelab/load-env.sh` to load credentials
- Validate required env vars before making any calls — fail fast with a clear message
- Output JSON to stdout for Claude to read
- Write errors and warnings to stderr
- Return exit code 0 on success, 1 on failure

Claude reads the JSON output and presents it in a human-readable format tailored to your question.

---

## How the Plugin System Works

### Marketplace registration

`.claude-plugin/marketplace.json` registers this repo as a private plugin marketplace. Its structure:

```json
{
  "name": "claude-homelab",
  "owner": { "name": "jmagar" },
  "metadata": {
    "version": "1.1.0",
    "description": "Homelab service management plugins for Claude Code"
  },
  "plugins": [
    {
      "name": "homelab-core",
      "source": "./",
      "metadata": { "description": "Core agents, commands, setup wizard, and health dashboard" }
    },
    {
      "name": "plex",
      "source": "./service-plugins/plex",
      "metadata": { "description": "Plex Media Server control and monitoring" }
    }
    // ... 21 more service plugins
  ]
}
```

When you run `/plugin marketplace add jmagar/claude-homelab`, Claude Code fetches this file from GitHub and registers the marketplace. Each plugin's `source` field points to a directory that must contain a `.claude-plugin/plugin.json`.

### Plugin manifests

Every plugin directory needs a `.claude-plugin/plugin.json`:

```json
{
  "name": "plex",
  "description": "Plex Media Server control and monitoring",
  "version": "1.0.0",
  "author": { "name": "jmagar" },
  "homepage": "https://github.com/jmagar/claude-homelab",
  "repository": "https://github.com/jmagar/claude-homelab"
}
```

**homelab-core is special**: its `plugin.json` is at `.claude-plugin/plugin.json` in the repo root, and its `source` in marketplace.json is `"./"`. This makes the entire repo root the homelab-core plugin — agents/, commands/, skills/, and lib/ are all discovered relative to the root. No separate subdirectory needed for the core plugin.

### What happens when you install a plugin

`/plugin install plex@jmagar-claude-homelab`:

1. Claude Code looks up `plex` in the marketplace — finds source path `./service-plugins/plex`
2. Fetches all files from `service-plugins/plex/` on GitHub
3. Copies them to `~/.claude/plugins/cache/jmagar-claude-homelab/plex/<version>/`
4. Reads `plugin.json` from `.claude-plugin/plugin.json` within the copied directory
5. Discovers skills at `skills/plex/SKILL.md` within the copied directory
6. Makes the `plex` skill available in subsequent sessions

No symlinks. No git clone. Files are copied to the plugin cache directory. This is why the plugin path doesn't need `setup-symlinks.sh`.

### Updating plugins (plugin path)

Plugins are pinned to the version installed. To get updates:

```
/plugin update plex@jmagar-claude-homelab
# or update all:
/plugin update --all
```

### Updating (bash path)

Symlinks point to the live repo. Just pull:

```bash
cd ~/claude-homelab && git pull
```

Changes are immediately available — no reinstall needed.

---

## Bash Path Deep Dive

The bash path is for users who prefer a traditional install, want live-updating skills via git pull, or don't use the Claude Code plugin marketplace.

### What setup-symlinks.sh does

`scripts/setup-symlinks.sh` creates symlinks from this repo into `~/.claude/`:

```
~/.claude/skills/plex           →  ~/claude-homelab/service-plugins/plex
~/.claude/skills/radarr         →  ~/claude-homelab/service-plugins/radarr
~/.claude/skills/sonarr         →  ~/claude-homelab/service-plugins/sonarr
... (all 22 service plugins)

~/.claude/agents/agentic-orchestrator.md   →  ~/claude-homelab/agents/agentic-orchestrator.md
~/.claude/agents/exa-specialist.md         →  ~/claude-homelab/agents/exa-specialist.md
~/.claude/agents/firecrawl-specialist.md   →  ~/claude-homelab/agents/firecrawl-specialist.md
~/.claude/agents/notebooklm-specialist.md  →  ~/claude-homelab/agents/notebooklm-specialist.md

~/.claude/commands/homelab/      →  ~/claude-homelab/commands/homelab/
~/.claude/commands/notebooklm/   →  ~/claude-homelab/commands/notebooklm/
~/.claude/commands/agentic-research.md  →  ~/claude-homelab/commands/agentic-research.md
```

It also:
- Copies `lib/load-env.sh` → `~/.claude-homelab/load-env.sh`
- Creates `~/.claude-homelab/.env` from `.env.example` if the file doesn't exist yet
- Skips existing valid symlinks (safe to re-run)
- Warns about conflicts without overwriting

**Note**: The homelab-core skills (`skills/setup/` and `skills/health/`) are not symlinked separately — they're part of the repo root which is the homelab-core plugin. They're available directly via the repo checkout. For the bash path, Claude Code discovers them through the skills/ directory at the repo root, provided the repo is at a discoverable location.

### Re-running setup-symlinks.sh

Safe to run multiple times. It skips symlinks that already point to the right place:

```bash
~/claude-homelab/scripts/setup-symlinks.sh
```

---

## Verification

Run this any time to check your complete install state:

```bash
~/claude-homelab/scripts/verify.sh
```

It checks everything and exits 0 (clean), warns on issues, or exits 1 on critical errors.

**What it checks:**

Credentials:
- `~/.claude-homelab/.env` exists and has `chmod 600` permissions
- File is non-empty (at least one configured credential line)
- `~/.claude-homelab/load-env.sh` is installed

Bash path (symlinks):
- Count of skill symlinks in `~/.claude/skills/` — broken symlinks listed individually
- Count of agent symlinks in `~/.claude/agents/`
- Count of command files in `~/.claude/commands/`

Plugin path:
- `marketplace.json` parses as valid JSON
- All `source` paths in marketplace.json point to existing directories in the repo
- `homelab-core` `plugin.json` exists and has a valid `name` field
- All 22 service plugin directories have a `.claude-plugin/plugin.json`

Homelab-core skills:
- `skills/setup/SKILL.md` present
- `skills/health/SKILL.md` present
- `skills/health/scripts/check-health.sh` is executable (`chmod +x`)

Sample output when clean:

```
=== Claude Homelab — Verification ===

Credentials
  ✓  .env exists with correct permissions (600)
  ✓  45 credential lines configured
  ✓  load-env.sh installed at /home/user/.claude-homelab/load-env.sh

Bash Path (symlinks)
  ✓  22 skill symlinks (all valid)
  ✓  4 agent symlinks
  ✓  7 command files

Plugin Path
  ✓  marketplace.json valid (23 plugins listed)
  ✓  All marketplace source paths exist
  ✓  homelab-core plugin.json valid (name: homelab-core)
  ✓  22 service plugins with valid manifests

Homelab-Core Skills
  ✓  /homelab-core:setup skill present
  ✓  /homelab-core:health skill present
  ✓  check-health.sh is executable

============================
  ✓  OK:       13

All good! Run /homelab-core:health in Claude Code to verify service connectivity.
```

---

## Adding a New Service Plugin

To add a new homelab service to this collection:

### 1. Create the plugin directory structure

```bash
mkdir -p service-plugins/myservice/{.claude-plugin,skills/myservice,scripts,references}
```

### 2. Write the plugin manifest

`service-plugins/myservice/.claude-plugin/plugin.json`:
```json
{
  "name": "myservice",
  "description": "One-line description of what this plugin does",
  "version": "1.0.0",
  "author": { "name": "jmagar" },
  "homepage": "https://github.com/jmagar/claude-homelab",
  "repository": "https://github.com/jmagar/claude-homelab"
}
```

### 3. Write the SKILL.md

`service-plugins/myservice/skills/myservice/SKILL.md`:
```markdown
---
name: myservice
description: "Short description. Use when the user asks to 'do X with myservice',
  'check myservice status', 'add something to myservice', or mentions myservice."
---

# MyService Skill

## Setup
Credentials: `MYSERVICE_URL`, `MYSERVICE_API_KEY` in `~/.claude-homelab/.env`

## Commands

List items:
```bash
bash ~/claude-homelab/service-plugins/myservice/scripts/myservice-api.sh list
```

## Workflow

When the user asks about myservice:
1. "List everything" → run the list command, present results
2. "Add X" → ask for confirmation, then run the add command
3. "Status" → run the status check, format the output
```

### 4. Write the API scripts

`service-plugins/myservice/scripts/myservice-api.sh`:
```bash
#!/bin/bash
set -euo pipefail

source "$HOME/.claude-homelab/load-env.sh"
load_service_credentials "myservice" "MYSERVICE_URL" "MYSERVICE_API_KEY"

cmd="${1:-list}"
case "$cmd" in
    list)
        curl -s -H "X-Api-Key: $MYSERVICE_API_KEY" "$MYSERVICE_URL/api/items" | jq .
        ;;
    *)
        echo "Unknown command: $cmd" >&2
        exit 1
        ;;
esac
```

Make it executable:
```bash
chmod +x service-plugins/myservice/scripts/myservice-api.sh
```

### 5. Write reference documentation

`service-plugins/myservice/references/api-endpoints.md` — full API reference
`service-plugins/myservice/references/quick-reference.md` — copy-paste examples
`service-plugins/myservice/references/troubleshooting.md` — common issues

### 6. Add to marketplace.json

In `.claude-plugin/marketplace.json`, add to the `plugins` array:
```json
{
  "name": "myservice",
  "source": "./service-plugins/myservice",
  "metadata": {
    "description": "MyService description"
  }
}
```

### 7. Add credentials to .env.example

```bash
# =============================================================================
# MYSERVICE
# =============================================================================
MYSERVICE_URL=https://your-myservice-url
MYSERVICE_API_KEY=your_api_key
```

### 8. Add the check-health.sh entry

In `skills/health/scripts/check-health.sh`, add:
```bash
check_service "myservice" "${MYSERVICE_URL:-}" "${MYSERVICE_API_KEY:+X-Api-Key: $MYSERVICE_API_KEY}"
```

### 9. Wire it up

**Bash path:**
```bash
ln -sf ~/claude-homelab/service-plugins/myservice ~/.claude/skills/myservice
# or re-run setup-symlinks.sh to pick it up automatically
~/claude-homelab/scripts/setup-symlinks.sh
```

**Plugin path:** Push to GitHub, then `/plugin update --all` or install by name.

---

## Security

**Credentials**
- `~/.claude-homelab/.env` is `chmod 600` — readable only by your user
- The file is in `.gitignore` — never committed, not even accidentally
- Service scripts never log or echo credential values
- The `/homelab-core:setup` wizard never displays values you paste in — they go directly into the file
- If you accidentally paste a credential into the Claude chat, Claude acknowledges it, doesn't repeat it, and reminds you it should only be in the `.env` file

**Transport**
- Configure your services with HTTPS where possible
- The health checker and service scripts use whatever URL you provide — `https://` is strongly recommended for anything not on localhost

**Rotating credentials**
```bash
/homelab-core:setup   # wizard — select the service to update
# or directly:
$EDITOR ~/.claude-homelab/.env
```

**What's safe to commit**
- Everything in this repo except `.env` (which is in `.gitignore`)
- `.env.example` contains only placeholder values — safe and intended to be committed
- All skill definitions, scripts, agents, commands — no secrets ever in these files

---

## Troubleshooting

### verify.sh shows errors

Run it and read the output. Each check prints specifically what's wrong and what command to run to fix it:

```bash
~/claude-homelab/scripts/verify.sh
```

### A service shows "unreachable" in /homelab-core:health

1. Verify the URL in `~/.claude-homelab/.env` is correct (including port if non-standard)
2. Test the URL directly: `curl -v <SERVICE_URL>`
3. Check the service container is running: `docker ps | grep <service-name>`
4. If behind a VPN or Tailscale, confirm you're connected
5. If it shows "reachable" but Claude can't make API calls, the API key is likely wrong — run `/homelab-core:setup` to update it

### Skills not appearing in Claude Code

After any install, **restart Claude Code** — skills load at session start and don't hot-reload.

For the **plugin path**: Confirm the plugin installed without errors. Try reinstalling:
```
/plugin install plex@jmagar-claude-homelab
```

For the **bash path**: Check the symlink exists and isn't broken:
```bash
ls -la ~/.claude/skills/plex
# Should show: ... ~/.claude/skills/plex -> /home/user/claude-homelab/service-plugins/plex
```

If it's broken (pointing to a path that doesn't exist), remove and recreate:
```bash
rm ~/.claude/skills/plex
~/claude-homelab/scripts/setup-symlinks.sh
```

### ".env not found" errors when scripts run

The credential file is missing. Run setup-creds.sh to create it:
```bash
curl -sSL https://raw.githubusercontent.com/jmagar/claude-homelab/main/scripts/setup-creds.sh | bash
```
Then fill in credentials with `/homelab-core:setup`.

### "plugin not found" when installing via plugin path

The marketplace might not be registered in this session. Re-add it:
```
/plugin marketplace add jmagar/claude-homelab
```
Then try the install again.

### check-health.sh: a service shows "reachable" but doesn't work

The health check uses a 5-second timeout and considers *any* HTTP response (including 401/403) as "reachable" — it's checking whether the service is up, not whether your credentials are correct. A 401 means the service is running but the API key is wrong. Run `/homelab-core:setup` to update the credential for that service.

### Broken symlinks after moving the repo

If you moved `~/claude-homelab/` to a different location, the symlinks in `~/.claude/skills/` are now broken. Fix them:

```bash
# Remove all broken symlinks
find ~/.claude/skills -maxdepth 1 -type l ! -e -delete
find ~/.claude/agents -maxdepth 1 -type l ! -e -delete
find ~/.claude/commands -maxdepth 1 -type l ! -e -delete

# Recreate from the new location
~/claude-homelab/scripts/setup-symlinks.sh
```

---

**Repository:** https://github.com/jmagar/claude-homelab
**Version:** 1.1.0
**Last Updated:** 2026-03-21
