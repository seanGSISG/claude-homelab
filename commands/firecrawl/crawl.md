---
description: Crawl entire website with depth and path controls
argument-hint: <url> [--limit N] [--max-depth N]
allowed-tools: Bash(firecrawl:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Crawl the following website using the Firecrawl CLI:

$ARGUMENTS

## Instructions

Run `firecrawl crawl` with the provided URL and options. Always include `--wait --progress` for real-time tracking. Use zsh-tool with `pty: true` for visible output.

**Common options** (only add if user specifies):
- `--limit <n>` - Maximum pages to crawl
- `--max-depth <n>` - Maximum link depth
- `--include-paths <paths>` - Only crawl matching paths (comma-separated)
- `--exclude-paths <paths>` - Skip matching paths (comma-separated)
- `--delay <ms>` - Delay between requests
- `--no-embed` - Skip vector database embedding
- `-o <path>` - Save results to file

**CRITICAL:** Do NOT add `--limit`, `--max-depth`, or other constraints unless the user explicitly requests them. Let the crawl run unlimited by default.

**Auto-embedding:** All crawled pages are automatically embedded into Qdrant unless `--no-embed` is specified.

Monitor progress and report results (pages crawled, errors, timing).

For detailed parameters, see `skills/firecrawl/references/parameters.md`.
