# Exa AI Troubleshooting

Common issues and solutions when using the Exa semantic search skill.

## Authentication & Configuration

### "MCP tool not available"

**Cause:** Exa MCP server not configured or not running.

**Solution:**
1. Check MCP server configuration in Claude Code settings
2. Verify Exa MCP server is installed
3. Restart Claude Code if needed
4. Check server logs for errors

**Verify:**
```
Check if mcp__exa__ tools are listed in available tools
```

---

### "API key invalid"

**Cause:** Exa API key is missing, expired, or incorrect.

**Solution:**
1. Get valid API key from https://exa.ai/
2. Update MCP server configuration with new key
3. Restart MCP server
4. Test with simple query

**Exa API Key Setup:**
```bash
# API key should be configured in Exa MCP server settings
# Usually in ~/.config/claude-code/mcp-servers.json or similar
```

---

## Search Quality Issues

### No results returned

**Possible causes:**
1. Query too specific or narrow
2. Domain filters too restrictive
3. Date range excludes all content
4. Category mismatch

**Solutions:**

**Simplify query:**
```json
// Too specific
{"query": "exact implementation of XYZ in framework ABC version 1.2.3"}

// Better
{"query": "XYZ implementation framework ABC"}
```

**Remove filters:**
```json
// Start broad
{
  "query": "your topic"
}

// Then add filters if needed
{
  "query": "your topic",
  "include_domains": ["github.com"]
}
```

**Check date range:**
```json
// Too narrow (might exclude everything)
{
  "start_published_date": "2026-02-07T00:00:00Z",
  "end_published_date": "2026-02-07T23:59:59Z"
}

// Better (last month)
{
  "start_published_date": "2026-01-01T00:00:00Z"
}
```

---

### Poor quality results

**Cause:** Wrong search type or category for your use case.

**Solutions:**

**Try different search types:**
```json
// If keyword search isn't working
{"type": "keyword"}  // Change to ↓
{"type": "neural"}   // Or ↓
{"type": "auto"}
```

**Use appropriate category:**
```json
// Looking for code but getting articles
{"category": null}  // Change to ↓
{"query": "...", "include_domains": ["github.com"]}

// Looking for research but getting blogs
{"category": null}  // Change to ↓
{"category": "research paper"}
```

**Enable autoprompt:**
```json
{
  "query": "your query",
  "use_autoprompt": true  // Let Exa optimize
}
```

---

## Rate Limiting

### "Rate limit exceeded"

**Cause:** Too many requests to Exa API.

**Solutions:**

1. **Implement exponential backoff:**
```javascript
async function searchWithRetry(query, maxAttempts = 3) {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await exaSearch(query);
    } catch (error) {
      if (error.message.includes('rate limit')) {
        const delay = Math.min(1000 * Math.pow(2, attempt), 30000);
        await new Promise(resolve => setTimeout(resolve, delay));
      } else {
        throw error;
      }
    }
  }
  throw new Error('Max retry attempts exceeded');
}
```

2. **Cache results:**
```javascript
const cache = new Map();

function getCachedSearch(query) {
  const key = JSON.stringify(query);
  if (cache.has(key)) {
    return cache.get(key);
  }
  const result = exaSearch(query);
  cache.set(key, result);
  return result;
}
```

3. **Batch requests:**
- Group related queries
- Use broader searches instead of multiple specific ones
- Increase `num_results` rather than making multiple calls

4. **Check your plan:**
- Free tier: Limited requests per month
- Paid tier: Higher limits
- Upgrade if hitting limits frequently

---

## Performance Issues

### Slow search responses

**Possible causes:**
1. Large `num_results` value
2. Complex domain filtering
3. Neural search on large corpus
4. Network latency

**Solutions:**

**Reduce result count:**
```json
// Instead of
{"num_results": 100}

// Try
{"num_results": 10}
```

**Use keyword search for speed:**
```json
{
  "query": "exact phrase",
  "type": "keyword"  // Faster than neural
}
```

**Implement timeout:**
```javascript
const searchWithTimeout = (query, timeout = 10000) => {
  return Promise.race([
    exaSearch(query),
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error('Search timeout')), timeout)
    )
  ]);
};
```

---

## Content Issues

### Missing expected content

**Cause:** Content not indexed or published too recently.

**Solutions:**
1. Content may not be in Exa's index yet
2. Try alternative search terms
3. Search specific domains you know have the content
4. Use traditional web search as fallback

---

### Outdated results

**Cause:** Results are old despite being relevant.

**Solutions:**

**Filter by date:**
```json
{
  "query": "your topic",
  "start_published_date": "2026-01-01T00:00:00Z"
}
```

**Check publish dates:**
- Results include `publishedDate` field
- Sort by date in your code
- Filter results client-side

---

## Date Filter Issues

### "Invalid date format"

**Cause:** Date not in ISO 8601 format.

**Solution:**
```json
// ❌ Wrong
{
  "start_published_date": "02/01/2026"
}

// ✅ Correct
{
  "start_published_date": "2026-02-01T00:00:00Z"
}
```

**JavaScript helper:**
```javascript
const toISO = (date) => new Date(date).toISOString();

// Usage
{
  "start_published_date": toISO('2026-01-01')
}
```

---

### Date range returns nothing

**Cause:** Date range too narrow or in the future.

**Solution:**
```json
// Too narrow
{
  "start_published_date": "2026-02-07T12:00:00Z",
  "end_published_date": "2026-02-07T13:00:00Z"
}

// Better (full day)
{
  "start_published_date": "2026-02-07T00:00:00Z",
  "end_published_date": "2026-02-07T23:59:59Z"
}

// Even better (last week)
{
  "start_published_date": new Date(Date.now() - 7*24*60*60*1000).toISOString()
}
```

---

## Domain Filter Issues

### Domain filter not working

**Possible causes:**
1. Domain spelled incorrectly
2. Need subdomain specification
3. Domain not in Exa index

**Solutions:**

**Check domain spelling:**
```json
// ❌ Wrong
{"include_domains": ["stackoverflow.con"]}

// ✅ Correct
{"include_domains": ["stackoverflow.com"]}
```

**Try with and without www:**
```json
{
  "include_domains": [
    "example.com",
    "www.example.com"
  ]
}
```

**Use broader domain:**
```json
// Instead of specific subdomain
{"include_domains": ["blog.example.com"]}

// Try parent domain
{"include_domains": ["example.com"]}
```

---

## Error Messages

### "Invalid query parameter"

**Cause:** Parameter type or value is wrong.

**Check:**
- `num_results` is an integer, not string
- Dates are ISO 8601 strings
- Arrays are actually arrays
- Booleans are true/false, not "true"/"false"

---

### "Server error" or "Internal error"

**Cause:** Exa API having issues.

**Solutions:**
1. Wait a few minutes and retry
2. Check Exa status page
3. Implement retry logic
4. Fall back to alternative search

---

## Best Practices to Avoid Issues

1. **Always validate inputs:**
   - Check query is not empty
   - Validate date formats
   - Ensure arrays are proper type

2. **Implement error handling:**
   - Try/catch around all API calls
   - Graceful degradation
   - User-friendly error messages

3. **Cache aggressively:**
   - Reduce API calls
   - Faster responses
   - Avoid rate limits

4. **Start simple:**
   - Basic query first
   - Add filters incrementally
   - Test each addition

5. **Monitor usage:**
   - Track API calls
   - Watch rate limits
   - Optimize queries

---

## Getting Help

1. **Check Exa documentation:** https://docs.exa.ai/
2. **Review API reference:** https://docs.exa.ai/api
3. **Exa Discord community:** https://discord.gg/exa
4. **GitHub issues:** https://github.com/metaphorsystems/exa-py
5. **Contact support:** support@exa.ai

---

**Tip:** Most issues are resolved by simplifying your query and removing filters. Start basic, then add complexity!
