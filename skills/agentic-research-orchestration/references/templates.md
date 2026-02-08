# Agentic Research — Output Templates

This document contains all output file templates used in the agentic research workflow.

---

## Research Brief Template

Location: `<output_dir>/research-brief.md`

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

---

## Final Report Template

Location: `<output_dir>/report.md`

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

---

## Sources File Template

Location: `<output_dir>/sources/sources.md`

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

---

## Template Usage

All templates above are referenced from the core orchestration methodology. To use:

1. **Phase 2 Setup:** Use Research Brief Template
2. **Phase 5 Synthesis:** Use Final Report Template and Sources File Template
3. **Replace placeholders** with actual research data
4. **Maintain structure** for consistency across research sessions
