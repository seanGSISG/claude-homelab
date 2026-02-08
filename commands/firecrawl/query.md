---
description: Semantic search over embedded content in Qdrant
argument-hint: "<search query>" [--limit N] [--domain example.com]
allowed-tools: Bash(firecrawl:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Search embedded content using the Firecrawl CLI:

$ARGUMENTS

## Instructions

Run `firecrawl query` with the provided search query and options. Use zsh-tool with `pty: true` for visible output.

**Common options:**
- `--limit <n>` - Number of results (default: 5)
- `--domain <domain>` - Filter by source domain
- `--full` - Show full document content (not just snippets)
- `--group` - Group results by source URL
- `--collection <name>` - Search specific Qdrant collection

**Usage patterns:**

```bash
# Basic semantic search
firecrawl query "How do I configure authentication?"

# Domain-filtered search
firecrawl query "API rate limits" --domain docs.example.com

# Full content with more results
firecrawl query "deployment steps" --limit 10 --full

# Grouped by source
firecrawl query "error handling" --group
```

**Prerequisite:** Content must be embedded first via `firecrawl scrape`, `crawl`, or `embed` commands.

Present results with source URLs, relevance scores, and content snippets.

For detailed RAG docs, see `skills/firecrawl/references/vector-database.md`.
