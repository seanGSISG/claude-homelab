---
description: Retrieve full document from vector database by URL
argument-hint: <url> [--collection name]
allowed-tools: Bash(firecrawl:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Retrieve a full document from the vector database using the Firecrawl CLI:

$ARGUMENTS

## Instructions

Run `firecrawl retrieve` with the provided URL. Use zsh-tool with `pty: true` for visible output.

**Common options:**
- `--collection <name>` - Retrieve from specific Qdrant collection
- `-o <path>` - Save retrieved document to file

**How it works:** Reconstructs the full document by fetching and reassembling all embedded chunks for the given URL from Qdrant.

**Usage patterns:**

```bash
# Retrieve full document
firecrawl retrieve https://docs.example.com/guide

# Save to file
firecrawl retrieve https://docs.example.com/guide -o guide.md

# From specific collection
firecrawl retrieve https://docs.example.com/guide --collection my-docs
```

**Prerequisite:** The URL must have been previously embedded via `firecrawl scrape`, `crawl`, or `embed`.

Present the full reconstructed document content.

For detailed RAG docs, see `skills/firecrawl/references/vector-database.md`.
