# Exa AI MCP Tools Reference

This skill uses Model Context Protocol (MCP) tools provided by the `exa` MCP server.

## Available Tools

### 1. mcp__exa__web_search_exa

**Purpose:** Semantic web search using Exa's neural search engine.

**When to use:**
- Finding relevant web content by meaning, not just keywords
- Discovering high-quality sources on a topic
- Research that benefits from understanding context

**Parameters:**
- `query` (string, required) - Search query in natural language
- `num_results` (integer, optional) - Number of results to return (default: 10, max: 100)
- `include_domains` (array, optional) - Only search these domains
- `exclude_domains` (array, optional) - Exclude these domains
- `start_published_date` (string, optional) - Filter by publish date (ISO 8601)
- `end_published_date` (string, optional) - Filter by publish date (ISO 8601)
- `use_autoprompt` (boolean, optional) - Let Exa optimize the query (default: true)
- `type` (string, optional) - Result type: "neural" (default), "keyword", or "auto"
- `category` (string, optional) - Filter by category (e.g., "research paper", "news", "github")

**Example:**
```json
{
  "query": "latest developments in vector databases 2026",
  "num_results": 5,
  "use_autoprompt": true,
  "type": "neural"
}
```

**Returns:**
- Array of search results with:
  - `title` - Page title
  - `url` - Page URL
  - `publishedDate` - When published
  - `author` - Author if available
  - `score` - Relevance score
  - `text` - Page content excerpt

---

### 2. mcp__exa__get_code_context_exa

**Purpose:** Search for code snippets and technical implementation examples.

**When to use:**
- Finding code examples for a specific library/framework
- Looking for implementation patterns
- Discovering how others solved similar problems
- GitHub repository search by content

**Parameters:**
- `query` (string, required) - Code/technical query
- `num_results` (integer, optional) - Number of results (default: 10)
- `include_domains` (array, optional) - Limit to specific code hosts (e.g., ["github.com"])
- `exclude_domains` (array, optional) - Exclude domains

**Example:**
```json
{
  "query": "FastAPI websocket authentication example",
  "num_results": 3,
  "include_domains": ["github.com"]
}
```

**Returns:**
- Code-focused search results with:
  - Repository/file URLs
  - Code snippets in context
  - Implementation examples
  - Related documentation

---

### 3. mcp__exa__company_research_exa

**Purpose:** Research companies using Exa's business intelligence.

**When to use:**
- Gathering company information
- Competitive analysis
- Finding company websites and official sources
- Business research

**Parameters:**
- `query` (string, required) - Company name or description
- `num_results` (integer, optional) - Number of results (default: 10)

**Example:**
```json
{
  "query": "Anthropic AI company",
  "num_results": 5
}
```

**Returns:**
- Company-focused results with:
  - Official websites
  - Company descriptions
  - News and announcements
  - Product information

---

## Search Types Explained

### Neural Search (Default)
- Uses AI to understand query meaning
- Finds conceptually similar content
- Best for research and discovery
- Higher quality results
- Example: "how to scale microservices" finds architecture guides, not just keyword matches

### Keyword Search
- Traditional keyword matching
- Exact phrase matching
- Faster for specific terms
- Example: "docker-compose.yml" finds files with exact filename

### Auto Search
- Exa automatically chooses between neural and keyword
- Recommended for most use cases

---

## Domain Filtering

**Include specific domains:**
```json
{
  "include_domains": [
    "github.com",
    "stackoverflow.com",
    "docs.python.org"
  ]
}
```

**Exclude domains:**
```json
{
  "exclude_domains": [
    "pinterest.com",
    "facebook.com"
  ]
}
```

---

## Date Filtering

**Recent content only:**
```json
{
  "start_published_date": "2026-01-01T00:00:00Z"
}
```

**Date range:**
```json
{
  "start_published_date": "2025-01-01T00:00:00Z",
  "end_published_date": "2026-01-01T00:00:00Z"
}
```

---

## Category Filtering

Available categories:
- `research paper` - Academic papers and research
- `news` - News articles and journalism
- `github` - GitHub repositories and code
- `tweet` - Twitter/X posts
- `company` - Company websites and business info
- `pdf` - PDF documents

**Example:**
```json
{
  "query": "machine learning embeddings",
  "category": "research paper"
}
```

---

## Best Practices

1. **Use autoprompt for research:**
   - Exa optimizes your query for better results
   - Especially useful for complex topics

2. **Start broad, then filter:**
   - Run initial search without filters
   - Apply domain/date filters if needed
   - Narrow down with categories

3. **Code search tips:**
   - Use `get_code_context_exa` for code
   - Include language/framework in query
   - Filter to `github.com` for repos

4. **Company research:**
   - Use `company_research_exa` for businesses
   - More structured than general search
   - Finds official sources first

---

## Error Handling

**Common errors:**
- `Invalid query` - Query is empty or malformed
- `Rate limit exceeded` - Too many requests, wait before retry
- `Invalid date format` - Use ISO 8601: `YYYY-MM-DDTHH:MM:SSZ`

**Rate limits:**
- Exa API has rate limits based on your API key tier
- Implement exponential backoff for retries
- Cache results when possible

---

## Reference

- **Exa AI Docs:** https://docs.exa.ai/
- **API Reference:** https://docs.exa.ai/api
- **Pricing:** https://exa.ai/pricing
