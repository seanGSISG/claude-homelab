---
skill: agentic-research-orchestration
version: 1.0.0
updated: 2026-02-06
description: >
  This skill should be loaded when the user requests deep, comprehensive, multi-source research
  on any topic. Load this skill when you see requests like "Research X comprehensively",
  "Do deep research on Y", "I need thorough analysis of Z with multiple sources",
  "Investigate A and provide detailed findings", or when the /agentic-research command is invoked.
  This skill defines the orchestrator's 5-phase methodology for coordinating ExaAI, Firecrawl,
  and NotebookLM specialist agents to conduct comprehensive research with source citation,
  quality analysis, and synthesis.
---

# Agentic Research Orchestration Methodology

This skill defines the orchestrator's methodology for conducting deep agentic research. Only the orchestrator agent loads this skill. Specialists load the shared `agentic-research` skill plus their domain-specific skills.

---

## Overview

As the orchestrator, you manage a 5-phase research workflow:

1. **Clarification** — Gather complete requirements from user
2. **Setup** — Create infrastructure (directories, research brief, NotebookLM notebook)
3. **Dispatch** — Spawn and coordinate 3 specialist agents
4. **Active Orchestration** — Relay URLs, cross-pollinate discoveries, monitor progress
5. **Synthesis** — Generate artifacts, write final report, notify user, shutdown team

---

## Phase 1: Clarification Protocol

Parse the research topic from your initial prompt. Then use the **AskUserQuestion** tool to ask a minimum of 5 clarifying questions before proceeding.

**DO NOT skip this phase. DO NOT make assumptions about scope or depth.**

### Required Questions

Ask ALL of these questions, plus any additional ones needed for zero ambiguity:

1. **Scope boundaries** — What is explicitly in scope? What is explicitly out of scope? Are there adjacent topics to include or exclude?

2. **Depth requirements** — Do you need a surface-level overview, a mid-depth analysis, or a deep technical dive with primary sources and citations?

3. **Target audience** — Who will read this? (developer, executive, academic researcher, general audience, other)

4. **Desired output format** — What form should the final deliverable take? Options: strategic report, technical analysis, comparison matrix, literature review, decision brief, other.

5. **Key questions that MUST be answered** — List the 3-5 specific questions that this research must definitively answer.

6. **Known sources or starting points** — Are there specific URLs, papers, tools, or authors the user already knows about?

7. **Time sensitivity** — Should this focus on cutting-edge 2025-2026 developments, historical context, or both?

### Clarification Guidelines

- **Continue asking follow-up questions until there is ZERO ambiguity** about what the user wants
- If the user gives a vague answer, probe deeper
- If conflicting requirements emerge, ask the user to prioritize
- The quality of the entire research operation depends on this phase — invest the time

### Document the Research Brief

Once all questions are answered, you will write a research brief in Phase 2. For now, keep detailed notes in your working memory about:
- Exact scope boundaries
- Depth level required
- Target audience
- Output format
- Key questions to answer
- Known starting sources
- Time sensitivity

---

## Phase 2: Setup

### Create Output Directory

Use today's date and a URL-safe slug of the topic:

```bash
mkdir -p ./docs/research/YYYY-MM-DD-<topic-slug>/findings
mkdir -p ./docs/research/YYYY-MM-DD-<topic-slug>/sources
mkdir -p ./docs/research/YYYY-MM-DD-<topic-slug>/artifacts
```

**Naming rules:**
- `YYYY-MM-DD` = today's date
- `<topic-slug>` = lowercase, hyphenated version of topic (e.g., `ai-agent-frameworks`)

Store the output directory path — every agent will need it.

### Write Research Brief

Write `./docs/research/YYYY-MM-DD-<topic-slug>/research-brief.md`:

```markdown
# Research Brief: <Topic>

**Date:** YYYY-MM-DD
**Requested by:** User
**Orchestrator:** Agentic Research (/agentic-research)

## Topic
<Exact topic statement>

## Scope
- **In scope:** <what's included>
- **Out of scope:** <what's excluded>

## Depth
<Surface / Mid-depth / Deep technical>

## Target Audience
<Who will read this>

## Output Format
<Strategic report / Technical analysis / Comparison matrix / etc.>

## Key Questions
1. <Question 1>
2. <Question 2>
3. <Question 3>
4. <Question 4>
5. <Question 5>

## Known Sources
- <Any URLs, papers, or starting points the user provided>

## Time Sensitivity
<Cutting-edge 2025-2026 / Historical / Both>

## Additional Context
<Any other relevant details from clarification>
```

### Create NotebookLM Notebook

Create a notebook for this research session:

```bash
notebooklm create "Agentic Research: <topic>" --json
```

The JSON output format:
```json
{"id": "abc123...", "title": "Agentic Research: <topic>"}
```

**Extract and store the notebook ID.** You will pass it to the NotebookLM specialist.

**CRITICAL:** For ALL subsequent NotebookLM commands, use the `-n <notebook_id>` flag. NEVER use `notebooklm use` — that command is not safe for parallel multi-agent execution.

---

## Phase 3: Dispatch Specialist Agents

### Create Team

Use **TeamCreate** to create the team:

```
TeamCreate with:
  team_name: "agentic-research-<topic-slug>"
  description: "Deep research on <topic>"
  agent_type: "agentic-orchestrator"
```

This creates the team infrastructure and shared task list at `~/.claude/tasks/agentic-research-<topic-slug>/`.

### Create Tasks

Use **TaskCreate** to create one task per specialist agent. Each task contains:
- The full research brief text
- The output directory path
- Agent-specific instructions
- The notebook ID (for NotebookLM specialist only)

You do NOT need to create these tasks manually — the specialist agents will handle their own task tracking. Focus on spawning them with clear instructions.

### Spawn Specialist Agents

Spawn exactly 3 specialist agents via the **Task** tool with the `team_name` parameter. Each agent is a full Claude Code instance with its own context window.

| Agent | subagent_type | Receives | Special Notes |
|-------|---------------|----------|---------------|
| **ExaAI** | `exa-specialist` | Research brief, output directory | Conducts 10-20 semantic searches |
| **Firecrawl** | `firecrawl-specialist` | Research brief, output directory | Maps/crawls sites on request, auto-embeds to Qdrant |
| **NotebookLM** | `notebooklm-specialist` | Research brief, **notebook ID**, output directory | **CRITICAL:** Always use `-n <notebook_id>` flag |

**Common prompt pattern for all agents:**
```
"You are the [Agent Name] Research Specialist. Your identity and methodology are defined in:
  agents/[agent-name].md

Read and internalize your identity file, then proceed with your research task.

**Research Brief:**
<paste full research brief here>

[For NotebookLM only: **Notebook ID:** <notebook_id>]

**Output Directory:** <path>

Follow the methodology defined in your agent file and the shared agentic-research skill."
```

**Detailed spawn configurations:** See [references/agent-spawn-patterns.md](references/agent-spawn-patterns.md)

---

## Phase 4: Active Orchestration Loop

**This is the CRITICAL coordination phase. You are the hub. You must actively manage information flow.**

After dispatching all three specialists, enter an active monitoring and relay loop.

### URL Relay Protocol

1. **Monitor incoming messages** from specialists — they are delivered automatically as new conversation turns.

2. When **ExaAI specialist** or **Firecrawl specialist** report discovered URLs:
   - Evaluate each URL for relevance to the research topic and key questions
   - Maintain a running count of URLs sent to NotebookLM (max 300 sources)
   - Cherry-pick the BEST URLs using these priorities:
     - Primary sources over secondary
     - Academic/official sources over blog posts
     - Sources that directly answer key questions
     - Sources with unique perspectives not covered by other URLs
     - Recent sources (2025-2026) if research is time-sensitive

3. **Relay selected URLs to NotebookLM specialist** via **SendMessage**:
   - Include the URLs and brief context for why each was selected
   - Track the count — stop at 300 sources
   - Format: `"Add these N sources to the notebook: [URL] — [description] [Tier: X]"`

4. When a **documentation site** is discovered by either specialist:
   - **Message the Firecrawl specialist** to map and crawl it
   - Format: `"Map and crawl this documentation site: <url> — focus on sections related to <subtopic>"`

### Progress Tracking

Track the following throughout the orchestration loop:

- **URLs sent to NotebookLM:** count / 300 (hard limit for paid plan)
- **ExaAI specialist status:** in progress / complete
- **Firecrawl specialist status:** in progress / complete
- **NotebookLM specialist status:** deep research running / questions in progress / complete
- **Total unique URLs discovered** across all agents

You can check specialist status by:
- Reading their messages (they report progress)
- Using **TaskList** to see task statuses
- Sending a message asking for status update

### Orchestration Rules

- **Do NOT wait passively.** Check if specialists need input when idle.
- **Do NOT send duplicate URLs** to NotebookLM. Track what has already been sent.
- **Prioritize quality over quantity** for NotebookLM sources. 200 excellent sources beat 300 mediocre ones.
- **Cross-pollinate discoveries.** If ExaAI finds a key documentation site, tell Firecrawl to crawl it. If Firecrawl finds a great source, make sure it gets to NotebookLM.
- **Keep orchestrating until ALL 3 specialists signal completion** (their tasks are marked completed via **TaskUpdate**).

---

## Phase 4.5: Artifact Generation

**IMPORTANT:** This phase happens BEFORE shutdown, while the NotebookLM specialist is still active.

Once all specialists have reported their findings are complete:

### Request Artifact Generation

Send a message to the **NotebookLM specialist**:

```
Status: Ready for artifact generation

Please generate all required artifacts:
- Report (briefing-doc format)
- Mind map (JSON)
- Data table (CSV)

Use the nlm-generate.sh script, then download all artifacts using nlm-download.sh to:
  <output-dir>/artifacts/

Report back when complete with artifact inventory.
```

### Wait for Artifact Completion

The NotebookLM specialist will:
1. Run `nlm-generate.sh -n <notebook_id> --all`
2. Run `nlm-download.sh -n <notebook_id> -o <output-dir>/artifacts/`
3. Send completion message with artifact inventory

**Do NOT proceed to Phase 5 until artifacts are downloaded.**

---

## Phase 5: Synthesis and Completion

Once all three specialists have completed their work AND artifacts are downloaded:

### Gather All Findings

1. Read all findings files:
   - `<output_dir>/findings/exa-findings.md`
   - `<output_dir>/findings/firecrawl-findings.md`
   - `<output_dir>/findings/notebooklm-findings.md`

2. Query Qdrant for any gaps in coverage:
   ```bash
   bash skills/firecrawl/scripts/query.sh "<research topic>" --limit 20
   ```
   This searches the Qdrant vector DB built by Firecrawl's auto-embedding to find any relevant content that may not have surfaced in the findings files.

### Write Final Report

Write `<output_dir>/report.md` using the template below:

```markdown
# Deep Research Report: <Topic>

**Date:** YYYY-MM-DD
**Research Method:** Deep Agentic Research (ExaAI + Firecrawl + NotebookLM)
**Orchestrator:** Agentic Research System

---

## Executive Summary

<2-3 paragraph summary of the most important findings, key insights, and actionable conclusions. Write this LAST after completing all other sections.>

---

## Key Findings

### Finding 1: <Title>
<Description with inline citations and source URLs>

**Sources:**
- [Title](URL) — Tier: <quality>

### Finding 2: <Title>
<Description with inline citations>

**Sources:**
- [Title](URL) — Tier: <quality>

### Finding 3: <Title>
...

<Continue for all major findings, organized by topic area or key question>

---

## Detailed Analysis

### <Key Question 1>
<In-depth analysis addressing this question, drawing from all three specialist agents' findings. Include inline citations with source URLs.>

### <Key Question 2>
<In-depth analysis>

### <Key Question 3>
<In-depth analysis>

<Continue for all key questions from the research brief>

---

## Contradictions and Debates

<Document any conflicting information found across sources. Do NOT smooth over disagreements — present both sides with evidence.>

- **Debate 1:** <Description> — Source A says X ([url]), Source B says Y ([url])
- **Debate 2:** <Description>

---

## Research Gaps

<What questions remain unanswered? What areas had insufficient source material? What would require further investigation?>

- Gap 1: <Description>
- Gap 2: <Description>

---

## Conclusions and Recommendations

<Based on the totality of evidence gathered, what are the clear conclusions? What actions or decisions does this research support?>

1. <Conclusion/Recommendation 1>
2. <Conclusion/Recommendation 2>
3. <Conclusion/Recommendation 3>

---

## Methodology

This research was conducted using a multi-agent deep research system:

- **ExaAI Specialist:** Performed N semantic searches, discovered N unique sources
- **Firecrawl Specialist:** Scraped N pages, crawled N documentation sites, embedded N documents to Qdrant
- **NotebookLM Specialist:** Analyzed N sources in NotebookLM, ran deep research, asked N analytical questions
- **Total unique sources:** N
- **NotebookLM artifacts generated:** briefing-doc, mind-map, data-table
- **Research duration:** approximately N minutes

---

## Sources

See [sources.md](./sources/sources.md) for the complete list of all URLs and references.

---

## Artifacts

Generated NotebookLM artifacts are available in `./artifacts/`:
- **Reports:** `./artifacts/reports/` — Briefing documents
- **Mind Maps:** `./artifacts/mind-maps/` — Visual topic structure
- **Data Tables:** `./artifacts/data-tables/` — Comparison tables
```

### Write Sources File

Write `<output_dir>/sources/sources.md` with ALL URLs from all three agents, deduplicated and organized:

```markdown
# Sources: <Topic>

**Research Date:** YYYY-MM-DD
**Total Unique Sources:** N

---

## Primary Sources
- [Title/Description](URL) — Found by: <agent> — Tier: Primary

## Academic Sources
- [Title](URL) — Found by: <agent> — Tier: Academic

## Official Documentation
- [Site Name](URL) — Pages crawled: N — Found by: Firecrawl — Tier: Official

## Industry Analysis
- [Title](URL) — Found by: <agent> — Tier: Industry

## Community Resources
- [Description](URL) — Found by: <agent> — Tier: Community
```

### Send Gotify Notification

Invoke the **Skill** tool to trigger the `gotify` skill:

```
Skill tool:
  skill: "gotify"
  args: "Deep Research Complete | Project: agentic-research | Topic: <topic> | Output: <output_dir> | Sources: <total_count> unique | Report: <output_dir>/report.md | Session: <session_id>"
```

**This is MANDATORY per operational requirements.**

### Write to Persistent Memory

Append to your memory file at `~/.claude/memory/agentic-orchestrator.md`:

```markdown
## Session: YYYY-MM-DD — <topic-slug>

**Clarification Insights:**
- Questions that unlocked scope: <list effective questions>
- Follow-up patterns that worked: <patterns>

**URL Relay Insights:**
- Effective quality tier prioritization: <what worked>
- Relay timing and batch sizes: <what was optimal>
- Cherry-picking criteria: <what led to best NotebookLM sources>
- NotebookLM source count: <final count> / 300

**Specialist Coordination:**
- ExaAI discoveries: <total URLs, top sources>
- Firecrawl discoveries: <sites crawled, pages scraped>
- NotebookLM analysis: <sources added, questions asked>
- Cross-pollination successes: <examples of effective relay>

**Synthesis Insights:**
- Report structure effectiveness: <what worked>
- Contradiction handling: <how disagreements were presented>
- Gap identification: <how gaps were surfaced>

**Lessons Learned:**
- <insight 1>
- <insight 2>
- <insight 3>
```

### Shutdown Team

1. Send **shutdown_request** via **SendMessage** to each specialist agent:
   - `exa-specialist`
   - `firecrawl-specialist`
   - `notebooklm-specialist`

2. Wait for shutdown confirmations from each agent

3. Use **TeamDelete** to clean up the team resources

### Present Results

After completing all steps, present the user with:

- Path to the final report: `<output_dir>/report.md`
- Path to the sources file: `<output_dir>/sources/sources.md`
- Path to artifacts: `<output_dir>/artifacts/`
- A brief summary of what was found (3-5 sentences)
- Any notable contradictions or gaps
- Suggested follow-up research if applicable

---

## Important Implementation Notes

### Parallel Safety

Always use `-n <notebook_id>` or `--notebook <notebook_id>` flags with notebooklm commands. NEVER use `notebooklm use` — it is not safe for parallel multi-agent execution.

### NotebookLM Source Limit

Maximum 300 sources per notebook (paid plan). Prioritize quality over quantity. Track the count carefully throughout the orchestration loop.

### Firecrawl Auto-Embedding

All scrape and crawl operations auto-embed content to Qdrant by default. This builds a persistent, searchable knowledge base that can be queried during synthesis.

### URL Relay Pattern

The orchestrator is the central hub for URL flow:
1. ExaAI and Firecrawl discover URLs
2. Orchestrator evaluates relevance
3. Orchestrator relays the best URLs to NotebookLM specialist
4. Orchestrator instructs Firecrawl to crawl high-value documentation sites

### NotebookLM Deep Research Timing

The `notebooklm research` command takes 15-30+ minutes to complete. The NotebookLM specialist should start it FIRST. While it runs, the specialist can add sources and ask questions in parallel.

### Output Location

Always use `./docs/research/YYYY-MM-DD-<topic-slug>/` relative to the current working directory. Create it during Phase 2 setup.

### Error Recovery

If any specialist agent fails or goes unresponsive:
- Check their task status via **TaskList**
- Send a message asking for status
- If truly failed, the orchestrator should attempt to cover that agent's responsibilities directly using available tools
- Document any gaps in the final report's Methodology section

### Quality over Speed

This is deep research. Take the time to do it right. A thorough 30-60 minute research session is far more valuable than a shallow 5-minute one. Do not rush the clarification phase or the synthesis phase.

---

## Cross-References

This orchestration methodology works in conjunction with other components of the deep research system:

- **Shared team playbook:** All agents (including you) follow the protocols defined in [agentic-research.md](../agentic-research/agentic-research.md)
  - Communication protocols and message formats
  - Source quality tier system
  - Parallel safety rules (NotebookLM `-n` flag requirement)
  - Output formatting standards
  - Error handling protocol
  - Persistent memory conventions

- **Specialist agent identities:**
  - ExaAI specialist: `agents/exa-specialist.md`
  - Firecrawl specialist: `agents/firecrawl-specialist.md`
  - NotebookLM specialist: `agents/notebooklm-specialist.md`

- **Reference documentation:**
  - Agent spawn patterns: [references/agent-spawn-patterns.md](references/agent-spawn-patterns.md)
  - Output templates: [references/templates.md](references/templates.md)
  - Source quality tiers: [agentic-research/references/source-quality-tiers.md](../agentic-research/references/source-quality-tiers.md)
  - Message templates: [agentic-research/references/message-templates.md](../agentic-research/references/message-templates.md)

**Integration points:**
- All specialists load both their domain-specific skill AND the shared playbook
- URL relay flow: Specialists → Orchestrator → NotebookLM
- Quality tier prioritization is defined in the shared playbook
- Communication formats are standardized across all agents

---

## Summary

As the orchestrator, you guide the entire research workflow from clarification to final synthesis. Your role is to:
1. Gather complete requirements
2. Set up infrastructure
3. Coordinate specialists
4. Relay information intelligently
5. Synthesize comprehensive findings

Follow this methodology precisely to ensure high-quality, thorough research that meets the user's needs.
