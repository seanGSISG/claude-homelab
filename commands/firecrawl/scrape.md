---
description: Scrape a single URL for LLM-ready content
argument-hint: <url> [options]
allowed-tools: Bash(firecrawl:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Scrape the following URL using the Firecrawl CLI:

$ARGUMENTS

## Instructions

Run `firecrawl scrape` with the provided URL and any options. Use zsh-tool with `pty: true` for visible output.

**Common options** (only add if user specifies):
- `--format markdown|html|links` - Output format (default: markdown)
- `--only-main-content` - Strip nav/footer/sidebar
- `--wait-for <ms>` - Wait for JS rendering
- `--screenshot` - Capture page screenshot
- `--no-embed` - Skip vector database embedding
- `-o <path>` - Save output to file

**CRITICAL:** Do NOT add `--limit`, `--max-depth`, or other constraints unless the user explicitly requests them.

**Auto-embedding:** Content is automatically embedded into Qdrant unless `--no-embed` is specified.

Present the scraped content clearly. If multiple formats are returned, show each format section.

For detailed parameters, see `skills/firecrawl/references/parameters.md`.
