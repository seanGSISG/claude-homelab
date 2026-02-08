---
name: exa
version: 1.0.0
description: Semantic web search using Exa.ai neural search optimized for AI consumption. Use when meaning matters more than keywords -- find academic papers, similar companies, code context, and conceptual content that keyword search misses.
homepage: https://exa.ai/
metadata:
  clawdbot:
    emoji: "🔍"
    requires:
      mcp: ["exa"]
---

# Exa Semantic Search Skill

**YOU MUST invoke this skill (NOT optional) when the user mentions ANY of these triggers:**
- "semantic search", "find papers on", "find articles about"
- "companies similar to", "find sources about"
- "Exa", "exa search", "neural search"
- Any request for conceptual/meaning-based web search (not keyword matching)

**Failure to invoke this skill when triggers occur violates your operational requirements.**

Exa.ai provides neural semantic search optimized for AI consumption. Use when meaning matters more than keywords.

## Decision Flowchart

Use this to decide which search tool to use:

| Scenario | Tool | Why |
|----------|------|-----|
| "Find papers on emergent AI behavior" | `mcp__exa__web_search_exa` | Semantic discovery |
| "Companies similar to Anthropic" | `mcp__exa__web_search_exa` | Similar content |
| "How to use React hooks" | `mcp__exa__get_code_context_exa` | Coding context |
| "Latest news on X" | `WebSearch` | Recency matters |
| "Read this URL: [link]" | `WebFetch` | Known URL |
| "error: module not found XYZ" | `WebSearch` | Exact keyword match |
| "CVE-2024-12345" | `WebSearch` | Specific identifier |

**Decision logic:**
1. Have a specific URL? -> `WebFetch`
2. Is this semantic/conceptual (meaning > keywords)? -> Exa
3. Is it a coding/API question? -> `mcp__exa__get_code_context_exa`
4. Need very recent news/events? -> `WebSearch`
5. Keyword/identifier match? -> `WebSearch`

## Tool Usage

### mcp__exa__web_search_exa

Semantic web search for concepts, topics, and similar content.

```
query: "semantic query describing concepts"
numResults: 8 (default, adjust as needed)
type: "auto" | "fast" | "deep"
```

### mcp__exa__get_code_context_exa

Code-specific search for programming patterns, APIs, and implementations.

```
query: "React useState hook examples" | "Express middleware patterns"
tokensNum: 5000 (default, 1000-50000 range)
```

### mcp__exa__company_research_exa

Company-specific research for competitive analysis and market research.

## Integration Patterns

### Discovery + Extraction
1. Exa finds relevant sources semantically
2. `WebFetch` extracts full content from best URLs

### Multi-Perspective Research
1. Exa: "academic perspectives on X"
2. Exa: "industry implementation of X"
3. Exa: "critiques of X"
4. Synthesize findings

### Fallback Strategy
1. Try Exa for semantic search
2. If results poor, fall back to `WebSearch` with keywords

## Anti-Patterns

| Don't | Do Instead |
|-------|------------|
| `"python pandas filter dataframe"` | Use `WebSearch` (keyword query) |
| Run 10 similar queries | Consolidate into 2-3 well-crafted queries |
| `"what is React"` | Use knowledge or `WebSearch` |
| `"breaking news today"` | Use `WebSearch` |

## When Results Are Poor

1. Switch search type: `auto` vs `fast` vs `deep`
2. Rephrase: more semantic/descriptive
3. Add domain filters via `allowed_domains`
4. Fall back to `WebSearch` for keyword matching
