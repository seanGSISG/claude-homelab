# Claude Homelab - Development Guidelines

Comprehensive Claude Code skills, agents, and commands for homelab service management.

## Table of Contents

- [Glossary](#glossary)
- [Repository Overview](#repository-overview)
- [Repository Structure](#repository-structure)
- [Source of Truth](#source-of-truth)
  - [Symlink Architecture](#symlink-architecture)
  - [How Slash Commands Work](#how-slash-commands-work)
  - [Command File Format](#command-file-format)
  - [Adding New Symlinks](#adding-new-symlinks)
  - [Automated Symlink Setup](#automated-symlink-setup)
- [Core Principles](#core-principles)
  - [1. Credential Management](#1-credential-management)
  - [2. Shared Library](#2-shared-library-libload-envsh)
  - [3. Directory Organization](#3-directory-organization)
  - [4. Git Workflow](#4-git-workflow)
  - [5. Code Standards](#5-code-standards)
  - [6. Documentation Standards](#6-documentation-standards)
- [Development Workflows](#development-workflows)
  - [Adding a New Skill](#adding-a-new-skill)
  - [Adding a New Agent](#adding-a-new-agent)
  - [Adding a New Command](#adding-a-new-command)
- [Common Patterns](#common-patterns)
  - [Error Handling](#error-handling)
  - [JSON Output](#json-output)
  - [Logging](#logging)
  - [Security Patterns](#security-patterns)
- [Testing](#testing)
  - [Manual Testing](#manual-testing)
  - [Integration Testing](#integration-testing)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
  - [Debug Mode](#debug-mode)
- [Security Best Practices](#security-best-practices)
- [Version Control](#version-control)
  - [Semantic Versioning](#semantic-versioning)
  - [Version Bump Examples](#version-bump-examples)
- [Links and Resources](#links-and-resources)

## Glossary

- **Skill**: A Claude Code plugin providing commands and scripts for a specific service (e.g., Plex, Radarr)
- **Agent**: A specialized AI agent for complex workflows (e.g., `agentic-orchestrator`, `firecrawl-specialist`)
- **Command**: A slash command invocable in Claude Code (e.g., `/firecrawl:scrape`, `/homelab:docker-health`)
- **Script**: Executable code in skill `scripts/` directories that performs API calls or system operations
- **Reference**: Detailed documentation in skill `references/` directories (API endpoints, troubleshooting, etc.)
- **Symlink**: Symbolic link connecting this repo to `~/.claude/` for Claude Code discovery
- **SKILL.md**: Claude-facing skill definition with commands, workflows, and examples
- **README.md**: User-facing documentation for setting up and using a skill
- **.env**: Environment file containing credentials (gitignored, NEVER commit)
- **.env.example**: Template credential file (tracked in git, NO secrets)

## Repository Overview

This repository provides production-ready integrations for self-hosted homelab services:

- **Individual Skills** (30+) - API wrappers for specific services (root level)
- **Agents** (`agents/`) - Specialized AI agents for complex workflows
- **Commands** (`commands/`) - Reusable command definitions
- **Shared Libraries** (`lib/`) - Common credential and environment management

## Repository Structure

```
claude-homelab/
├── README.md                    # User-facing documentation
├── CLAUDE.md                    # This file - development guidelines
├── AGENTS.md                    # Symlink to CLAUDE.md
├── GEMINI.md                    # Symlink to CLAUDE.md
├── .env                         # Credentials (gitignored, NEVER commit)
├── .env.example                 # Credential template (tracked)
├── .gitignore                   # Git ignore patterns
│
├── lib/                         # Shared libraries
│   └── load-env.sh              # Environment variable loading
│
├── agents/                      # Agent definitions
│   ├── agentic-orchestrator.md  # Multi-agent research coordinator
│   ├── exa-specialist.md        # ExaAI semantic search specialist
│   ├── firecrawl-specialist.md  # Web scraping specialist
│   └── notebooklm-specialist.md # NotebookLM research specialist
│
├── commands/                    # Slash commands (symlinked to ~/.claude/commands/)
│   ├── agentic-research.md      # /agentic-research command
│   ├── firecrawl/               # /firecrawl:* namespace
│   │   ├── scrape.md            # /firecrawl:scrape
│   │   ├── crawl.md             # /firecrawl:crawl
│   │   ├── map.md               # /firecrawl:map
│   │   ├── batch.md             # /firecrawl:batch
│   │   ├── extract.md           # /firecrawl:extract
│   │   ├── query.md             # /firecrawl:query
│   │   └── retrieve.md          # /firecrawl:retrieve
│   ├── homelab/                 # /homelab:* namespace
│   │   ├── system-resources.md  # /homelab:system-resources
│   │   ├── docker-health.md     # /homelab:docker-health
│   │   ├── disk-space.md        # /homelab:disk-space
│   │   └── zfs-health.md        # /homelab:zfs-health
│   └── notebooklm/              # /notebooklm:* namespace
│       ├── create.md            # /notebooklm:create
│       ├── ask.md               # /notebooklm:ask
│       ├── source.md            # /notebooklm:source
│       ├── generate.md          # /notebooklm:generate
│       ├── download.md          # /notebooklm:download
│       ├── list.md              # /notebooklm:list
│       └── research.md          # /notebooklm:research
│
├── skills/                      # Organized skill collection
│   ├── CLAUDE.md                # Skill development guidelines
│   ├── authelia/                # Individual skill directories
│   ├── bytestash/
│   ├── firecrawl/
│   ├── ... (30+ services)
│   └── [service]/
│       ├── SKILL.md             # Skill definition
│       ├── README.md            # User documentation
│       ├── scripts/             # Executable scripts
│       ├── references/          # Detailed documentation
│       └── examples/            # Usage examples
│
└── [service]/                   # Additional skills (root level - legacy)
    └── ... (exa, notebooklm, agentic-research-orchestration)
```

## Source of Truth

**This repository (`~/claude-homelab`) is the single source of truth for all homelab agents, skills, and commands.**

All definitions live here and are symlinked into `~/.claude/` for Claude Code discovery. Never edit files directly in `~/.claude/` — always edit in this repo.

### Symlink Architecture

```
~/.claude/
├── agents/
│   ├── agentic-orchestrator.md  → ~/claude-homelab/agents/agentic-orchestrator.md
│   ├── exa-specialist.md        → ~/claude-homelab/agents/exa-specialist.md
│   ├── firecrawl-specialist.md  → ~/claude-homelab/agents/firecrawl-specialist.md
│   └── notebooklm-specialist.md → ~/claude-homelab/agents/notebooklm-specialist.md
├── skills/
│   ├── firecrawl/               → ~/claude-homelab/skills/firecrawl/
│   ├── notebooklm/              → ~/claude-homelab/skills/notebooklm/
│   ├── plex/                    → ~/claude-homelab/skills/plex/
│   └── ...                      (all homelab skills)
└── commands/
    ├── agentic-research.md      → ~/claude-homelab/commands/agentic-research.md
    ├── firecrawl/               → ~/claude-homelab/commands/firecrawl/
    ├── homelab/                 → ~/claude-homelab/commands/homelab/
    └── notebooklm/              → ~/claude-homelab/commands/notebooklm/
```

### How Slash Commands Work

Slash commands are created by placing `.md` files in `~/.claude/commands/`. Claude Code discovers them automatically:

- **Single command:** `commands/proxy.md` → `/proxy`
- **Namespaced commands:** `commands/firecrawl/scrape.md` → `/firecrawl:scrape`

The **directory name** becomes the namespace prefix, the **file name** becomes the command after the colon.

### Command File Format

```yaml
---
description: Short description shown in autocomplete
argument-hint: <required> [optional]
allowed-tools: Bash(tool:*), mcp__plugin_name__tool
---

Task instruction using $ARGUMENTS

## Instructions
Steps for Claude to follow when this command is invoked.
```

Key fields:
- **`description`** — shown in autocomplete menu
- **`argument-hint`** — hint for expected arguments
- **`allowed-tools`** — pre-approved tools (no permission prompts)
- **`$ARGUMENTS`** — replaced with user input after the command
- **`!`command``** — dynamic context injection (runs shell command, injects output)

### Adding New Symlinks

When adding a new skill, agent, or command to this repo:

```bash
# Skills (directory symlink)
ln -sf ~/claude-homelab/skills/new-service ~/.claude/skills/new-service

# Agents (file symlink)
ln -sf ~/claude-homelab/agents/new-agent.md ~/.claude/agents/new-agent.md

# Commands - single file
ln -sf ~/claude-homelab/commands/new-cmd.md ~/.claude/commands/new-cmd.md

# Commands - namespaced directory
ln -sf ~/claude-homelab/commands/service-name ~/.claude/commands/service-name
```

### Automated Symlink Setup

Run the setup script to create all required symlinks automatically:

```bash
# Create all symlinks
./scripts/setup-symlinks.sh

# Verify symlinks are correct
./scripts/verify-symlinks.sh
```

The setup script will:
- Create `~/.claude/` directories if they don't exist
- Symlink all skills from `skills/` to `~/.claude/skills/`
- Symlink all agents from `agents/` to `~/.claude/agents/`
- Symlink all commands from `commands/` to `~/.claude/commands/`
- Report any errors or conflicts
- Skip existing valid symlinks

## Core Principles

### 1. Credential Management

**All credentials are stored in a single `.env` file at repository root.**

**Security requirements:**
- ✅ `.env` is gitignored (NEVER commit credentials)
- ✅ Set permissions: `chmod 600 .env`
- ✅ NEVER log credentials (even in debug mode)
- ✅ Use `.env.example` as a template (tracked in git)
- ❌ NO JSON config files with credentials
- ❌ NO hardcoded credentials in scripts

**Pattern for all scripts:**
```bash
# Bash scripts
source "$REPO_ROOT/lib/load-env.sh"
load_env_file || exit 1
validate_env_vars "SERVICE_URL" "SERVICE_API_KEY"

# Python scripts
from pathlib import Path
env_path = Path.home() / "claude-homelab" / ".env"
# Parse and load variables
```

**Environment variable naming:**
```bash
# Single instance services
SERVICE_URL="https://service.example.com"
SERVICE_API_KEY="your-api-key"

# Multi-instance services
SERVICE1_URL="https://server1.example.com"
SERVICE1_API_KEY="key1"
SERVICE2_URL="https://server2.example.com"
SERVICE2_API_KEY="key2"
```

**.env.example Template:**

The installer copies `.env.example` to `~/.claude-homelab/.env`. Template contents:

```bash
# =============================================================================
# PLEX MEDIA SERVER
# =============================================================================
PLEX_URL=https://your-plex-url:32400
PLEX_TOKEN=your_x_plex_token

# =============================================================================
# RADARR (MOVIE MANAGEMENT)
# =============================================================================
RADARR_URL=https://your-radarr-url
RADARR_API_KEY=your_api_key
RADARR_DEFAULT_QUALITY_PROFILE=1

# =============================================================================
# SONARR (TV SERIES MANAGEMENT)
# =============================================================================
SONARR_URL=https://your-sonarr-url
SONARR_API_KEY=your_api_key
SONARR_DEFAULT_QUALITY_PROFILE=1

# =============================================================================
# GOTIFY (NOTIFICATION SERVER)
# =============================================================================
GOTIFY_URL=https://your-gotify-url
GOTIFY_TOKEN=your_token

# =============================================================================
# FIRECRAWL (WEB SCRAPING/CRAWLING)
# =============================================================================
# Cloud API (recommended)
FIRECRAWL_API_KEY=fc-your_api_key
FIRECRAWL_API_URL=https://api.firecrawl.dev

# =============================================================================
# TAILSCALE (VPN/MESH NETWORK)
# =============================================================================
TAILSCALE_API_KEY=your_api_key
TAILSCALE_TAILNET=your_tailnet_or_dash
```

**Security Checklist:**
- [ ] `~/.claude-homelab/.env` has `chmod 600` permissions
- [ ] No credentials in code, docs, or commit history
- [ ] `.env.example` has placeholder values only

### 2. Shared Library (lib/load-env.sh)

The `lib/load-env.sh` library provides centralized environment loading:

```bash
# Loads ~/.claude-homelab/.env by default (or an explicit override)
load_env_file [/optional/path/to/.env]

# Validate required variables exist
validate_env_vars "VAR1" "VAR2" "VAR3"

# Load and validate service credentials
load_service_credentials "service-name" "URL_VAR" "API_KEY_VAR"
```

**All skills and scripts MUST use this library for credentials.**

### 3. Directory Organization

**Skills** - Organized in `skills/` subdirectory for clarity:
- Each skill in its own directory under `skills/`
- See `skills/CLAUDE.md` for skill development guidelines

**Agents** - Specialized AI agents in `agents/`:
- Markdown files defining agent behavior
- Used by orchestration systems
- Named `*-specialist.md` or `*-orchestrator.md`

**Commands** - Reusable commands in `commands/`:
- Markdown files defining command patterns
- Can be invoked via Claude Code
- Document common workflows

**Shared Code** - Common utilities in `lib/`:
- Bash libraries for credential loading
- Python utilities (future)
- JavaScript/Node utilities (future)

### 4. Git Workflow

**Branch strategy:**
- `main` - Production-ready code
- Feature branches for new skills/agents
- PR required before merge

**Commit conventions:**
```bash
# Format: <type>(<scope>): <description> (vX.Y.Z)
feat(radicale): add CalDAV/CardDAV skill (v1.0.0)
fix(plex): correct authentication headers (v1.2.1)
docs(readme): update skill catalog
refactor(lib): improve load-env error handling
```

**Never commit:**
- `.env` files (gitignored)
- Credentials or API keys
- Large binary files
- Temporary/debug files

### 5. Code Standards

**Bash scripts:**
- `set -euo pipefail` (strict mode)
- Quote all variables: `"$var"`
- Use functions for reusable code
- Include shebangs: `#!/bin/bash`
- Executable permissions: `chmod +x`
- Return JSON where appropriate

**Python scripts:**
- Type hints on all functions
- Google-style docstrings
- Use f-strings for formatting
- Async/await for I/O operations
- PEP 8 style guide

**Node.js scripts:**
- ESM modules (`.mjs` extension)
- `import` syntax (NOT `require`)
- Async/await for I/O
- No `any` types in TypeScript
- Strict mode enabled

### 6. Documentation Standards

**Every skill requires:**
1. `SKILL.md` - Claude Code skill definition
2. `README.md` - User-facing documentation
3. Reference documentation (choose based on skill type):
   - `references/api-endpoints.md` - For REST API services (Plex, Overseerr, etc.)
   - `references/command-reference.md` - For CLI tools (ZFS, git, docker, etc.)
   - `references/library-reference.md` - For libraries/SDKs
   - `references/config-reference.md` - For configuration schemas, options, and defaults
4. `references/quick-reference.md` - Quick examples
5. `references/troubleshooting.md` - Common issues

**Progressive disclosure:**
- SKILL.md: ~2,000 words (core syntax and workflows)
- References: Unlimited (detailed documentation)
- Examples: Complete, runnable code
- Scripts: Executable, not documentation

See `skills/CLAUDE.md` for detailed skill development guidelines.

## Development Workflows

### Adding a New Skill

1. **Use the skill creator:**
   ```
   /plugin-dev:create-plugin
   ```

2. **Create skill directory:**
   ```bash
   mkdir -p skills/service-name/{scripts,references,examples}
   ```

3. **Follow the skill template:**
   - Copy structure from existing skill
   - Update SKILL.md frontmatter (name, version, description)
   - Add mandatory skill invocation section
   - Document all commands with examples
   - Include workflow decision trees

4. **Implement scripts:**
   - Use `lib/load-env.sh` for credentials
   - Return JSON output
   - Include error handling
   - Support `--help` flag

5. **Create documentation:**
   - SKILL.md (Claude-facing)
   - README.md (user-facing)
   - references/ (detailed docs)

6. **Test thoroughly:**
   - Run scripts manually
   - Verify JSON output
   - Test error conditions
   - Check credential loading

7. **Update repository docs:**
   - Add skill to README.md catalog
   - Update skills/CLAUDE.md if needed

### Adding a New Agent

1. **Create agent definition:**
   ```bash
   touch agents/new-specialist.md
   ```

2. **Define agent behavior:**
   - Purpose and capabilities
   - Available tools
   - Workflow patterns
   - Integration points

3. **Document usage:**
   - When to invoke the agent
   - Input/output format
   - Example workflows

### Adding a New Command

Commands become slash commands in Claude Code via symlinks to `~/.claude/commands/`.

**Single command** (`/command-name`):
```bash
# Create in repo
touch commands/new-command.md
# Symlink to ~/.claude
ln -sf ~/claude-homelab/commands/new-command.md ~/.claude/commands/new-command.md
```

**Namespaced commands** (`/service:action`):
```bash
# Create directory in repo
mkdir -p commands/service-name
touch commands/service-name/action.md
# Symlink directory to ~/.claude
ln -sf ~/claude-homelab/commands/service-name ~/.claude/commands/service-name
```

**Command file format:**
```yaml
---
description: Short description for autocomplete
argument-hint: <required> [optional]
allowed-tools: Bash(tool:*), mcp__plugin__tool
---

Task: $ARGUMENTS

## Instructions
Steps for Claude to follow.
```

Key fields:
- `description` — shown in autocomplete
- `argument-hint` — expected arguments hint
- `allowed-tools` — pre-approved tools (no permission prompts)
- `$ARGUMENTS` — replaced with user input
- `` !`command` `` — dynamic context injection (shell output)

## Common Patterns

### Error Handling

```bash
# Bash - defensive error handling
if ! result=$(command 2>&1); then
    log_error "Command failed: $result"
    return 1
fi

# Timeout protection
if ! output=$(timeout 30 command 2>&1); then
    log_warn "Command timed out"
    return 0
fi
```

### JSON Output

```bash
# Bash - consistent JSON structure
cat <<EOF
{
  "success": true,
  "data": {
    "id": 123,
    "name": "Example"
  },
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

### Logging

```bash
# Use structured logging
log_info "Operation started"
log_warn "Potential issue detected"
log_error "Operation failed"
log_success "Operation completed"
```

### Security Patterns

**Input Sanitization:**

Always sanitize user input before using in commands, URLs, or API calls.

```bash
# Sanitize user input - remove dangerous characters
sanitize_input() {
    local input="$1"
    # Remove shell metacharacters and command injection attempts
    echo "$input" | sed 's/[;&|`$(){}[\]<>\\]//g' | tr -d '\n\r'
}

# Usage
user_query=$(sanitize_input "$1")
```

**Command Injection Prevention:**

Never directly interpolate user input into shell commands or URLs.

```bash
# ❌ DANGEROUS - Command injection vulnerability
curl "https://api.example.com/search?q=$user_input"

# ✅ SAFE - Properly escaped and quoted
query=$(printf '%s' "$user_input" | jq -sRr @uri)
curl "https://api.example.com/search?q=${query}"
```

**URL Encoding:**

Always URL-encode user input when building API requests.

```bash
# URL encode function
url_encode() {
    local string="$1"
    printf '%s' "$string" | jq -sRr @uri
}

# Usage
search_term=$(url_encode "user's search & query")
curl "https://api.example.com/search?q=${search_term}"
```

**SQL Injection Prevention (Python):**

Use parameterized queries, NEVER string concatenation.

```python
# ❌ DANGEROUS - SQL injection vulnerability
cursor.execute(f"SELECT * FROM users WHERE username = '{username}'")

# ✅ SAFE - Parameterized query
cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
```

**API Key Protection:**

Never log, print, or expose credentials.

```bash
# ❌ DANGEROUS - Logs API key
echo "Using API key: $API_KEY"
curl -H "Authorization: Bearer $API_KEY" https://api.example.com

# ✅ SAFE - No credential exposure
if [ -z "$API_KEY" ]; then
    log_error "API_KEY not set"
    exit 1
fi
curl -H "Authorization: Bearer $API_KEY" https://api.example.com 2>&1 | grep -v "Authorization"
```

**Path Traversal Prevention:**

Validate file paths to prevent directory traversal attacks.

```bash
# Validate file path is within allowed directory
validate_path() {
    local file_path="$1"
    local base_dir="$2"

    # Resolve to absolute path
    local abs_path=$(realpath -m "$file_path" 2>/dev/null)
    local abs_base=$(realpath "$base_dir")

    # Check if path starts with base directory
    if [[ "$abs_path" != "$abs_base"* ]]; then
        log_error "Invalid path: $file_path (outside base directory)"
        return 1
    fi

    echo "$abs_path"
}

# Usage
safe_path=$(validate_path "$user_file" "/allowed/directory") || exit 1
```

**JSON Response Parsing:**

Always validate JSON structure before parsing.

```bash
# Validate JSON response
parse_json_safely() {
    local json="$1"
    local key="$2"

    # Check if valid JSON
    if ! echo "$json" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response"
        return 1
    fi

    # Extract value
    echo "$json" | jq -r ".$key // empty"
}

# Usage
response=$(curl -s https://api.example.com/data)
value=$(parse_json_safely "$response" "data.field") || exit 1
```

## Testing

### Manual Testing

```bash
# Test credential loading
./scripts/test-script.sh

# Validate JSON output
./scripts/script.sh | jq .

# Test error conditions
SERVICE_URL="" ./scripts/script.sh  # Should fail gracefully
```

### Integration Testing

```bash
# Test full workflow
./scripts/search.sh "query"
./scripts/create.sh --title "Test"
./scripts/delete.sh 123
```

## Troubleshooting

### Common Issues

**".env file not found"**
- Run `scripts/setup-symlinks.sh` to create `~/.claude-homelab/.env` from `.env.example`
- Or manually: `cp .env.example ~/.claude-homelab/.env && chmod 600 ~/.claude-homelab/.env`

**"Permission denied"**
- Make scripts executable: `chmod +x scripts/*.sh`
- Check .env permissions: `chmod 600 ~/.claude-homelab/.env`

**"Command not found"**
- Install required dependencies (jq, curl, etc.)
- Check PATH includes script directory

**"Invalid JSON"**
- Validate with: `jq . < output.json`
- Check for unescaped quotes in strings

### Debug Mode

```bash
# Enable debug logging
DEBUG=1 ./scripts/script.sh

# Trace script execution
bash -x ./scripts/script.sh
```

## Security Best Practices

1. **Never commit credentials**
   - Always use `.env` file
   - Double-check before committing
   - Use `.env.example` as template

2. **Secure permissions**
   - `.env`: `chmod 600` (owner read/write only)
   - Scripts: `chmod +x` (executable)

3. **HTTPS in production**
   - Update service URLs from HTTP to HTTPS
   - Use valid SSL certificates

4. **Rotate credentials regularly**
   - Update `.env` file
   - Test all affected skills

5. **Review skill permissions**
   - Read-only vs read-write
   - Destructive operations require confirmation

## Version Control

### Semantic Versioning

Skills use semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR** (x.0.0): Breaking changes, removed features
- **MINOR** (1.x.0): New features, enhancements (backward compatible)
- **PATCH** (1.0.x): Bug fixes, documentation updates

### Version Bump Examples

```yaml
# Adding new feature
version: 1.1.0 → 1.2.0  # MINOR bump

# Fixing bug
version: 1.1.0 → 1.1.1  # PATCH bump

# Breaking API change
version: 1.2.0 → 2.0.0  # MAJOR bump
```

## Links and Resources

- **Repository:** https://github.com/jmagar/claude-homelab
- **Claude Code:** https://claude.ai/code
- **Skills Development:** See `skills/CLAUDE.md`
- **README:** See `README.md`

---

**Version:** 1.1.0
**Last Updated:** 2026-02-08
**Changelog:**
- Added Table of Contents
- Added Glossary section
- Added Automated Symlink Setup section with scripts
- Added .env.example template examples
- Added Security Patterns section with input sanitization examples
