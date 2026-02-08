# Claude Homelab - Development Guidelines

Comprehensive Claude Code skills, agents, and commands for homelab service management.

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

### 2. Shared Library (lib/load-env.sh)

The `lib/load-env.sh` library provides centralized environment loading:

```bash
# Auto-detects .env in repository root
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
- Legacy: Some skills remain at root level (will be migrated)

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
3. `references/api-endpoints.md` - Complete API reference
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
- Ensure `.env` exists at repository root
- Copy from `.env.example` and add credentials

**"Permission denied"**
- Make scripts executable: `chmod +x scripts/*.sh`
- Check .env permissions: `chmod 600 .env`

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

**Version:** 1.0.0
**Last Updated:** 2026-02-08
