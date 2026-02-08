# Message Templates — Inter-Agent Communication

Standard message templates for all communication between agents in the agentic research system.

## Specialist -> Orchestrator Messages

### URL Report (Batch)

Send every 3-5 operations:

```
## [Agent Name] URL Report (Batch N)

### Key URLs Discovered:
- https://url1.com - [Brief description] - Tier: [Primary/Academic/Official/Industry/Community/News]
- https://url2.com - [Brief description] - Tier: [tier]
- https://url3.com - [Brief description] - Tier: [tier]

### Documentation Sites (recommend for Firecrawl crawling):
- https://docs.example.com - [What it documents, estimated size]

### Key Findings So Far:
- [Finding 1 with source reference]
- [Finding 2 with source reference]

### Stats:
- Queries/operations this batch: N
- Total unique URLs discovered: N (cumulative)
```

**SendMessage summary:** "[Agent] batch N: X URLs found"

---

### Progress Update

Send every 5-10 operations or when significant milestone reached:

```
## [Agent Name] Progress Update

### Status: [In Progress / Nearing Completion]
### Operations Completed: N / estimated N
### Key Milestones:
- [Milestone 1]
- [Milestone 2]

### Blockers: [None / Description of issue]
### Estimated Remaining: [Brief description of remaining work]
```

**SendMessage summary:** "[Agent] progress: N% complete"

---

### Completion Signal

Send when all work is done:

```
[Agent Name] specialist complete.
Findings written to findings/[agent]-findings.md.
[Key stats: N searches, N URLs, N pages, etc.]
Key gaps: [list any unanswered questions or missing coverage].
```

**SendMessage summary:** "[Agent] research complete"

---

### Error Escalation

Send when encountering a blocking issue:

```
## Error Report

**Agent:** [name]
**Severity:** [Warning / Error / Critical]
**Error:** [Clear description of what went wrong]
**Action Taken:** [What you tried to resolve it]
**Impact:** [What's affected - specific URLs, operations, coverage areas]
**Suggested Fix:** [If you have an idea for resolution]
**Can Continue:** [Yes, with reduced coverage / No, blocked]
```

**SendMessage summary:** "[severity] on [agent]: [brief description]"

---

## Orchestrator -> Specialist Messages

### Source Relay (to NotebookLM)

```
Add these N sources to the notebook:
- https://url1.com — [Description] — Tier: Primary
- https://url2.com — [Description] — Tier: Academic
- https://url3.com — [Description] — Tier: Official

Source count: [current] / [limit] (N remaining slots)
Priority: [High - these answer key questions / Normal - good supplementary sources]
```

**SendMessage summary:** "Relay N sources to NotebookLM"

---

### Crawl Request (to Firecrawl)

```
Map and crawl this documentation site:
URL: https://docs.example.com
Focus: [Specific sections or paths relevant to research]
Discovered by: [ExaAI / Orchestrator / User-provided]
Priority: [High / Normal]
```

**SendMessage summary:** "Crawl request: docs.example.com"

---

### Status Check

```
Status check: How is your progress?
- Have you completed your initial search/scrape phase?
- Any blockers or rate limit issues?
- Estimated completion time?
```

**SendMessage summary:** "Status check for [agent]"

---

### Artifact Generation Request (to NotebookLM)

```
Status: Ready for artifact generation

Please generate all required artifacts:
- Report (briefing-doc format)
- Mind map (JSON)
- Data table (CSV) - Description: "[what to compare]"

Use the generate commands with -n [notebook_id], then download all artifacts to:
  [output-dir]/artifacts/

Report back when complete with artifact inventory.
```

**SendMessage summary:** "Generate artifacts request"

---

### Shutdown Request

```
Research complete. Please finalize any remaining work and prepare for shutdown.
Ensure all findings are written to your findings file.
```

Then use SendMessage with `type: "shutdown_request"`.

---

## Message Best Practices

1. **Be concise** -- agents have limited context, avoid unnecessary verbosity
2. **Include stats** -- quantify everything (N URLs, N pages, N queries)
3. **Classify sources** -- always include tier classification for URLs
4. **Highlight gaps** -- explicitly call out what's missing or needs more work
5. **Flag contradictions** -- never hide disagreements between sources
6. **Use consistent format** -- follow templates exactly for easy parsing
7. **Batch appropriately** -- don't send one URL at a time, batch 3-10
