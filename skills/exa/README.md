# Exa Semantic Search

Neural semantic search via Exa.ai, optimized for AI consumption. Use when meaning and concepts matter more than exact keyword matching.

## What It Does

- **Semantic Web Search** -- Find content by meaning, not just keywords
- **Code Context Search** -- Find programming patterns, API examples, and implementations
- **Company Research** -- Competitive analysis and market research
- **AI-Optimized Results** -- Returns content structured for LLM consumption

## When to Use Exa vs Other Tools

| Need | Tool | Why |
|------|------|-----|
| Conceptual/meaning-based search | Exa | Neural semantic matching |
| Code patterns and API examples | Exa (code context) | Programming-specific index |
| Company/market research | Exa (company research) | Business-focused search |
| Breaking news / recent events | WebSearch | Recency-focused |
| Known URL content extraction | WebFetch | Direct fetch |
| Exact keyword / error messages | WebSearch | Literal matching |

## Prerequisites

- Exa MCP server configured in Claude Code
- MCP tools available: `mcp__exa__web_search_exa`, `mcp__exa__get_code_context_exa`, `mcp__exa__company_research_exa`

## Usage Examples

### Semantic Web Search

```
mcp__exa__web_search_exa
  query: "emerging techniques for LLM fine-tuning on domain-specific data"
  numResults: 10
  type: "deep"
```

### Code Context Search

```
mcp__exa__get_code_context_exa
  query: "FastAPI dependency injection with async database sessions"
  tokensNum: 5000
```

### Multi-Perspective Research

Run multiple queries to build comprehensive understanding:

1. `"academic perspectives on retrieval augmented generation"`
2. `"industry implementations of RAG pipelines"`
3. `"limitations and critiques of RAG approaches"`

Then synthesize findings across all results.

## Tips

- **Be descriptive**: "techniques for reducing hallucination in large language models" works better than "LLM hallucination fix"
- **Use search types**: `auto` (default), `fast` (quick results), `deep` (thorough)
- **Consolidate queries**: 2-3 well-crafted queries beat 10 similar ones
- **Combine with WebFetch**: Use Exa to discover URLs, then WebFetch for full content extraction

## Reference

- [Exa.ai Documentation](https://docs.exa.ai/)
- [Exa Search Guide](./exa-search.md)
