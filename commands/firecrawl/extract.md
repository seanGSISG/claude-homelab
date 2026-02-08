---
description: Extract structured data from URLs using prompts or schemas
argument-hint: <url> --prompt "what to extract" [options]
allowed-tools: Bash(firecrawl:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Extract structured data using the Firecrawl CLI:

$ARGUMENTS

## Instructions

Run `firecrawl extract` with the provided URL and extraction options. Use zsh-tool with `pty: true` for visible output.

**Common options:**
- `--prompt "<prompt>"` - Natural language extraction prompt (required unless --schema)
- `--schema '<json>'` - JSON schema defining expected output structure
- `--system-prompt "<prompt>"` - System prompt for extraction model
- `--enable-web-search` - Allow web search for additional context
- `--show-sources` - Show source URLs used for extraction
- `--no-embed` - Skip vector database embedding
- `-o <path>` - Save results to file

**Usage patterns:**

```bash
# Natural language extraction
firecrawl extract https://example.com --prompt "Extract product names and prices"

# Schema-based extraction
firecrawl extract https://example.com --schema '{"type":"object","properties":{"title":{"type":"string"},"price":{"type":"number"}}}'

# With web search and sources
firecrawl extract https://example.com --prompt "Find contact info" --enable-web-search --show-sources
```

Present extracted data in a clear, structured format.

For detailed parameters, see `skills/firecrawl/references/parameters.md`.
