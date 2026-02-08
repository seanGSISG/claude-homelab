# Agentic Research — Shared Team Playbook

Shared protocols and conventions for the multi-agent deep research system. This playbook is loaded by all agents (orchestrator + 3 specialists) to ensure consistent communication, source quality classification, and output formatting.

## What It Defines

- **Communication Protocol** -- Standard message formats for URL reports, progress updates, source relays, and completion signals between agents
- **Source Quality Tiers** -- 6-tier classification system (Primary, Academic, Official, Industry, Community, News) for prioritizing which URLs to relay to NotebookLM
- **Parallel Safety Rules** -- Requirements for safe concurrent agent operation (NotebookLM `-n` flag, file system isolation, message-based communication)
- **Output Formatting Standards** -- Consistent structure for findings files, citation formats, and URL reporting
- **Error Handling Protocol** -- Severity levels, reporting format, and recovery strategies
- **Persistent Memory Conventions** -- Where and how agents record session learnings

## Who Uses This

| Agent | Identity File | Loads This Playbook + |
|-------|---------------|----------------------|
| Orchestrator | `agents/agentic-orchestrator.md` | `skills/agentic-research-orchestration/SKILL.md` |
| ExaAI Specialist | `agents/exa-specialist.md` | `skills/exa/SKILL.md` |
| Firecrawl Specialist | `agents/firecrawl-specialist.md` | `skills/firecrawl/SKILL.md` |
| NotebookLM Specialist | `agents/notebooklm-specialist.md` | `skills/notebooklm/SKILL.md` |

## Source Quality Tiers (Summary)

| Tier | Priority | Relay to NotebookLM? |
|------|----------|---------------------|
| Primary | Highest | Always |
| Academic | High | Always |
| Official | High | Always |
| Industry | Medium | If relevant + not redundant |
| Community | Lower | Only if unique insights |
| News | Lowest | Rarely |

## Key Rules

1. All agents read this playbook before starting work
2. NotebookLM commands always use `-n <notebook_id>` (never `notebooklm use`)
3. Each specialist writes to its own findings file (no conflicts)
4. URL reports go to orchestrator every 3-5 operations
5. Sources are classified by quality tier before relaying
6. Errors are reported with severity, impact, and suggested fix
7. Session learnings are written to persistent memory

## Reference

- [Source Quality Tiers (detailed)](./references/source-quality-tiers.md)
- [Message Templates](./references/message-templates.md)
