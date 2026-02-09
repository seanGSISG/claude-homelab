# Exa AI Quick Reference

Common patterns and examples for using Exa semantic search.

## Common Searches

### Research a Topic

```
Query: "latest research on vector embeddings 2026"
Tool: mcp__exa__web_search_exa
Params: { query, num_results: 5, use_autoprompt: true }
```

### Find Code Examples

```
Query: "FastAPI async database connection pool"
Tool: mcp__exa__get_code_context_exa
Params: { query, include_domains: ["github.com"] }
```

### Company Research

```
Query: "Anthropic AI"
Tool: mcp__exa__company_research_exa
Params: { query, num_results: 5 }
```

---

## Search Patterns

### Academic Research

```json
{
  "query": "transformer architecture improvements",
  "category": "research paper",
  "start_published_date": "2025-01-01T00:00:00Z",
  "num_results": 10
}
```

### Technical Documentation

```json
{
  "query": "PostgreSQL performance tuning guide",
  "include_domains": [
    "postgresql.org",
    "wiki.postgresql.org"
  ],
  "type": "keyword"
}
```

### Recent News

```json
{
  "query": "AI regulation developments",
  "category": "news",
  "start_published_date": "2026-02-01T00:00:00Z",
  "num_results": 20
}
```

### Code Repositories

```json
{
  "query": "Python async web scraper example",
  "include_domains": ["github.com"],
  "num_results": 5
}
```

---

## Domain Filters

### Popular Tech Sites

```javascript
include_domains: [
  "github.com",
  "stackoverflow.com",
  "dev.to",
  "medium.com",
  "hashnode.dev"
]
```

### Official Documentation

```javascript
include_domains: [
  "docs.python.org",
  "docs.docker.com",
  "kubernetes.io",
  "nodejs.org"
]
```

### Exclude Low-Quality

```javascript
exclude_domains: [
  "pinterest.com",
  "facebook.com",
  "instagram.com",
  "quora.com"
]
```

---

## Date Filters

### Last Month

```javascript
start_published_date: new Date(Date.now() - 30*24*60*60*1000).toISOString()
```

### Last Year

```javascript
start_published_date: "2025-01-01T00:00:00Z"
```

### Specific Year

```javascript
start_published_date: "2024-01-01T00:00:00Z"
end_published_date: "2024-12-31T23:59:59Z"
```

---

## Search Type Selection

| Use Case | Type | Reason |
|----------|------|--------|
| Research | `neural` | Understands concepts |
| Exact match | `keyword` | Literal matching |
| General | `auto` | Exa decides |
| Code search | `neural` | Finds similar implementations |
| Product names | `keyword` | Exact brand/product names |

---

## Category Usage

| Category | Best For |
|----------|----------|
| `research paper` | Academic research, papers, studies |
| `news` | Current events, journalism |
| `github` | Code repositories, projects |
| `tweet` | Social media, discussions |
| `company` | Business info, official sites |
| `pdf` | Documents, reports, papers |

---

## Optimization Tips

### Better Queries

**Bad:**
```
"docker"
```

**Good:**
```
"docker multi-stage builds best practices 2026"
```

### Use Autoprompt

```json
{
  "query": "how to scale web applications",
  "use_autoprompt": true  // Exa optimizes this
}
```

### Combine Filters

```json
{
  "query": "machine learning model deployment",
  "category": "research paper",
  "start_published_date": "2025-01-01T00:00:00Z",
  "include_domains": ["arxiv.org", "papers.nips.cc"],
  "num_results": 10
}
```

---

## Error Recovery

### Rate Limited

```javascript
// Wait and retry with exponential backoff
const delay = (attempt) => Math.min(1000 * Math.pow(2, attempt), 30000);
```

### No Results

1. Remove filters (domains, dates)
2. Simplify query
3. Try different search type
4. Use autoprompt

### Invalid Date

```javascript
// Always use ISO 8601
const date = new Date('2026-01-01').toISOString();  // ✅
const date = '01/01/2026';  // ❌
```

---

## Performance Tips

1. **Cache results** - Store search results locally
2. **Batch queries** - Group related searches
3. **Use num_results wisely** - Don't request more than needed
4. **Implement timeouts** - Don't wait indefinitely
5. **Handle errors gracefully** - Always have fallback

---

## Example Workflows

### Research Workflow

1. Broad neural search for topic overview
2. Filter by category (research papers)
3. Narrow by date (recent only)
4. Limit to authoritative domains
5. Get detailed content from top results

### Code Discovery Workflow

1. Search with `get_code_context_exa`
2. Include GitHub only
3. Sort by relevance
4. Review implementations
5. Adapt patterns to your use case

### News Monitoring Workflow

1. Category: news
2. Date filter: last 7 days
3. Exclude aggregators
4. Set up periodic searches
5. Track emerging trends

---

## Quick Command Reference

| Action | Tool | Key Params |
|--------|------|------------|
| Web search | `web_search_exa` | query, type |
| Code search | `get_code_context_exa` | query, include_domains |
| Company info | `company_research_exa` | query |
| Filter domains | Any | include_domains, exclude_domains |
| Filter dates | Any | start/end_published_date |
| Filter type | `web_search_exa` | category |

---

**Tip:** Start simple, iterate with filters. Exa's neural search is powerful - let it understand your intent!
