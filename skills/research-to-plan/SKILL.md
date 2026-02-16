---
name: research-to-plan
description: Orchestrate the full idea-to-validated-plan pipeline using agent teams. Combines Firecrawl RAG research, brainstorming, plan writing, and validation into a coordinated workflow with proper task dependencies. Use when starting any non-trivial feature from scratch.
metadata:
  clawdbot:
    emoji: "🏗️"
    requires:
      skills:
        - firecrawl
        - superpowers
        - validating-plans
---

# Research-to-Plan Orchestration

**Invoke this skill when:**
- User wants to build a new feature from an idea
- User says "research and plan", "design and plan", "brainstorm this"
- Starting any non-trivial implementation that needs both research and planning
- User wants a RAG-grounded design (not assumptions)

**Do NOT use for:**
- Simple bug fixes or single-file changes
- Tasks where the approach is already clear and documented
- Pure research with no implementation intent

## Overview

This skill orchestrates a full pipeline from idea to validated implementation plan using an **agent team** with strict task dependencies. Every phase blocks until its prerequisites are complete, and every design decision is grounded in indexed documentation — not assumptions.

**Pipeline:** Brainstorm → Crawl Docs → Research → Augment Design → Write Plan → Validate Plan

## Phase 1: Brainstorm + Early Crawl Dispatch

**You (the lead) handle the brainstorm directly.**

1. **Orient** — Review recent commits, session logs, active plans (per Orient First rule)
2. **Invoke `superpowers:brainstorming`** — Follow it exactly:
   - Explore project context
   - Ask clarifying questions (one at a time)
   - Propose 2-3 approaches with trade-offs
   - Present design sections, get user approval on each
   - Save design doc to `docs/plans/YYYY-MM-DD-<topic>-design.md`

### Early Crawl Dispatch (AS SOON AS TECH STACK IS IDENTIFIED)

**Do NOT wait for the full design to be approved.** As soon as you know what technologies, libraries, or frameworks are involved — even mid-brainstorm — immediately create an agent team and dispatch a **crawler agent**:

1. `TeamCreate` with name `rtp-<topic>`
2. Spawn **crawler** teammate:

```
You are the documentation crawler. Your ONLY job is to index docs into the knowledge base.

Technologies to crawl: [list identified tech stack]

For EACH technology/library/framework:
1. firecrawl:map — discover the docs site structure
2. firecrawl:crawl — crawl the FULL docs site (not just one page)
3. Report what was indexed and approximate page count

Crawl the official docs site for each. Examples:
- React: https://react.dev
- Next.js: https://nextjs.org/docs
- Zod: https://zod.dev
- Drizzle: https://orm.drizzle.team
- FastAPI: https://fastapi.tiangolo.com
- Pydantic: https://docs.pydantic.dev

Work through the list systematically. Mark each crawl complete via TaskUpdate.
When ALL crawls are done, send a message to the lead confirming completion.
```

3. Create tasks for each technology with `TaskCreate`
4. **Continue brainstorming** while crawls run in the background
5. The crawler works independently — no coordination needed yet

**Gate:** Two things must be true before Phase 2:
- User has approved the design doc
- All crawls have completed (check TaskList or wait for crawler's completion message)

If the design is approved but crawls aren't done yet, **wait for crawls to finish.** The whole point is that Phase 2 queries a fully-loaded knowledge base.

## Phase 2: Research (Grounded in Indexed Docs)

Now the knowledge base is loaded with everything we need. Spawn a **researcher** teammate:

```
You are the research specialist. The knowledge base has been freshly loaded
with all relevant documentation. Your job is to ground our design in facts.

Design doc: docs/plans/YYYY-MM-DD-<topic>-design.md

For each major design decision in the doc:
1. firecrawl:query — semantic search the knowledge base
2. firecrawl:ask — ask specific questions grounded in indexed docs:
   - "What are best practices for X?"
   - "What are common pitfalls with Y?"
   - "How does Z handle [specific concern from design]?"
3. firecrawl:retrieve — pull full docs for anything that needs deeper reading

DO NOT use firecrawl:search or firecrawl:crawl — the crawler already indexed
everything. You are querying, not gathering.

Report findings organized by design decision. Include:
- Evidence supporting or challenging each approach
- Specific API patterns, configuration, versions
- Risks or gotchas discovered
- Any contradictions between the design and the docs

Mark task complete when done. Send findings to the lead.
```

Create tasks:
```
Task: "Research design decisions against indexed docs"
  - Depends on: all crawl tasks complete
  - Agent: researcher

Task: "Augment design doc with research findings"
  - Depends on: research task
  - Agent: researcher
  - Action: Update design doc with evidence, specific patterns, risks
  - If research contradicts design decisions, FLAG CLEARLY — don't silently change
```

### Lead Responsibilities During Phase 2

- Monitor task progress via `TaskList`
- When augmented design is ready, review it yourself
- Present changes to the user for approval
- If user requests changes, message the researcher with feedback
- **Gate:** User must approve the augmented design before Phase 3

Once approved, shut down all agents: `SendMessage` type `shutdown_request` to crawler and researcher. Then `TeamDelete`.

## Phase 3: Write Implementation Plan

After the augmented design is approved:

1. **Invoke `superpowers:writing-plans`** — Follow it exactly:
   - Use the augmented design doc as input
   - Create bite-sized tasks (2-5 min each)
   - Full TDD 5-step pattern for every task
   - Exact file paths, complete code, exact commands
   - Save to `docs/plans/YYYY-MM-DD-<topic>.md`

## Phase 4: Validate Plan

After the plan is written:

1. **Invoke `validating-plans`** — Follow it exactly:
   - Launch 3 parallel validation agents (static-analyzer, environment-verifier, architecture-reviewer)
   - Add organization note to plan
   - Aggregate results into validation report
   - If blockers found: create TodoWrite tasks to fix THE PLAN, then re-validate
   - If clean: offer GitHub issue creation

## Phase 5: Handoff

After validation passes:

> "Pipeline complete. Design researched and grounded. Plan written and validated.
>
> **Design:** `docs/plans/YYYY-MM-DD-<topic>-design.md`
> **Plan:** `docs/plans/YYYY-MM-DD-<topic>.md`
> **Knowledge base:** Indexed [N] pages across [M] documentation sites
>
> Two execution options:
> 1. **Subagent-Driven (this session)** — `superpowers:subagent-driven-development`
> 2. **Parallel Session (separate)** — Open new session with `superpowers:executing-plans`
>
> Which approach?"

## Key Principles

- **Crawl early, crawl everything** — As soon as you know the tech stack, start indexing. Don't wait for the full design. The crawler runs in parallel with brainstorming.
- **Block on crawls before research** — The researcher ONLY queries the knowledge base. All indexing must be complete first. This is a hard dependency.
- **RAG before assumptions** — firecrawl:query before firecrawl:search. Check what you know before hitting the web. The researcher should almost never need to search — the crawler already indexed everything.
- **User gates** — Design approval required twice: after initial brainstorm (Phase 1) and after research augmentation (Phase 2). Never skip these.
- **Always Be Indexing** — Crawl full docs sites, not individual pages. Every crawl is an investment in every future session.
- **Clean shutdown** — Shut down all agents and delete the team after Phase 2. Don't leave orphaned agents.
- **Plan fixes fix THE PLAN** — During validation, TodoWrite tasks fix the plan document, not the code.
- **Flag, don't fix** — If research contradicts the design, flag it clearly for user review. Don't silently change architecture.

## Error Recovery

- **Crawl fails:** Retry once. If still failing, note the gap and continue — the researcher can fall back to firecrawl:search for that specific technology.
- **Agent stuck:** Message it directly with clarification or reassign the task.
- **Research contradicts design:** Flag to user immediately. Present the evidence and let them decide.
- **Validation finds blockers:** Fix plan, re-validate. Don't skip to execution.
- **User rejects augmented design:** Message the researcher with feedback, don't restart from scratch.

## Example Flow

```
User: "I want to build a real-time dashboard with WebSockets"

Phase 1 (Brainstorm):
  Lead: "What framework? What data sources?"
  User: "Next.js + FastAPI backend, streaming sensor data"
  Lead: → identifies tech: Next.js, FastAPI, WebSockets, React
  Lead: → IMMEDIATELY dispatches crawler for all 4 docs sites
  Lead: → continues brainstorm while crawls run...
  Lead: → design doc approved ✓
  Lead: → crawls complete ✓ (indexed 1,847 pages)

Phase 2 (Research):
  Researcher: firecrawl:query "WebSocket patterns in Next.js"
  Researcher: firecrawl:ask "How does FastAPI handle WebSocket connections?"
  Researcher: firecrawl:retrieve (full WebSocket docs for both)
  Researcher: → augments design with specific patterns, gotchas
  User: → approves augmented design ✓

Phase 3 (Plan):
  Lead: → invokes writing-plans with augmented design
  Lead: → 23 bite-sized TDD tasks created

Phase 4 (Validate):
  Lead: → invokes validating-plans
  Lead: → 3 parallel validators, all pass ✓

Phase 5 (Handoff):
  Lead: → "Ready. Subagent-driven or parallel session?"
```

IMPORTANT: Write these files EXACTLY as specified. Do not modify, truncate, or paraphrase any content.
