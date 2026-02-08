---
description: Deep agentic research with ExaAI, Firecrawl, and NotebookLM
argument-hint: <topic and description of what you're researching>
allowed-tools: Task
---

# Deep Agentic Research

Spawn the **agentic-orchestrator** agent to conduct comprehensive deep research on: **$ARGUMENTS**

Use the Task tool to spawn the orchestrator:

```
Task tool:
  subagent_type: "agentic-orchestrator"
  description: "Deep research orchestration"
  prompt: "You are the Agentic Research Orchestrator. Your identity, methodology, and workflow are defined in:
    agents/agentic-orchestrator.md

    Read and internalize your agent file. It will instruct you to load two critical skills:
    1. Shared team playbook (agentic-research.md)
    2. Your orchestration methodology (agentic-research-orchestration.md)

    Research topic: $ARGUMENTS

    Follow the 5-phase methodology defined in your orchestration skill:
    1. Clarification (AskUserQuestion - minimum 5 questions)
    2. Setup (directories, research brief, NotebookLM notebook)
    3. Dispatch (TeamCreate + spawn 3 specialists)
    4. Active Orchestration (URL relay, cross-pollination, progress tracking)
    5. Synthesis (artifacts, final report, Gotify notification, team shutdown)

    Begin by reading your agent file, then proceed with Phase 1 (Clarification)."
```

The orchestrator will handle the complete research workflow from clarification through final synthesis.
