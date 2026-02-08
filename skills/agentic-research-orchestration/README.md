# Agentic Research Orchestration

Orchestrate deep, multi-source research using a team of specialized AI agents (ExaAI, Firecrawl, NotebookLM) coordinated through a 5-phase methodology.

## What It Does

- **Multi-Agent Coordination** -- Spawns and manages 3 specialist agents working in parallel
- **5-Phase Workflow** -- Clarification, Setup, Dispatch, Orchestration, Synthesis
- **Source Quality Control** -- Cherry-picks the best URLs using a tiered quality system
- **Comprehensive Output** -- Final report with citations, source list, NotebookLM artifacts
- **Cross-Pollination** -- Intelligently relays discoveries between agents for maximum coverage

## Architecture

```
User Request
    |
    v
Orchestrator (this skill)
    |
    +-- ExaAI Specialist (semantic web search, 10-20 queries)
    |       |
    |       +---> URLs + findings
    |
    +-- Firecrawl Specialist (site crawling, auto-embedding to Qdrant)
    |       |
    |       +---> Crawled content + URLs
    |
    +-- NotebookLM Specialist (source analysis, artifact generation)
            |
            +---> Deep research, reports, mind maps, data tables
```

The orchestrator acts as the central hub, relaying high-quality URLs from ExaAI and Firecrawl to NotebookLM, and directing Firecrawl to crawl documentation sites discovered by ExaAI.

## Prerequisites

- **ExaAI**: Exa MCP server configured (`mcp__exa__web_search_exa`)
- **Firecrawl**: Firecrawl CLI installed and configured with API key
- **NotebookLM**: `notebooklm-py` CLI installed and authenticated (`notebooklm login`)
- **Qdrant**: Vector database running for Firecrawl auto-embedding
- **TEI**: Text Embeddings Inference service running

## Setup

### 1. Install Dependencies

```bash
# Firecrawl CLI
npm install -g @firecrawl/cli

# NotebookLM CLI
pip install notebooklm-py
notebooklm login
```

### 2. Configure Environment

Add to your `.env` file:

```bash
# Firecrawl
FIRECRAWL_API_KEY="fc-your-api-key"

# Qdrant (for Firecrawl auto-embedding)
QDRANT_URL="http://localhost:6333"
QDRANT_COLLECTION="firecrawl"

# TEI (for embeddings)
TEI_URL="http://localhost:8080"
```

### 3. Verify

```bash
firecrawl --version
notebooklm status
```

## Usage

Invoke with any of these triggers:

- "Do deep research on [topic]"
- "Research [topic] comprehensively"
- "I need thorough analysis of [topic] with multiple sources"
- `/agentic-research [topic]`

The orchestrator will:
1. Ask 5+ clarifying questions about scope, depth, audience, format, and key questions
2. Create output directory and research brief
3. Spawn specialist agents
4. Coordinate URL relay and cross-pollination
5. Generate final report with all findings

## Output Structure

```
docs/research/YYYY-MM-DD-<topic-slug>/
├── research-brief.md          # Scope and requirements
├── report.md                  # Final synthesized report
├── findings/
│   ├── exa-findings.md        # ExaAI specialist results
│   ├── firecrawl-findings.md  # Firecrawl specialist results
│   └── notebooklm-findings.md # NotebookLM specialist results
├── sources/
│   └── sources.md             # Deduplicated source list with tiers
└── artifacts/
    ├── reports/               # NotebookLM briefing documents
    ├── mind-maps/             # Topic structure (JSON)
    └── data-tables/           # Comparison tables (CSV)
```

## Timing

A typical deep research session takes 30-60 minutes:
- Clarification: 5-10 minutes
- Setup + Dispatch: 1-2 minutes
- Active Orchestration: 15-30 minutes
- Artifact Generation: 10-20 minutes
- Synthesis: 5-10 minutes

## Reference

- [Agent Spawn Patterns](./references/agent-spawn-patterns.md)
- [Output Templates](./references/templates.md)
- [Orchestration Transcript Example](./examples/orchestration-transcript.md)
