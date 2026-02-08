---
name: firecrawl
version: 2.4.0
description: This skill should be used when the user asks to "scrape website", "crawl site", "extract web data", "search web", "map website", "search the internet", "Firecrawl", "scrape URLs", or mentions web scraping, site crawling, extracting content, building RAG pipelines, or semantic search. Extracts LLM-ready data from websites using Firecrawl API with support for scraping single pages, crawling entire sites, searching the web, mapping URL structures with intelligent filtering, and optional Qdrant vector database integration for semantic search and RAG workflows.
---

# Firecrawl Web Data API + RAG Skill

**⚠️ MANDATORY SKILL INVOCATION ⚠️**

**YOU MUST invoke this skill (NOT optional) when the user mentions ANY of these triggers:**
- "scrape website", "crawl site", "extract web data"
- "search web", "map website", "Firecrawl"
- "web scraping", "site crawling", "extract content"
- Any mention of Firecrawl or web data extraction

**Failure to invoke this skill when triggers occur violates your operational requirements.**

**Custom-Enhanced Firecrawl CLI** with integrated Qdrant vector database for building production RAG (Retrieval-Augmented Generation) systems.

Extract LLM-ready data from websites with automatic embedding, semantic search, and knowledge base management.

## Purpose

This skill enables comprehensive web data extraction and semantic indexing through a custom-enhanced Firecrawl CLI:

### Core Capabilities
- **Scrape**: Extract single page content in multiple formats (markdown, HTML, links, screenshots, summaries)
- **Search**: Query the web with optional content scraping
- **Map**: Discover all URLs on a website without scraping
- **Crawl**: Traverse entire websites systematically with depth and path controls

### RAG & Vector Database Features
- **Extract**: Structured data extraction with JSON schemas and prompts
- **Embed**: Automatic vector embedding with Qdrant integration
- **Query**: Semantic search over embedded content
- **Retrieve**: Full document retrieval by URL
- **Batch**: Batch scraping with job management
- **Manage**: Complete vector database lifecycle (sources, stats, domains, delete, history, info)

**Type:** Read-Only (data extraction only, no modifications)

**Use Cases:**
- Build RAG systems with automatic web content indexing
- Extract website content for AI processing
- Semantic search across crawled documentation
- Collect and index training data from web sources
- Monitor competitor websites with change tracking
- Research and documentation gathering with retrieval
- Site structure analysis
- Content aggregation with vector search

## Setup

### Quick Setup

1. **Install Firecrawl CLI globally:**
   ```bash
   npm install -g @firecrawl/cli
   firecrawl --version
   ```

2. **Add credentials to `.env` file:** `~/workspace/homelab/.env`
   ```bash
   # Firecrawl API (Cloud or Self-Hosted)
   FIRECRAWL_API_KEY="fc-your-api-key"
   FIRECRAWL_API_URL="https://api.firecrawl.dev"  # Optional

   # Qdrant Vector Database (optional - RAG features only)
   QDRANT_URL="http://localhost:6333"
   QDRANT_API_KEY=""  # Optional for cloud
   QDRANT_COLLECTION="firecrawl"

   # Text Embeddings Inference (optional - RAG features only)
   TEI_URL="http://localhost:8080"
   TEI_MODEL="BAAI/bge-small-en-v1.5"
   TEI_DIMENSIONS=384
   ```

3. **Get Firecrawl API key:** Visit https://firecrawl.dev/ → Account → API Keys → Generate New Key

**For detailed setup instructions, see [README.md](./README.md)**

## Core Commands

Quick syntax reference. **For complete command reference with all parameters, see [references/commands.md](./references/commands.md)**

### Scrape Single URL
```bash
firecrawl scrape <url> [options]
```

Common options: `--only-main-content`, `--format`, `--wait-for`, `--screenshot`, `--no-embed`, `-o`

### Search the Web
```bash
firecrawl search "<query>" [options]
```

Common options: `--limit`, `--scrape`, `--sources`, `--tbs`, `--location`, `-o`

### Map Website URLs
```bash
firecrawl map <url> [options]
```

Common options: `--limit`, `--search`, `--include-subdomains`, `--sitemap`, `--exclude-paths`, `--exclude-extensions`, `--no-default-excludes`, `--no-filtering`, `--verbose`, `--json`, `-o`

**NEW**: URL filtering support with 143 default exclude patterns (language routes, blog paths, WordPress, etc.)

### Crawl Entire Website
```bash
firecrawl crawl <url> [options]
```

Common options: `--limit`, `--max-depth`, `--include-paths`, `--exclude-paths`, `--delay`, `--wait`, `--progress`

### Extract Structured Data
```bash
firecrawl extract <url> --prompt "<prompt>" [options]
```

Common options: `--schema`, `--system-prompt`, `--enable-web-search`, `--show-sources`

**For all parameters and detailed examples, see [references/parameters.md](./references/parameters.md)**

## RAG & Vector Database Commands

Quick syntax reference. **For complete RAG documentation, see [references/vector-database.md](./references/vector-database.md)**

### Embed Content
```bash
firecrawl embed <url|file|stdin> [options]
```

Common options: `--url`, `--no-chunk`, `--collection`

### Query Semantic Search
```bash
firecrawl query "<text>" [options]
```

Common options: `--limit`, `--domain`, `--full`, `--group`, `--collection`

### Retrieve Document
```bash
firecrawl retrieve <url> [options]
```

Common options: `--collection`, `-o`

### Database Management
```bash
firecrawl sources [options]           # List all indexed URLs
firecrawl stats [options]             # Database statistics
firecrawl domains [options]           # List unique domains
firecrawl delete --url <url> --yes   # Delete vectors
firecrawl history [options]           # View indexing history
firecrawl info <url> [options]        # URL details
```

**Note:** Auto-embedding is enabled by default. Use `--no-embed` to disable.

## Job Management

Quick syntax reference. **For complete job management documentation, see [references/job-management.md](./references/job-management.md)**

### Check Status
```bash
firecrawl status [options]            # Show all active jobs
firecrawl status --crawl <job-id>     # Check crawl job
firecrawl status --batch <job-id>     # Check batch job
firecrawl status --extract <job-id>   # Check extract job
firecrawl status --embed [job-id]     # Check embedding queue
```

### Batch Operations
```bash
firecrawl batch <url1> <url2> ... [options]   # Start batch scrape
firecrawl batch status <job-id>               # Check batch status
firecrawl batch cancel <job-id>               # Cancel batch job
firecrawl batch errors <job-id>               # Get batch errors
```

### List & Manage
```bash
firecrawl list                        # List active crawl jobs
firecrawl embed cancel <job-id>      # Cancel embedding job
```

## Workflows

When extracting web data:

1. **Choose extraction method:**
   - Single page → Use `scrape`
   - Search web → Use `search`
   - Discover URLs → Use `map`
   - Full website → Use `crawl`

2. **Select output format:**
   - LLM processing → Use markdown (`--format markdown`)
   - Preserve structure → Use HTML (`--format html`)
   - Extract links → Use links (`--format links`)
   - Visual reference → Use screenshot (`--screenshot`)

3. **Configure options:**
   - JavaScript sites → Add `--wait-for <ms>`
   - Clean content → Add `--only-main-content`
   - Rate limiting → Add `--delay <ms>`
   - Path filtering (crawl) → Add `--include-paths` or `--exclude-paths`
   - URL filtering (map) → Add `--exclude-paths`, `--exclude-extensions`, or `--no-filtering`

4. **Execute and save:**
   - Output to file → Add `-o <path>`
   - Pretty JSON → Add `--pretty`
   - Progress tracking → Add `--progress` (crawl only)

5. **Process results:**
   - Single format returns raw content
   - Multiple formats return JSON object
   - Pipe to other tools or save to file

### RAG Workflow

**Build a Documentation RAG System:**

```bash
# Step 1: Scrape documentation (auto-embeds by default)
firecrawl scrape https://docs.example.com/guide

# Step 2: Crawl entire docs site (auto-embeds all pages)
firecrawl crawl https://docs.example.com --include-paths "/docs/*" --wait --progress

# Step 3: Query the embedded content
firecrawl query "How do I configure authentication?"

# Step 4: Retrieve full document
firecrawl retrieve https://docs.example.com/auth-guide
```

**Extract and Index Product Data:**

```bash
# Extract structured data
firecrawl extract https://example.com/products \
  --prompt "Extract product name, price, description" \
  --show-sources

# Query products
firecrawl query "products under $50 with free shipping"
```

**Database Maintenance:**

```bash
# Show database stats
firecrawl stats --verbose

# List all sources
firecrawl sources

# Delete old content
firecrawl delete --domain old.example.com --yes

# View cleanup history
firecrawl history --days 30
```

## Parameter Constraints

**CRITICAL:** Do NOT add `--limit`, `--max-depth`, or other constraint parameters unless the user explicitly requests them.

- ❌ **Don't:** Automatically add `--limit 10` or `--max-depth 3`
- ✅ **Do:** Only add constraints when user says "max 10 results", "depth 3", etc.
- ✅ **Do:** Let operations run unlimited by default - user will stop them if needed
- ✅ **Do:** Trust the user to set appropriate limits for their use case

## Notes

### Auto-Embedding Behavior

**Default:** All scrape, crawl, search, and extract operations automatically embed content into Qdrant.

**Disable embedding:**
- Add `--no-embed` flag to any command
- Content is scraped but NOT embedded

**When to disable:**
- Testing scraping logic
- Extracting data for non-RAG purposes
- Avoiding duplicate embeddings
- Performance-sensitive operations

### URL Filtering (Map Command)

**Default Behavior:** Map command applies 143 default exclude patterns to filter unwanted URLs:
- Language routes (e.g., `/en/`, `/de/`, `/fr/`, `/es/`)
- Blog paths (e.g., `/blog/`, `/news/`, `/article/`)
- WordPress admin (e.g., `/wp-admin`, `/wp-login`)
- Common excludes (e.g., `/login`, `/logout`, `/cart`, `/checkout`)

**Filtering Options:**
- `--exclude-paths <paths...>` - Add custom patterns (merged with defaults)
- `--exclude-extensions <exts...>` - Filter file types (e.g., `.pdf`, `.zip`, `.exe`)
- `--no-default-excludes` - Skip default patterns (only apply custom excludes)
- `--no-filtering` - **Master override**: Disable ALL filtering (defaults + custom)
- `--verbose` - Show excluded URLs and which patterns matched

**Pattern Matching:**
- Simple patterns use substring matching: `/blog/` matches any URL containing `/blog/`
- Regex patterns auto-detected: `\.pdf$` matches URLs ending with `.pdf`
- Invalid regex patterns are caught and logged, filtering continues with remaining patterns

**Examples:**
```bash
# Default filtering (excludes language routes, blog, wp-admin, etc.)
firecrawl map docs.example.com --limit 50

# Custom excludes (merged with defaults)
firecrawl map example.com --exclude-paths /api,/admin --exclude-extensions .pdf

# No defaults, only custom excludes
firecrawl map example.com --no-default-excludes --exclude-paths /test

# Disable all filtering
firecrawl map example.com --exclude-paths /api --no-filtering

# Verbose mode (see what was filtered)
firecrawl map example.com --verbose
```

### Authentication

- **Cloud API**: Requires API key (get from https://firecrawl.dev/)
- **Self-hosted**: Skip authentication automatically
- **API key sources**: `.env` file, CLI login, or `--api-key` flag
- **Environment variable**: `FIRECRAWL_API_KEY` is read by CLI

### Output Behavior

- **Single format**: Returns raw content (pipe-friendly)
- **Multiple formats**: Returns JSON object with all formats
- **`--pretty` flag**: Human-readable JSON formatting
- **`-o` flag**: Saves to file instead of stdout

### Performance Tips

- Use `--only-main-content` to reduce data size
- Set `--delay` and `--max-concurrency` to avoid rate limits
- Filter paths with `--include-paths`/`--exclude-paths` (crawl) or `--exclude-paths`/`--exclude-extensions` (map)
- Use `--max-depth` to control crawl scope
- Map first with URL filtering, then crawl specific paths for large sites
- Use `--no-embed` when testing scraping logic
- Batch operations for multiple URLs
- Use `--no-filtering` to bypass all URL filters when you need complete results

### Vector Database

- **Collection**: Configured via `QDRANT_COLLECTION` env var
- **Chunking**: Automatic by default (disable with `--no-chunk`)
- **Metadata**: Stores URL, domain, source command, timestamp
- **Deduplication**: Automatic by URL and content hash

## Reference

**Core Documentation:**
- [README.md](./README.md) - Complete user-facing documentation with setup
- [Firecrawl Official Docs](https://docs.firecrawl.dev/) - Official Firecrawl documentation
- [Firecrawl CLI Docs](https://docs.firecrawl.dev/sdks/cli) - Official CLI documentation
- [Firecrawl GitHub](https://github.com/firecrawl/firecrawl) - Firecrawl repository
- [Firecrawl CLI GitHub](https://github.com/firecrawl/cli) - CLI repository

**Reference Files (Detailed Documentation):**
- [references/commands.md](./references/commands.md) - Complete command reference with all parameters
- [references/parameters.md](./references/parameters.md) - All parameters organized by category
- [references/job-management.md](./references/job-management.md) - Job management and async operations
- [references/vector-database.md](./references/vector-database.md) - RAG features, Qdrant, and semantic search
- [references/quick-reference.md](./references/quick-reference.md) - Quick command examples
- [references/troubleshooting.md](./references/troubleshooting.md) - Common issues and solutions
- [references/api-endpoints.md](./references/api-endpoints.md) - API endpoint reference

**Example Scripts (Working Code):**
- [examples/README.md](./examples/README.md) - Examples overview and usage guide
- [examples/basic-scrape.sh](./examples/basic-scrape.sh) - Simple scraping workflows
- [examples/rag-pipeline.sh](./examples/rag-pipeline.sh) - Complete RAG system build
- [examples/batch-processing.sh](./examples/batch-processing.sh) - Batch scraping operations
- [examples/monitor-website.sh](./examples/monitor-website.sh) - Change monitoring workflow

**Additional Resources:**
- [Qdrant Documentation](https://qdrant.tech/documentation/) - Vector database docs
- [Text Embeddings Inference (TEI)](https://github.com/huggingface/text-embeddings-inference) - TEI GitHub
- [Hugging Face Embedding Models](https://huggingface.co/models?pipeline_tag=feature-extraction) - Model catalog

## Wrapper Scripts

For common operations, use provided wrapper scripts in `scripts/`:

```bash
# Scrape with standard settings
./scripts/scrape.sh https://example.com

# Search and scrape top results
./scripts/search-scrape.sh "AI agents" 5

# Map website to file
./scripts/map-site.sh https://example.com sitemap.json

# Crawl with progress
./scripts/crawl-site.sh https://example.com 100 3
```

All scripts:
- Source credentials from `~/workspace/homelab/.env`
- Include error handling and validation
- Return JSON output where appropriate
- Support `--help` flag

---

## 🔧 Agent Tool Usage Requirements

**CRITICAL:** When invoking scripts from this skill via the zsh-tool, **ALWAYS use `pty: true`**.

Without PTY mode, command output will not be visible even though commands execute successfully.

**Correct invocation pattern:**
```typescript
<invoke name="mcp__plugin_zsh-tool_zsh-tool__zsh">
<parameter name="command">./skills/firecrawl/scripts/SCRIPT.sh [args]</parameter>
<parameter name="pty">true