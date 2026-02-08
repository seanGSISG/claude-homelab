# Agentic Research — Agent Spawn Patterns

Detailed Task tool configurations for spawning each specialist agent.

---

## Common Pattern

All agents are spawned via **Task** tool with these common parameters:
- `team_name`: "agentic-research-<topic-slug>"
- `description`: Brief agent purpose
- Agent reads identity file at `agents/<name>.md`
- Receives full research brief in prompt
- Receives output directory path

---

## ExaAI Specialist

**Agent Type:** `exa-specialist`

**Task tool configuration:**

```
Task tool:
  subagent_type: "exa-specialist"
  team_name: "agentic-research-<topic-slug>"
  name: "exa-specialist"
  description: "ExaAI semantic search"
  prompt: "You are the ExaAI Research Specialist. Your identity and methodology are defined in:
    1. agents/exa-specialist.md

    Read and internalize your identity file, then proceed with your research task.

    **Research Brief:**
    <paste full research brief here>

    **Output Directory:** <path>

    Follow the methodology defined in your agent file and the shared agentic-research skill."
```

**What it receives:**
- Research brief (topic, scope, key questions, depth, audience)
- Output directory path

**What it does:**
- Loads shared agentic-research skill
- Loads exa-search skill
- Conducts 10-20 semantic searches
- Reports URLs to orchestrator in batches
- Writes findings to `<output-dir>/findings/exa-findings.md`

---

## Firecrawl Specialist

**Agent Type:** `firecrawl-specialist`

**Task tool configuration:**

```
Task tool:
  subagent_type: "firecrawl-specialist"
  team_name: "agentic-research-<topic-slug>"
  name: "firecrawl-specialist"
  description: "Firecrawl web scraping and crawling"
  prompt: "You are the Firecrawl Research Specialist. Your identity and methodology are defined in:
    1. agents/firecrawl-specialist.md

    Read and internalize your identity file, then proceed with your research task.

    **Research Brief:**
    <paste full research brief here>

    **Output Directory:** <path>

    Follow the methodology defined in your agent file and the shared agentic-research skill."
```

**What it receives:**
- Research brief (topic, scope, key questions, depth, audience)
- Output directory path

**What it does:**
- Loads shared agentic-research skill
- Loads firecrawl SKILL.md
- Conducts 5-10 web searches via firecrawl CLI
- Maps and crawls documentation sites (on orchestrator request)
- Auto-embeds all content to Qdrant
- Reports URLs to orchestrator in batches
- Writes findings to `<output-dir>/findings/firecrawl-findings.md`

---

## NotebookLM Specialist

**Agent Type:** `notebooklm-specialist`

**Task tool configuration:**

```
Task tool:
  subagent_type: "notebooklm-specialist"
  team_name: "agentic-research-<topic-slug>"
  name: "notebooklm-specialist"
  description: "NotebookLM AI-assisted analysis"
  prompt: "You are the NotebookLM Research Specialist. Your identity and methodology are defined in:
    1. agents/notebooklm-specialist.md

    Read and internalize your identity file, then proceed with your research task.

    **Research Brief:**
    <paste full research brief here>

    **Notebook ID:** <notebook_id>

    **Output Directory:** <path>

    **CRITICAL:** Always use `-n <notebook_id>` flag with ALL notebooklm commands. NEVER use `notebooklm use`.

    Follow the methodology defined in your agent file and the shared agentic-research skill."
```

**What it receives:**
- Research brief (topic, scope, key questions, depth, audience)
- Notebook ID (created by orchestrator in Phase 2)
- Output directory path
- Critical reminder about `-n` flag for parallel safety

**What it does:**
- Loads shared agentic-research skill
- Loads notebooklm.md skill
- **Immediately** starts deep research (15-30 min operation)
- Adds sources as relayed by orchestrator (max 300)
- Asks 10-20 analytical questions
- Generates artifacts (report, mind-map, data-table)
- Downloads artifacts to output directory
- Writes findings to `<output-dir>/findings/notebooklm-findings.md`

---

## Spawn Order

1. **Create team first:** `TeamCreate` with team_name
2. **Spawn all 3 agents in parallel:** Use Task tool for each
3. **No specific order required:** Agents work independently

---

## Agent Communication

After spawning, agents communicate with orchestrator via **SendMessage**:
- URL discovery reports (batched every 3-5 operations)
- Progress updates (every 5-10 operations)
- Completion signals (when all work done)
- Error escalations (when blocked)

Orchestrator coordinates by:
- Relaying URLs to NotebookLM specialist
- Requesting specific sites for Firecrawl to crawl
- Tracking progress across all 3 agents
- Waiting for all 3 completion signals before proceeding to Phase 5

---

## Cross-Reference

This reference is used by:
`skills/agentic-research-orchestration/SKILL.md`

Phase 3: Dispatch Specialist Agents
