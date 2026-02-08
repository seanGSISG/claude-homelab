---
description: Discover all URLs on a website without scraping content
argument-hint: <url> [options]
allowed-tools: Bash(firecrawl:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Map URLs on the following website using the Firecrawl CLI:

$ARGUMENTS

## Instructions

Run `firecrawl map` with the provided URL and options. Use zsh-tool with `pty: true` for visible output.

**Default behavior:** Applies 143 built-in exclude patterns (language routes, blog paths, WordPress admin, login/logout, etc.)

**Common options** (only add if user specifies):
- `--limit <n>` - Maximum URLs to discover
- `--search "<query>"` - Filter URLs by search term
- `--include-subdomains` - Include subdomain URLs
- `--sitemap` - Use sitemap.xml for discovery
- `--exclude-paths <paths>` - Add custom exclude patterns (merged with defaults)
- `--exclude-extensions <exts>` - Filter file types (e.g., `.pdf`, `.zip`)
- `--no-default-excludes` - Skip default patterns, only use custom excludes
- `--no-filtering` - Disable ALL filtering (defaults + custom)
- `--verbose` - Show excluded URLs and which patterns matched
- `--json` - Output as JSON array
- `-o <path>` - Save results to file

**CRITICAL:** Do NOT add `--limit` or other constraints unless the user explicitly requests them.

**Tip:** Use `--verbose` to see which URLs were filtered and why. Use `--no-filtering` when you need complete results.

Present discovered URLs clearly. Summarize the URL structure if there are many results.

For detailed parameters, see `skills/firecrawl/references/parameters.md`.
