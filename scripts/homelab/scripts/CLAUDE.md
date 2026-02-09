# Scripts Directory - Development Guidelines

**⚠️ CRITICAL: MANDATORY SKILL USAGE ⚠️**

**YOU MUST use the shell-scripting:bash-pro skill (NOT optional) when:**
- Creating ANY new bash script in this directory
- Modifying existing bash scripts with significant changes
- Implementing error handling or defensive patterns
- Need bash best practices guidance

**YOU MUST use the shell-scripting:bash-defensive-patterns skill when:**
- Implementing error handling patterns
- Adding input validation
- Creating safety mechanisms

**Failure to invoke these skills when creating or significantly modifying bash scripts violates your operational requirements.**

---

This directory contains utility scripts for homelab maintenance, validation, and automation. Scripts support the infrastructure for monitoring dashboards, skill management, and API documentation.

## Directory Purpose

Utility scripts that don't fit dashboard/inventory/monitor/report categories but are essential for:
- Environment validation and testing
- API documentation generation
- Skill system utilities
- Development and maintenance tasks

## Core Principles

### 1. Script Categories

Scripts are organized by function:

| Category | Purpose | Examples |
|----------|---------|----------|
| **Validation** | Test system state, credentials, documentation | `verify-env-migration.sh`, `validate-api-docs.sh` |
| **Data Acquisition** | Fetch external resources | `download-openapi-specs.sh` |
| **Generation** | Create artifacts from sources | `generate-api-docs.py` |
| **Utilities** | Helper tools and wrappers | `skill-wrapper.sh` |

### 2. Naming Conventions

**Format:** `<verb>-<noun>.<ext>`

| Pattern | Example | Purpose |
|---------|---------|---------|
| `verify-*` | `verify-env-migration.sh` | Validation scripts |
| `validate-*` | `validate-api-docs.sh` | Quality assurance |
| `download-*` | `download-openapi-specs.sh` | Remote data fetching |
| `generate-*` | `generate-api-docs.py` | Content generation |
| `*-wrapper` | `skill-wrapper.sh` | Wrapper utilities |

**Requirements:**
- All lowercase with hyphens
- Verb-first (action-oriented)
- Descriptive of actual function
- Extension indicates language (`.sh`, `.py`)

### 3. Script Structure

#### Bash Scripts

**Standard header:**
```bash
#!/bin/bash
# Brief description of purpose
# Additional context if needed
# Usage: ./script-name.sh [args] (if applicable)

set -euo pipefail

# === Configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source shared libraries if needed
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/load-env.sh"
```

#### Python Scripts

**Standard header:**
```python
#!/usr/bin/env python3
"""
Brief description of purpose

Usage:
    python3 script-name.py <arg1> <arg2>

Example:
    python3 script-name.py input.yml OutputName
"""

import sys
from typing import Dict, List, Any  # Full type hints
```

### 4. Error Handling Standards

**MANDATORY patterns:**

```bash
# Strict mode (all Bash scripts)
set -euo pipefail

# Early validation
if [ $# -lt 1 ]; then
    echo "Usage: $0 <required-arg>"
    exit 1
fi

# File existence checks
if [[ ! -f "$FILE_PATH" ]]; then
    echo "Error: File not found: $FILE_PATH"
    exit 1
fi

# Command failure handling
if ! result=$(command 2>&1); then
    echo "Error: Command failed: $result"
    exit 1
fi

# Graceful degradation for optional operations
if [[ -n "${OPTIONAL_VAR:-}" ]]; then
    # Process optional feature
else
    echo "⚠️  Optional feature skipped"
fi
```

**Python error handling:**
```python
try:
    with open(file_path) as f:
        data = json.load(f)
except FileNotFoundError:
    print(f"Error: File not found: {file_path}", file=sys.stderr)
    sys.exit(1)
except json.JSONDecodeError as e:
    print(f"Error parsing JSON: {e}", file=sys.stderr)
    sys.exit(1)
```

### 5. Output Standards

**Status indicators (use emojis):**
- ✅ Success/OK
- ❌ Error/failure
- ⚠️ Warning/partial failure
- → Progress/step indicators

**Output destinations:**
- Progress messages → stdout
- Errors/warnings → stderr
- JSON data → files (not stdout for scripts)
- Log entries → stderr + log files

**Example:**
```bash
echo "✅ Service validated successfully"
echo "⚠️  Optional check skipped" >&2
echo "❌ Validation failed" >&2
```

### 6. Exit Codes

**Standard meanings:**
- `0` - Success
- `1` - General error
- `$count` - Number of failures (for validation scripts)

**Examples:**
```bash
# Binary success/fail
exit 0  # Success
exit 1  # Failure

# Validation with counts
exit $fail_count  # Semantic: number of failed validations
```

### 7. Variable Naming

**Bash:**
- `UPPERCASE_SNAKE_CASE` for constants and configuration
- `lowercase_snake_case` for local variables
- Always quote: `"$var"` not `$var`

**Python:**
- `UPPERCASE_SNAKE_CASE` for module constants
- `lowercase_snake_case` for functions/variables
- `PascalCase` for classes
- Full type hints on all functions

### 8. Dependencies

**System binaries commonly used:**
- `bash` 3.0+ (all shell scripts)
- `curl` (HTTP requests)
- `jq` (JSON processing)
- `python3` 3.8+ (Python scripts)
- `grep`, `wc`, `awk` (text processing)

**Python libraries:**
- `yaml` (PyYAML for YAML parsing)
- `json` (stdlib)
- `pathlib` (modern path handling)
- `typing` (type hints)

**Dependency checking:**
```bash
# Optional tool check
if command -v tool &>/dev/null; then
    # Use tool
else
    echo "⚠️  Tool not available, skipping"
fi

# Required tool check
for cmd in curl jq python3; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required command not found: $cmd"
        exit 1
    fi
done
```

### 9. Credential Management and Security

**CRITICAL: All credentials MUST be stored in `.env` file with proper permissions.**

**Required `.env` file location:**
```bash
~/workspace/homelab/.env
```

**MANDATORY security requirements:**

1. **File permissions MUST be restrictive:**
   ```bash
   chmod 600 ~/workspace/homelab/.env
   # Only owner can read/write, no group or world access
   ```

2. **NEVER commit `.env` file:**
   - `.env` is gitignored by default
   - Verify: `git check-ignore ~/workspace/homelab/.env` (should output path)
   - If not ignored, add to `.gitignore` immediately

3. **NEVER log credentials:**
   - Don't echo/print environment variables containing secrets
   - Sanitize logs to remove API keys, tokens, passwords
   - Even in DEBUG mode, mask sensitive values

4. **Environment variable naming convention:**
   ```bash
   # Format: SERVICE_CREDENTIAL_TYPE
   SERVICE_URL="http://localhost:PORT"
   SERVICE_API_KEY="your-api-key"
   SERVICE_USERNAME="username"
   SERVICE_PASSWORD="password"

   # Multi-instance (numbered)
   SERVICE1_URL="http://server1:PORT"
   SERVICE1_API_KEY="key1"
   SERVICE2_URL="http://server2:PORT"
   SERVICE2_API_KEY="key2"
   ```

5. **Loading credentials in scripts:**
   ```bash
   # Source .env file
   if [[ -f ~/workspace/homelab/.env ]]; then
       source ~/workspace/homelab/.env
   else
       echo "ERROR: .env file not found at ~/workspace/homelab/.env" >&2
       exit 1
   fi

   # Validate required variables exist
   if [[ -z "${SERVICE_URL:-}" ]] || [[ -z "${SERVICE_API_KEY:-}" ]]; then
       echo "ERROR: SERVICE_URL and SERVICE_API_KEY must be set in .env" >&2
       exit 1
   fi
   ```

6. **Security checklist for all scripts:**
   - ✅ Credentials loaded from `.env` only (never hardcoded)
   - ✅ `.env` permissions are `600` (owner read/write only)
   - ✅ `.env` file is in `.gitignore`
   - ✅ No credentials in logs (even debug logs)
   - ✅ No credentials in script output
   - ✅ No credentials in error messages
   - ✅ Validate credentials exist before use

**Credential rotation workflow:**
```bash
# 1. Edit .env file
vim ~/workspace/homelab/.env

# 2. Verify permissions
chmod 600 ~/workspace/homelab/.env

# 3. Test all services load credentials
./scripts/verify-env-migration.sh

# 4. Check no credentials in git
git status  # .env should NOT appear

# 5. If .env appears in git status:
echo ".env" >> .gitignore
git rm --cached .env 2>/dev/null || true
```

## Current Scripts

### Validation Scripts

#### verify-env-migration.sh
**Purpose:** Validate all services can load credentials from `.env` file

**What it does:**
- Tests 13 services (Unifi, Linkding, Radarr, Sonarr, Prowlarr, Overseerr, SABnzbd, qBittorrent, Gotify, Glances, Tailscale, Unraid servers)
- Validates each service's required environment variables
- Reports pass/fail counts
- Exits with failure count as exit code

**Usage:**
```bash
./scripts/verify-env-migration.sh
```

**Libraries:**
- `lib/load-env.sh` - Credential loading
- `lib/logging.sh` - Structured logging

**Exit codes:**
- `0` - All services passed
- `$count` - Number of failed services

#### validate-api-docs.sh
**Purpose:** Check API documentation completeness and quality

**What it does:**
- Validates required files exist (`api-endpoints.md`)
- Checks for required sections (Authentication, Base URL, Quick Start, Endpoints)
- Verifies bash code blocks present (curl examples)
- Validates file size (warns if < 50 lines)
- Tier-specific checks (quick-reference.md, troubleshooting.md)
- Optional markdownlint integration

**Usage:**
```bash
./scripts/validate-api-docs.sh
```

**Services validated:** overseerr, sonarr, radarr, prowlarr, qbittorrent, plex, glances, gotify, tailscale, sabnzbd

**Exit codes:**
- `0` - All documentation valid (or warnings only)
- `1` - Errors found

### Data Acquisition Scripts

#### download-openapi-specs.sh
**Purpose:** Download OpenAPI/Swagger specifications for services

**What it does:**
- Downloads public specs from GitHub (Overseerr, Gotify)
- Downloads local specs from running instances (Sonarr, Radarr, Prowlarr)
- Creates `references/` directories if missing
- Gracefully handles missing API keys or unavailable services

**Usage:**
```bash
./scripts/download-openapi-specs.sh

# With API keys for local instances
SONARR_API_KEY="xxx" RADARR_API_KEY="xxx" ./scripts/download-openapi-specs.sh
```

**Output:**
- Files written to: `skills/*/references/*.{yml,json}`

**Dependencies:**
- `curl` - HTTP requests
- Environment variables (optional): `SONARR_API_KEY`, `RADARR_API_KEY`, `PROWLARR_API_KEY`

**Exit codes:**
- `0` - Always (reports status for each service)

### Generation Scripts

#### generate-api-docs.py
**Purpose:** Parse OpenAPI specs and generate markdown documentation

**What it does:**
- Parses YAML or JSON OpenAPI specifications
- Groups endpoints by OpenAPI tags
- Generates parameter tables
- Creates working curl examples with parameter substitution
- Outputs formatted markdown documentation

**Usage:**
```bash
python3 scripts/generate-api-docs.py <spec-file> <service-name>

# Example
python3 scripts/generate-api-docs.py \
  skills/overseerr/references/overseerr-api.yml \
  Overseerr
```

**Output:**
- File written to: `skills/<service>/references/api-endpoints.md`

**Output sections:**
1. Authentication details
2. Base URL and version
3. Quick start example
4. Endpoints by category
5. Version history
6. Additional resources

**Dependencies:**
- Python 3.8+
- `PyYAML` library (`pip install pyyaml`)

**Exit codes:**
- `0` - Success
- `1` - File not found, parse error, or write error

### Utility Scripts

#### skill-wrapper.sh
**Purpose:** Universal wrapper guaranteeing output visibility

**What it does:**
- Executes script and captures all output (stdout + stderr)
- Explicitly prints captured output
- Solves issue where zsh-tool may silently drop output

**Usage:**
```bash
./scripts/skill-wrapper.sh <path-to-script> [script-args...]

# Example
./scripts/skill-wrapper.sh skills/overseerr/scripts/search.mjs "dune"
```

**Exit codes:**
- Inherits from wrapped script

**When to use:**
- When executing skill scripts via MCP/zsh-tool
- When output visibility is critical
- As intermediary wrapper for skill invocation

## Script Workflow Patterns

### API Documentation Pipeline

**Complete workflow for adding API documentation:**

```bash
# 1. Download OpenAPI spec
./scripts/download-openapi-specs.sh
# Output: skills/service/references/service-api.{yml,json}

# 2. Generate markdown documentation
python3 scripts/generate-api-docs.py \
  skills/service/references/service-api.yml \
  ServiceName
# Output: skills/service/references/api-endpoints.md

# 3. Validate documentation completeness
./scripts/validate-api-docs.sh
# Checks: Required sections, examples, file size
```

### Environment Validation Workflow

**Before deploying or updating credentials:**

```bash
# 1. Update .env file with new credentials
vim ~/.env

# 2. Verify all services can load credentials
./scripts/verify-env-migration.sh

# 3. Check for specific service
# (inspect output for specific service status)
```

## Integration with Other Systems

### Library Usage

Scripts in this directory typically:
- **Source libraries** from `lib/` for shared functionality
- **Don't produce JSON state files** (unlike dashboard/monitor scripts)
- **Run on-demand** (not via cron)
- **Validate or generate** rather than monitor

**Library sourcing pattern:**
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/lib/logging.sh"
source "$REPO_ROOT/lib/load-env.sh"
```

### Skill System Integration

Scripts support the skill system:
- `download-openapi-specs.sh` - Fetches specs for skills
- `generate-api-docs.py` - Creates API documentation
- `validate-api-docs.sh` - Ensures documentation quality
- `skill-wrapper.sh` - Wraps skill execution for output visibility

**Output locations:**
- `skills/*/references/` - API specifications and documentation
- `skills/*/scripts/` - Executable skill scripts

## Development Guidelines

### Adding New Utility Scripts

**⚠️ MANDATORY: Before writing any bash script, you MUST invoke `/shell-scripting:bash-pro` skill**

1. **Choose appropriate category:**
   - Validation: Tests system state
   - Data acquisition: Fetches external resources
   - Generation: Creates artifacts from sources
   - Utilities: Helper tools

2. **Follow naming convention:**
   - Verb-first: `verify-`, `validate-`, `download-`, `generate-`
   - Descriptive noun: What it operates on
   - Example: `validate-docker-configs.sh`

3. **INVOKE bash-pro skill FIRST:**
   ```
   Before writing bash script code, you MUST:
   - Invoke shell-scripting:bash-pro skill
   - Follow all patterns and best practices from the skill
   - Use defensive patterns from shell-scripting:bash-defensive-patterns
   - This is NOT optional
   ```

4. **Use standard structure:**
   - Copy header from existing script
   - Include `set -euo pipefail` for Bash
   - Add usage message if arguments required
   - Source libraries only if needed

4. **Implement error handling:**
   - Exit early on missing arguments
   - Validate file existence before use
   - Use emoji for status indicators
   - Return semantic exit codes

5. **Document in README.md:**
   - Add to appropriate category
   - Describe purpose and usage
   - List dependencies
   - Show example invocations

6. **Update this CLAUDE.md:**
   - Add to "Current Scripts" section
   - Document integration patterns
   - Note any special requirements

### Code Quality Standards

**Required for all scripts:**
- ✅ Strict mode (`set -euo pipefail` for Bash)
- ✅ Error handling for all external commands
- ✅ Input validation (arguments, files, environment)
- ✅ Quoted variables everywhere
- ✅ Exit codes (0 = success, 1+ = error)
- ✅ Status indicators (✅, ❌, ⚠️)
- ✅ Comments explaining "why" not "what"

**Python-specific:**
- ✅ Type hints on all functions
- ✅ Docstrings for modules
- ✅ Exception handling with specific types
- ✅ Context managers for file I/O

**Bash-specific:**
- ✅ No external commands for simple operations
- ✅ Prefer `[[ ]]` over `[ ]`
- ✅ Use `$(command)` not backticks
- ✅ Local variables in functions

### Testing Scripts

**Before committing:**

1. **Test with valid input:**
   ```bash
   ./script.sh valid-arg
   echo $?  # Check exit code
   ```

2. **Test with invalid input:**
   ```bash
   ./script.sh
   ./script.sh nonexistent-file
   ```

3. **Test error conditions:**
   ```bash
   # Missing dependencies
   PATH=/usr/bin ./script.sh

   # Missing environment variables
   unset REQUIRED_VAR
   ./script.sh
   ```

4. **Verify output:**
   - Check stdout contains expected output
   - Check stderr for errors/warnings
   - Verify files created in expected locations
   - Confirm exit codes are correct

### Common Pitfalls

**Avoid these mistakes:**

❌ **Not using strict mode**
```bash
# Bad
#!/bin/bash
# Missing: set -euo pipefail
```

❌ **Unquoted variables**
```bash
# Bad
if [ -f $FILE ]; then  # Word splitting issue
    echo $FILE  # Word splitting issue
fi
```

❌ **Missing input validation**
```bash
# Bad
REQUIRED_ARG="$1"  # No check if $1 exists
```

❌ **Silent failures**
```bash
# Bad
command_that_might_fail  # No error handling
```

❌ **Wrong exit codes**
```bash
# Bad
exit 0  # Always success, even on errors
```

✅ **Correct patterns:**
```bash
#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <arg>"
    exit 1
fi

REQUIRED_ARG="$1"

if [[ ! -f "$REQUIRED_ARG" ]]; then
    echo "Error: File not found: $REQUIRED_ARG"
    exit 1
fi

if ! result=$(command 2>&1); then
    echo "Error: $result"
    exit 1
fi

exit 0
```

## Best Practices Summary

| Aspect | Pattern | Example |
|--------|---------|---------|
| **Script naming** | `<verb>-<noun>.<ext>` | `validate-api-docs.sh` |
| **Strict mode** | `set -euo pipefail` | All Bash scripts |
| **Variables** | `UPPER_CONST`, `lower_local` | `REPO_ROOT`, `fail_count` |
| **Quoting** | Always quote variables | `"$var"` not `$var` |
| **Status** | Use emoji indicators | `✅`, `❌`, `⚠️` |
| **Exit codes** | `0` success, `1+` error | `exit $fail_count` |
| **Error handling** | Check all commands | `if ! cmd; then exit 1; fi` |
| **Dependencies** | Check before use | `command -v tool &>/dev/null` |
| **Input validation** | Validate all arguments | `if [ $# -lt 1 ]; then` |
| **Comments** | Explain "why" not "what" | `# Skip if API key not set` |
| **Python typing** | Full type hints | `def func() -> Dict[str, Any]:` |

---

**Remember:** Scripts in this directory are utility tools for development and maintenance. They should be:
- **Defensive** - Validate all inputs and handle errors
- **Clear** - Use emoji and descriptive messages
- **Documented** - Include usage and examples
- **Tested** - Verify with valid and invalid inputs

For monitoring and data collection scripts, see the dashboard/, inventory/, monitor/, and report/ directories instead.
