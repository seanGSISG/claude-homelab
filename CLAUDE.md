# Skills Directory - Development Guidelines

**⚠️ CRITICAL: MANDATORY SKILL USAGE ⚠️**

**YOU MUST use the plugin-dev:create-plugin skill (NOT optional) when:**
- Creating ANY new skill in this directory
- Need skill structure guidance, templates, or best practices
- Setting up SKILL.md, README.md, or skill scripts
- Modifying skill patterns or conventions

**Failure to invoke this skill when creating new skills violates your operational requirements.**

---

This directory contains Claude Code skills for homelab service management. Skills provide structured API access to homelab services with consistent patterns for credentials, documentation, and scripting.

## Repository Structure

```
skills/
├── CLAUDE.md                     # This file - development guidelines
├── <service>/                    # One directory per service (lowercase)
│   ├── SKILL.md                  # Skill definition (REQUIRED)
│   ├── README.md                 # User documentation (REQUIRED)
│   ├── scripts/                  # Executable scripts
│   │   ├── *.sh                  # Bash scripts (with shebang)
│   │   ├── *.mjs                 # Node.js ESM scripts
│   │   └── *.js                  # Node.js scripts (if needed)
│   ├── references/               # Reference documentation
│   │   ├── api-endpoints.md      # Complete API reference
│   │   ├── quick-reference.md    # Quick command examples
│   │   └── troubleshooting.md    # Common issues and solutions
│   └── examples/                 # Example usage scripts (optional)
```

## Core Principles

### 1. Skill Definition (SKILL.md)

Every skill MUST have a `SKILL.md` file with YAML frontmatter and markdown documentation.

**Required frontmatter fields:**
```yaml
---
name: service-name                # lowercase, no spaces, matches directory name
version: 1.0.0                    # semantic versioning (x.y.z)
description: Detailed description with trigger phrases. Use when the user asks to "trigger phrase 1", "trigger phrase 2", or mentions [context].
---
```

**Optional frontmatter fields:**
```yaml
---
homepage: https://example.com    # Official project website (optional)
---
```

**Required markdown sections:**
1. **Title** — `# Service Name Skill`
2. **⚠️ Mandatory Skill Invocation Warning** — CRITICAL REQUIREMENT (see below)
3. **Purpose** — What the skill does, read-only vs read-write
4. **Setup** — Credential configuration with exact file paths
5. **Commands** — Copy-paste ready examples
6. **Workflow** — Common use cases with decision trees
7. **Notes** — Technical details, limitations, security considerations
8. **Reference** — Links to official documentation

### Progressive Disclosure Pattern

**CRITICAL PRINCIPLE:** Skills use a three-level loading system to manage context efficiently.

#### Loading Levels

1. **Metadata (name + description)** - Always in context (~100 words)
   - Loaded automatically when Claude Code starts
   - Used to determine when to activate the skill
   - Must include specific trigger phrases

2. **SKILL.md body** - Loaded when skill activates (~2,000 words max)
   - Condensed syntax reference and workflows
   - Essential commands with brief examples
   - Pointers to reference files for details
   - **Target length:** 200-300 lines (~2,000 words)
   - **Maximum:** 500 lines (~5,000 words) before requiring refactoring

3. **Bundled resources** - Loaded as needed by Claude
   - `references/` files loaded when Claude needs detailed info
   - `examples/` files loaded when user needs working code
   - `scripts/` executed without loading into context
   - **No size limits** - only loaded when needed

#### Why Progressive Disclosure Matters

- **Context window efficiency:** Don't waste tokens on content Claude doesn't need
- **Faster skill loading:** Smaller SKILL.md = faster context loading
- **Better discoverability:** Detailed content in references is easier to find than buried in long SKILL.md
- **Maintenance:** Easier to update one reference file than sections scattered in SKILL.md

#### SKILL.md Length Guidelines

**Target structure (~2,000 words):**
- Purpose section (30 lines)
- Setup section (20 lines, link to README for details)
- Commands section (40 lines, syntax only, link to references/commands.md)
- RAG section (30 lines, syntax only, link to references/vector-database.md)
- Workflows section (70 lines, keep decision trees)
- Notes section (30 lines, key points only)
- References section (20 lines, links to all reference files)

**If SKILL.md exceeds 500 lines:**
1. Extract detailed content to `references/` files
2. Keep only syntax and pointers in SKILL.md
3. Link to reference files for full documentation

#### References Directory (`references/`)

**Purpose:** Detailed documentation loaded as needed by Claude.

**Common reference files:**
- `references/api-endpoints.md` - Complete API reference
- `references/commands.md` - All commands with full parameters
- `references/parameters.md` - Parameters organized by category
- `references/job-management.md` - Async operations and job handling
- `references/vector-database.md` - RAG/vector DB specifics
- `references/quick-reference.md` - Copy-paste command examples
- `references/troubleshooting.md` - Common errors and solutions

**Best practices:**
- Each reference file can be 2,000-5,000+ words
- Organize by topic/function, not alphabetically
- Use descriptive names that indicate content
- Cross-reference between files where helpful
- Include examples within reference files

**When to create references:**
- Detailed API documentation (all endpoints, all parameters)
- Advanced configuration options
- Complex workflows with many steps
- Troubleshooting guides
- Migration guides
- Any content that makes SKILL.md too long

#### Examples Directory (`examples/`)

**Purpose:** Working code examples that users can copy and adapt.

**Common example files:**
- `examples/basic-scrape.sh` - Simple scraping example
- `examples/rag-pipeline.sh` - Complete RAG workflow
- `examples/batch-processing.sh` - Batch operation example
- `examples/monitor-website.sh` - Change monitoring example

**Best practices:**
- Examples are complete, runnable scripts
- Include comments explaining each step
- Use realistic scenarios
- Follow coding standards from main scripts
- Test all examples before committing

**When to create examples:**
- Common workflows that users request
- Complex multi-step operations
- Integration patterns
- Best practice demonstrations

#### Scripts Directory (`scripts/`)

**Purpose:** Executable utility scripts (not documentation).

**Distinction:**
- **Scripts** = Tools for execution (no need to read)
- **Examples** = Educational code for learning (meant to be read)

**Pattern:**
```
skills/service/
├── scripts/           # Utilities for execution
│   ├── api-wrapper.sh
│   └── health-check.sh
└── examples/          # Educational examples
    ├── basic-usage.sh
    └── advanced-workflow.sh
```

**CRITICAL: Mandatory Skill Invocation Section**

Every SKILL.md MUST include this section immediately after the title:

```markdown
**⚠️ MANDATORY SKILL INVOCATION ⚠️**

**YOU MUST invoke this skill (NOT optional) when the user mentions ANY of these triggers:**
- "trigger phrase 1", "trigger phrase 2", "trigger phrase 3"
- "action phrase 1", "status check phrase", "query phrase"
- Any mention of [service name] or [related functionality]

**Failure to invoke this skill when triggers occur violates your operational requirements.**
```

This section:
- Uses strong enforcement language (MUST, NOT optional, violates requirements)
- Lists specific trigger phrases (5-10 minimum)
- Makes it clear skill invocation is mandatory, not suggestive
- Appears immediately after the skill title, before Purpose section

### 2. User Documentation (README.md)

Every skill MUST have a `README.md` file with user-facing documentation.

**Structure:**
1. Title and brief description
2. "What It Does" — Bullet list of capabilities
3. "Setup" — Step-by-step credential setup
4. "Usage Examples" — Copy-paste commands with explanations
5. "Workflow" — Real-world usage scenarios
6. "Troubleshooting" — Common errors and solutions
7. "Notes" — Additional context

**Differences from SKILL.md:**
- README.md is user-facing (more explanatory, assumes less context)
- SKILL.md is Claude-facing (assumes Claude context, uses trigger phrases)
- README.md can be more verbose and educational
- SKILL.md is optimized for skill activation and API reference

### 3. Credential Management

All skills MUST use `.env` file for credentials. NO JSON config files.

**Required pattern:**
```bash
# In ~/workspace/homelab/.env
SERVICE_URL="http://localhost:PORT"
SERVICE_API_KEY="your-api-key"
```

**Common patterns:**

API Key authentication:
```bash
SERVICE_URL="https://service.example.com"
SERVICE_API_KEY="your-api-key-here"
```

Username/Password authentication:
```bash
SERVICE_URL="https://service.example.com"
SERVICE_USERNAME="admin"
SERVICE_PASSWORD="secure-password"
```

Multi-server setup:
```bash
# Server 1
SERVICE1_URL="http://server1.local:PORT"
SERVICE1_API_KEY="key1"

# Server 2
SERVICE2_URL="http://server2.local:PORT"
SERVICE2_API_KEY="key2"
```

**Loading credentials in scripts:**

Bash:
```bash
# Source the .env file
if [[ -f ~/workspace/homelab/.env ]]; then
    source ~/workspace/homelab/.env
else
    echo "ERROR: .env file not found at ~/workspace/homelab/.env" >&2
    exit 1
fi

# Validate required variables
if [[ -z "$SERVICE_URL" ]] || [[ -z "$SERVICE_API_KEY" ]]; then
    echo "ERROR: SERVICE_URL and SERVICE_API_KEY must be set in .env" >&2
    exit 1
fi
```

Node.js:
```javascript
import { readFile } from 'fs/promises';

async function loadEnv() {
    const envPath = `${process.env.HOME}/workspace/homelab/.env`;
    const content = await readFile(envPath, 'utf8');

    for (const line of content.split('\n')) {
        const match = line.match(/^([^#=]+)=(.+)$/);
        if (match) {
            const [, key, value] = match;
            process.env[key.trim()] = value.trim().replace(/^["']|["']$/g, '');
        }
    }
}
```

**Security requirements:**
- ✅ `.env` file is gitignored (NEVER commit)
- ✅ Set file permissions: `chmod 600 ~/workspace/homelab/.env`
- ✅ NEVER log credentials (even in debug mode)
- ✅ Always validate credentials exist before use
- ✅ Document exact variable names in Setup section
- ❌ NO JSON config files in `credentials/` directory
- ❌ NO hard-coded credentials in scripts

### 4. Script Standards

All scripts must follow these conventions:

#### Bash Scripts (.sh)

**File header:**
```bash
#!/bin/bash
# Script Name: script-name.sh
# Purpose: Brief description
# Usage: ./script-name.sh [arguments]

set -euo pipefail
```

**Standards:**
- Executable: `chmod +x script.sh`
- Use `set -euo pipefail` (strict mode)
- Quote all variables: `"$var"`
- Use functions for reusable code
- Return JSON output when appropriate
- Include error handling with clear messages
- Use `jq` for JSON parsing
- Support `--help` flag

**Example:**
```bash
#!/bin/bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 <command> [options]

Commands:
    list        List all items
    search      Search for items
    add         Add new item

Options:
    --help      Show this help message
EOF
}

main() {
    local cmd="${1:-}"
    case "$cmd" in
        list) list_items ;;
        search) search_items "$@" ;;
        --help) usage ;;
        *) echo "Unknown command: $cmd" >&2; usage; exit 1 ;;
    esac
}

main "$@"
```

#### Node.js Scripts (.mjs)

**File header:**
```javascript
#!/usr/bin/env node
/**
 * Script Name: script-name.mjs
 * Purpose: Brief description
 * Usage: node script-name.mjs [arguments]
 */
```

**Standards:**
- Use `.mjs` extension for ESM modules
- Use `import` syntax (NOT `require`)
- Use async/await for I/O operations
- Return JSON output when appropriate
- Include error handling with clear messages
- Use `fetch` API for HTTP requests (Node 18+)
- Support `--help` flag

**Example:**
```javascript
#!/usr/bin/env node
import { readFile } from 'fs/promises';

const ENV_PATH = `${process.env.HOME}/workspace/homelab/.env`;

async function loadEnv() {
    try {
        const content = await readFile(ENV_PATH, 'utf8');

        for (const line of content.split('\n')) {
            const match = line.match(/^([^#=]+)=(.+)$/);
            if (match) {
                const [, key, value] = match;
                process.env[key.trim()] = value.trim().replace(/^["']|["']$/g, '');
            }
        }
    } catch (error) {
        console.error(`Failed to load .env: ${error.message}`);
        process.exit(1);
    }
}

async function main() {
    await loadEnv();

    // Validate required environment variables
    const { SERVICE_URL, SERVICE_API_KEY } = process.env;
    if (!SERVICE_URL || !SERVICE_API_KEY) {
        console.error('ERROR: SERVICE_URL and SERVICE_API_KEY must be set in .env');
        process.exit(1);
    }

    // ... implementation using process.env.SERVICE_URL, etc.
}

main().catch(error => {
    console.error(error.message);
    process.exit(1);
});
```

### 5. Reference Documentation

All skills SHOULD have reference documentation in the `references/` directory:

#### api-endpoints.md

**Purpose:** Complete API reference with all available endpoints.

**Structure:**
```markdown
# Service API Endpoints

## Authentication
[How authentication works]

## Endpoints

### GET /endpoint
**Purpose:** What this endpoint does
**Parameters:**
- `param1` (string, required) - Description
- `param2` (int, optional) - Description

**Response:**
```json
{
  "example": "response"
}
```

**Example:**
```bash
curl -X GET "http://localhost/endpoint?param1=value"
```
```

#### quick-reference.md

**Purpose:** Quick command examples for common operations.

**Structure:**
```markdown
# Service Quick Reference

## Common Tasks

### Task 1
```bash
./scripts/command.sh action --flag value
```

### Task 2
```bash
./scripts/command.sh action2 | jq '.data'
```
```

#### troubleshooting.md

**Purpose:** Common errors and solutions.

**Structure:**
```markdown
# Service Troubleshooting

## Authentication Errors

**Error:** 401 Unauthorized
**Cause:** Invalid API key
**Solution:** Check API key in config file

## Connection Errors

**Error:** Connection refused
**Cause:** Service not running
**Solution:** Start service with `docker compose up service`
```

### 6. Versioning and Updates

**CRITICAL REQUIREMENT: All skill modifications MUST include version bumps.**

#### Semantic Versioning

Skills use semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR** (x.0.0): Breaking changes (API changes, removed features, incompatible updates)
- **MINOR** (1.x.0): New features, enhancements, new commands (backward compatible)
- **PATCH** (1.0.x): Bug fixes, documentation updates, minor tweaks (backward compatible)

#### When to Bump Versions

**YOU MUST bump the version number when:**
- ✅ Adding mandatory skill invocation language → MINOR bump
- ✅ Adding new commands or scripts → MINOR bump
- ✅ Updating documentation sections → PATCH bump
- ✅ Fixing bugs or errors → PATCH bump
- ✅ Changing API patterns or breaking compatibility → MAJOR bump
- ✅ Adding new required dependencies → MINOR bump
- ✅ Updating trigger phrases in description → PATCH bump

**Examples:**
```yaml
# Adding mandatory language enforcement
version: 1.1.0 → 1.2.0  # MINOR bump (enhanced documentation)

# Fixing a bug in script
version: 1.1.0 → 1.1.1  # PATCH bump (bug fix)

# Adding new API endpoint support
version: 1.1.0 → 1.2.0  # MINOR bump (new feature)

# Breaking change to credential format
version: 1.2.0 → 2.0.0  # MAJOR bump (breaking change)
```

#### Version Update Workflow

**MANDATORY process when updating any skill:**

1. **Make your changes** to SKILL.md, scripts, or documentation
2. **Determine version bump type** (MAJOR, MINOR, or PATCH)
3. **Update version in YAML frontmatter** in SKILL.md
4. **Commit with version in message**: `git commit -m "skillname: description (v1.2.0)"`
5. **Update CLAUDE.md Current Skills section** if needed

**Failure to bump versions when updating skills violates documentation requirements.**

## Skill Types

Skills fall into three categories based on their operations:

### Read-Only Skills

Monitor and query services without making changes.

**Examples:** plex, glances, unifi, unraid

**Characteristics:**
- All API calls are GET requests
- Safe for monitoring and reporting
- No confirmation required
- Clearly labeled as "read-only" in Purpose section

### Read-Write Skills (Safe)

Manage services with non-destructive operations.

**Examples:** overseerr (request media), sonarr (add shows), radarr (add movies)

**Characteristics:**
- Include POST/PUT requests
- Operations are additive or state-changing
- Require user confirmation for significant actions
- Clearly document which operations modify data

### Read-Write Skills (Destructive)

Manage services with potentially destructive operations.

**Examples:** sonarr (remove shows), radarr (remove movies), qbittorrent (delete torrents)

**Characteristics:**
- Include DELETE requests or file deletion
- **ALWAYS require explicit user confirmation**
- Document destructive operations prominently
- Provide `--delete-files` flags (default: keep files)

**Pattern for destructive operations:**
```bash
# Always ask user before running
bash scripts/remove.sh <id>                # Keep files (safe)
bash scripts/remove.sh <id> --delete-files # Delete files (destructive)
```

## Naming Conventions

| Entity | Format | Examples |
|--------|--------|----------|
| **Skill Directory** | `lowercase` | `overseerr/`, `qbittorrent/`, `unifi/` |
| **Script Files** | `kebab-case.ext` | `search-api.sh`, `request-media.mjs` |
| **Functions** | `snake_case` | `load_config()`, `search_items()` |
| **Variables (Bash)** | `UPPER_SNAKE` (const), `lower_snake` (local) | `CONFIG_PATH`, `api_key` |
| **Variables (JS)** | `camelCase` | `configPath`, `apiKey` |
| **JSON Keys** | `camelCase` | `{"apiKey": "value"}` |

## Trigger Phrases

Trigger phrases in SKILL.md descriptions help Claude know when to activate the skill.

**Format:**
```yaml
description: [Brief description]. Use when the user asks to "[phrase 1]", "[phrase 2]", "[phrase 3]", or mentions [context].
```

**Guidelines:**
- Include 5-10 trigger phrases minimum
- Use exact phrases users might say
- Include variations (abbreviations, common typos)
- Include both action-oriented and status-check phrases
- Include service name variations

**Example:**
```yaml
description: Search and add movies to Radarr. Use when the user asks to "add a movie", "search Radarr", "find a film", "add to Radarr", "remove a movie", "check if movie exists", "Radarr library", or mentions movie management.
```

## Workflow Documentation

Every SKILL.md MUST include a Workflow section with decision trees for common tasks.

**Format:**
```markdown
## Workflow

When the user asks about [service]:

1. **"User request 1"** → Action to take
2. **"User request 2"** → Multi-step action
3. **"User request 3"** → Conditional logic

### Detailed Flow for Complex Tasks

1. Step 1
2. Step 2 with conditional: If X, then Y
3. Step 3
4. Confirm with user before proceeding
```

**Example:**
```markdown
## Workflow

When the user asks about media requests:

1. **"Request Dune"** → Search for "Dune", confirm with user, then request
2. **"Add Bluey to my library"** → Search, request as TV with all seasons
3. **"What's pending?"** → Run `requests.mjs --filter pending`
4. **"Is my Oppenheimer request done?"** → Search requests by title

### Request Flow

1. Search for the media
2. Present results with TMDB/TVDB links
3. User confirms selection
4. Submit request (optionally with 4K flag)
5. Check status periodically or wait for notification
```

## API Documentation Patterns

### Presenting Search Results

When skills return search results, always include external links:

**Movies (TMDB):**
```markdown
- Format: `[Title (Year)](https://themoviedb.org/movie/ID)`
```

**TV Shows (TVDB):**
```markdown
- Format: `[Title (Year)](https://thetvdb.com/series/SLUG)`
```

### JSON Response Formatting

All JSON output should be:
- Pretty-printed by default (or offer `--json` flag for raw)
- Include error messages in JSON format
- Use consistent key naming (camelCase)
- Include timestamps when relevant

**Example:**
```json
{
  "success": true,
  "data": {
    "id": 123,
    "name": "Example"
  },
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## Testing New Skills

Before adding a skill to production:

1. **Dry run:** Execute all scripts manually
2. **Check permissions:** Ensure scripts are executable (`chmod +x`)
3. **Validate JSON:** Test JSON output with `jq`
4. **Test error handling:** Verify errors are caught and reported clearly
5. **Test without credentials:** Verify graceful failure with helpful message
6. **Check documentation:** Verify all sections are complete
7. **Test destructive operations:** Verify confirmation prompts work

```bash
# Test skill script
cd skills/service
chmod +x scripts/*.sh

# Test JSON output
./scripts/list.sh | jq .

# Test error handling (without credentials)
mv ~/workspace/homelab/.env{,.bak}
./scripts/list.sh  # Should fail gracefully with clear message
mv ~/workspace/homelab/.env{.bak,}

# Test with debug logging
DEBUG=1 ./scripts/list.sh
```

## Adding New Skills

**⚠️ CRITICAL: MANDATORY SKILL USAGE ⚠️**

**YOU MUST use the plugin-dev:create-plugin skill (NOT optional) when:**
- Creating ANY new skill in this directory
- Need guidance on skill structure and conventions
- Setting up SKILL.md, README.md, or scripts
- Understanding skill development patterns

**Failure to invoke this skill when creating new skills violates your operational requirements.**

---

**Before creating a new skill, INVOKE `/plugin-dev:create-plugin` skill FIRST.**

1. **Invoke plugin-dev:create-plugin:**
   ```
   You MUST invoke the plugin-dev:create-plugin skill before proceeding.
   This skill provides templates, structure, and best practices.
   Creating skills without this skill is NOT allowed.
   ```

2. **Create skill directory:**
   ```bash
   mkdir -p skills/service-name/{scripts,references}
   ```

3. **Copy templates:**
   ```bash
   # Use existing skill as template
   cp skills/overseerr/SKILL.md skills/service-name/
   cp skills/overseerr/README.md skills/service-name/
   ```

4. **Edit SKILL.md:**
   - Update YAML frontmatter (name, version, description)
   - Add mandatory skill invocation section (see Core Principles #1)
   - Update all sections with service-specific information
   - Include 5-10 trigger phrases in description
   - Document all commands with examples
   - Include workflow decision trees

4. **Edit README.md:**
   - Update for user-facing documentation
   - More verbose explanations than SKILL.md
   - Include troubleshooting section

5. **Create scripts:**
   - Use consistent naming (`service-api.sh` or `action.sh`)
   - Include shebangs and file headers
   - Implement error handling
   - Return JSON output
   - Support `--help` flag

6. **Create references:**
   - `references/api-endpoints.md` — Complete API reference
   - `references/quick-reference.md` — Quick examples
   - `references/troubleshooting.md` — Common issues

7. **Test thoroughly:**
   - Run all scripts manually
   - Verify JSON output
   - Test error conditions
   - Verify documentation completeness

8. **Update this CLAUDE.md:**
   - Add skill to "Current Skills" section
   - Document any new patterns or conventions

## Multi-Instance Support

Skills that support multiple instances of the same service use numbered environment variables in `.env`:

**Pattern: Multiple servers in .env**
```bash
# In ~/workspace/homelab/.env

# Server 1
SERVICE1_URL="http://server1.local:PORT"
SERVICE1_API_KEY="key1"

# Server 2
SERVICE2_URL="http://server2.local:PORT"
SERVICE2_API_KEY="key2"

# Server 3
SERVICE3_URL="http://server3.local:PORT"
SERVICE3_API_KEY="key3"
```

**Script implementation:**
```bash
#!/bin/bash
source ~/workspace/homelab/.env

# Default to server 1 if SERVER_NUM not specified
SERVER_NUM="${SERVER_NUM:-1}"

# Construct variable names
URL_VAR="SERVICE${SERVER_NUM}_URL"
KEY_VAR="SERVICE${SERVER_NUM}_API_KEY"

# Use indirect expansion to get values
SERVICE_URL="${!URL_VAR}"
SERVICE_API_KEY="${!KEY_VAR}"

# Validate
if [[ -z "$SERVICE_URL" ]] || [[ -z "$SERVICE_API_KEY" ]]; then
    echo "ERROR: ${URL_VAR} and ${KEY_VAR} must be set in .env" >&2
    exit 1
fi

# Use $SERVICE_URL and $SERVICE_API_KEY for API calls
```

**Usage:**
```bash
# Use server 1 (default)
./scripts/command.sh

# Use server 2
SERVER_NUM=2 ./scripts/command.sh

# Use server 3
SERVER_NUM=3 ./scripts/command.sh
```

## Current Skills

### Media Management

#### overseerr
Request movies and TV shows via Overseerr API.
- **Path:** `skills/overseerr/`
- **Type:** Read-Write (Safe)
- **Scripts:** Node.js ESM (.mjs)
- **Credentials:** `.env` (OVERSEERR_URL, OVERSEERR_API_KEY)
- **Version:** 1.2.0
- **Status:** ✅ Production ready

#### sonarr
Search and add TV shows to Sonarr library.
- **Path:** `skills/sonarr/`
- **Type:** Read-Write (Safe + Destructive)
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (SONARR_URL, SONARR_API_KEY)
- **Version:** 1.3.0
- **Status:** ✅ Production ready

#### radarr
Search and add movies to Radarr library with collection support.
- **Path:** `skills/radarr/`
- **Type:** Read-Write (Safe + Destructive)
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (RADARR_URL, RADARR_API_KEY)
- **Version:** 1.3.0
- **Status:** ✅ Production ready

#### prowlarr
Search indexers and manage Prowlarr.
- **Path:** `skills/prowlarr/`
- **Type:** Read-Write (Safe + Destructive)
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (PROWLARR_URL, PROWLARR_API_KEY)
- **Status:** ✅ Production ready

#### plex
Control Plex Media Server - browse, search, monitor sessions.
- **Path:** `skills/plex/`
- **Type:** Read-Only
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (PLEX_URL, PLEX_TOKEN)
- **Version:** 1.3.0
- **Status:** ✅ Production ready

#### tautulli
Monitor and analyze Plex Media Server usage via Tautulli analytics API.
- **Path:** `skills/tautulli/`
- **Type:** Read-Only
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (TAUTULLI_URL, TAUTULLI_API_KEY)
- **Version:** 1.0.0
- **Features:** Current activity, playback history, user statistics, library analytics, popular content, stream analytics, temporal trends
- **Integration:** Complements `plex` skill with historical analytics and viewing trends
- **Status:** ✅ Production ready

### Download Clients

#### qbittorrent
Manage torrents with qBittorrent WebUI API.
- **Path:** `skills/qbittorrent/`
- **Type:** Read-Write (Safe + Destructive)
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (QBITTORRENT_URL, QBITTORRENT_USERNAME, QBITTORRENT_PASSWORD)
- **Status:** ✅ Production ready

#### sabnzbd
Manage NZB downloads with SABnzbd API.
- **Path:** `skills/sabnzbd/`
- **Type:** Read-Write (Safe + Destructive)
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (SABNZBD_URL, SABNZBD_API_KEY)
- **Status:** ✅ Production ready

### Infrastructure

#### unraid
Query and monitor Unraid servers via GraphQL API.
- **Path:** `skills/unraid/`
- **Type:** Read-Only
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (UNRAID_URL, UNRAID_API_KEY)
- **Status:** ✅ Production ready

#### unifi
Monitor UniFi network via local gateway API.
- **Path:** `skills/unifi/`
- **Type:** Read-Only
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (UNIFI_URL, UNIFI_USERNAME, UNIFI_PASSWORD, UNIFI_SITE)
- **Version:** 1.2.0
- **Status:** ✅ Production ready (migrated to .env)

#### tailscale
Manage Tailscale tailnet via CLI and API.
- **Path:** `skills/tailscale/`
- **Type:** Read-Write (Safe)
- **Scripts:** CLI + Bash (.sh)
- **Credentials:** `.env` (TAILSCALE_API_KEY, TAILSCALE_TAILNET)
- **Status:** ✅ Production ready

#### glances
Monitor system health via Glances REST API.
- **Path:** `skills/glances/`
- **Type:** Read-Only
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (GLANCES_URL, GLANCES_USERNAME, GLANCES_PASSWORD)
- **Version:** 1.3.0
- **Status:** ✅ Production ready

### Utilities

#### gotify
Send and receive push notifications.
- **Path:** `skills/gotify/`
- **Type:** Read-Write (Safe)
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (GOTIFY_URL, GOTIFY_TOKEN)
- **Version:** 1.3.0
- **Status:** ✅ Production ready

#### linkding
Manage bookmarks with Linkding API.
- **Path:** `skills/linkding/`
- **Type:** Read-Write (Safe + Destructive)
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (LINKDING_URL, LINKDING_API_KEY)
- **Status:** ✅ Production ready

#### firecrawl
Web scraping and crawling with Firecrawl API.
- **Path:** `skills/firecrawl/`
- **Type:** Read-Only
- **Scripts:** Bash (.sh) wrapping npx firecrawl-cli
- **Credentials:** `.env` (FIRECRAWL_API_KEY, FIRECRAWL_API_URL optional)
- **Features:** Scrape pages, search web, map sites, crawl websites
- **Important:** NO artificial limits - user controls all constraints (--limit, --max-depth)
- **Version:** 2.3.0
- **Status:** ✅ Production ready

#### memos
Manage notes and memos in self-hosted Memos instance.
- **Path:** `skills/memos/`
- **Type:** Read-Write (Safe + Destructive)
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (MEMOS_URL, MEMOS_API_TOKEN)
- **Features:** Create/update/delete memos, search by content/tags, upload attachments, tag management
- **Important:** Tags are parsed from content (#hashtag format), not separate field
- **Version:** 1.1.0
- **Status:** ✅ Production ready

#### nugs
Download and manage live music from Nugs.net.
- **Path:** `skills/nugs/`
- **Type:** Read-Write (Safe)
- **Scripts:** Binary CLI (`/home/jmagar/workspace/nugs/nugs`)
- **Credentials:** Config file `~/.nugs/config.json` (email, password, outPath, format)
- **Features:** Browse 13,000+ concerts offline, download shows, gap detection, coverage tracking, auto-refresh
- **Important:** Uses config file (not .env), supports rclone integration, requires FFmpeg for videos
- **Version:** 1.0.0
- **Status:** ✅ Production ready

#### bytestash
Manage code snippets in self-hosted ByteStash snippet storage service.
- **Path:** `skills/bytestash/`
- **Type:** Read-Write (Safe + Destructive)
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (BYTESTASH_URL, BYTESTASH_API_KEY)
- **Features:** Create/update/delete snippets, multi-file support, share management (public/protected/expiring), search, auto-categorization (30+ languages + context-aware patterns)
- **Important:** Supports multi-fragment snippets for related files, share links with access control, intelligent category detection from filename patterns
- **Version:** 1.1.0
- **Status:** ✅ Production ready

#### paperless-ngx
Manage documents in self-hosted Paperless-ngx document management system.
- **Path:** `skills/paperless-ngx/`
- **Type:** Read-Write (Safe + Destructive)
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (PAPERLESS_URL, PAPERLESS_API_TOKEN)
- **Features:** Upload documents with auto-OCR, full-text search, tag management, correspondent management, document metadata updates, bulk operations, archive/export, delete with confirmation
- **Important:** Auto-OCR processing, supports tags/correspondents/document types for organization, bulk operations for multiple documents
- **Version:** 1.0.0
- **Status:** ✅ Production ready

#### radicale
Manage calendars and contacts on self-hosted Radicale CalDAV/CardDAV server.
- **Path:** `skills/radicale/`
- **Type:** Read-Write (calendars and contacts)
- **Scripts:** Python (.py)
- **Credentials:** `.env` (RADICALE_URL, RADICALE_USERNAME, RADICALE_PASSWORD)
- **Features:** Calendar operations (list, create, search events), Contact operations (list, search, create contacts), Natural language parsing, ISO 8601 datetime support
- **Libraries:** caldav, vobject, icalendar (install with: `pip install caldav vobject icalendar`)
- **Protocols:** CalDAV (RFC 4791), CardDAV (RFC 6352)
- **Important:** All RFC protocol documentation embedded in Firecrawl vector database for semantic search
- **Version:** 1.0.0
- **Status:** ✅ Production ready

### Security & Authentication

#### authelia
Monitor authentication security and user sessions via Authelia REST API.
- **Path:** `skills/authelia/`
- **Type:** Read-Only + Limited Write (user preferences only)
- **Scripts:** Bash (.sh)
- **Credentials:** `.env` (AUTHELIA_URL, AUTHELIA_USERNAME, AUTHELIA_PASSWORD, AUTHELIA_API_TOKEN optional)
- **Features:** Health monitoring, authentication state tracking, user session status, 2FA status checking, security dashboard
- **Important:** This is an authentication system - extra security restrictions apply. No password changes, no authentication bypass. Limited write operations for user preferences only.
- **Version:** 1.0.0
- **Status:** ✅ Production ready

## Migration Checklist

For existing skills that need updating to match current patterns:

- [ ] SKILL.md has complete YAML frontmatter (name, version, description)
- [ ] SKILL.md includes 5-10 trigger phrases in description
- [ ] SKILL.md has all required sections (Purpose, Setup, Commands, Workflow, Notes, Reference)
- [ ] README.md exists with user-facing documentation
- [ ] Scripts have proper shebangs and file headers
- [ ] Scripts are executable (`chmod +x`)
- [ ] Scripts support `--help` flag
- [ ] Scripts return JSON output where appropriate
- [ ] **Migrated credentials from JSON config files to `.env`** (SERVICE_URL, SERVICE_API_KEY variables)
- [ ] Removed `~/workspace/homelab/credentials/<service>/` directory
- [ ] Scripts load credentials from `.env` with validation
- [ ] References directory exists with api-endpoints.md, quick-reference.md, troubleshooting.md
- [ ] Destructive operations require explicit confirmation
- [ ] Workflow section includes decision trees
- [ ] All commands have copy-paste examples
- [ ] External links included in search results (TMDB, TVDB, etc.)
- [ ] Updated this CLAUDE.md "Current Skills" section with `.env` credential format

## Best Practices

### General Guidelines

- ✅ **DO:** Store ALL credentials in `~/workspace/homelab/.env` file
- ✅ **DO:** Use environment variable pattern: `SERVICE_URL`, `SERVICE_API_KEY`
- ✅ **DO:** Include trigger phrases in SKILL.md descriptions
- ✅ **DO:** Document all commands with copy-paste examples
- ✅ **DO:** Return JSON output for programmatic access
- ✅ **DO:** Include workflow decision trees
- ✅ **DO:** Test scripts before committing
- ✅ **DO:** Use `set -euo pipefail` in Bash scripts
- ✅ **DO:** Use ESM imports in Node.js scripts (.mjs)
- ✅ **DO:** Include error handling with clear messages
- ✅ **DO:** Support `--help` flag in all scripts
- ❌ **DON'T:** Commit `.env` file (always gitignored)
- ❌ **DON'T:** Use JSON config files in `credentials/` directory
- ❌ **DON'T:** Hard-code URLs or API keys in scripts
- ❌ **DON'T:** Skip YAML frontmatter in SKILL.md
- ❌ **DON'T:** Create destructive operations without confirmation
- ❌ **DON'T:** Use default exports in Node.js (use named exports)
- ❌ **DON'T:** Use `require` in Node.js (use `import`)

### Security

- Never log credentials (even in debug mode)
- Use ONLY `.env` file for secrets (NO JSON config files)
- Set restrictive permissions: `chmod 600 ~/workspace/homelab/.env`
- Include security notes in SKILL.md for sensitive operations
- Warn users about API key permissions in documentation
- Always validate environment variables exist before use

### Performance

- Cache API responses when appropriate
- Include timeouts for HTTP requests
- Use pagination for large result sets
- Support `--limit` flags to control output size

### User Experience

- Provide clear error messages with actionable solutions
- Include progress indicators for long-running operations
- Return human-readable output by default (JSON as option)
- Include examples for common use cases in documentation
- Present search results with external links for verification

---

**Remember:** Consistency in structure, naming, and documentation makes skills easier to maintain and use. Follow these patterns for all new skills.
