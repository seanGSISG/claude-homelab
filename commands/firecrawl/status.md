---
description: Check status of Firecrawl jobs (crawls, batches, extracts)
argument-hint:
allowed-tools: mcp__plugin_zsh-tool_zsh-tool__zsh
---

Check the status of all Firecrawl jobs.

## Instructions

Run `firecrawl status` to display:
- **Running crawls** (◉) - Currently in progress
- **Completed crawls** (✓) - Finished successfully
- **Failed crawls** - Errors encountered
- **Pending crawls** - Queued but not started
- **Batch jobs** - Multi-URL batch scraping
- **Extract jobs** - Structured data extraction
- **Embeddings** - Vector database embedding status

Use zsh-tool with `pty: true` to preserve colored output and formatting.

The output shows:
- Job IDs (for use with other commands)
- URLs being processed
- Progress bars and completion percentages
- Total pages crawled/scraped

**To check a specific job:**
Use the job ID with `/firecrawl:crawl-status <job-id>` or check logs.
