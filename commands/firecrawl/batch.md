---
description: Batch scrape multiple URLs with job management
argument-hint: <url1> <url2> ... [options] | status <job-id> | cancel <job-id> | errors <job-id>
allowed-tools: Bash(firecrawl:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Perform batch operations using the Firecrawl CLI:

$ARGUMENTS

## Instructions

Use zsh-tool with `pty: true` for visible output.

**Batch subcommands:**

1. **Start batch scrape:** `firecrawl batch <url1> <url2> ... [options]`
   - `--no-embed` - Skip vector database embedding
   - `-o <path>` - Save results to file

2. **Check batch status:** `firecrawl batch status <job-id>`

3. **Cancel batch job:** `firecrawl batch cancel <job-id>`

4. **View batch errors:** `firecrawl batch errors <job-id>`

**CRITICAL:** Do NOT add constraints unless the user explicitly requests them.

**Auto-embedding:** All batch results are automatically embedded into Qdrant unless `--no-embed` is specified.

If the user provides multiple URLs without a subcommand, start a batch scrape. If they provide a job ID, check its status.

For detailed job management docs, see `skills/firecrawl/references/job-management.md`.
