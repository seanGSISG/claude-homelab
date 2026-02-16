---
description: Get up to speed on a project - review recent commits, PR comments, and session logs
allowed-tools: Bash, Read, Glob, Grep
---

## Context

- Branch: !`git branch --show-current`
- Commits: !`git log --oneline -10`
- PR: !`gh pr view --json number,title,state 2>/dev/null || echo "No open PR"`

## Task

Orient quickly. Gather context, internalize it, output a SHORT briefing. Do NOT rehash or quote raw data back — summarize into actionable intelligence. Context window is precious.

### Gather (do in parallel where possible)

1. **PR comments** — If open PR exists, run `python $HOME/claude-homelab/skills/gh-address-comments/scripts/fetch_comments.py 2>/dev/null`. Scan the 3 most recent unresolved threads. Don't quote them — note what action each needs.
2. **Session logs** — Find the most recent file in `docs/sessions/`. Read it. Extract: what was done, what's pending, any blockers.
3. **Active plans** — Check `docs/plans/` (skip `complete/`). Note any in-progress plans and their current phase.

### Output (keep under 20 lines total)

**Status:** 1-2 sentences on where the project is right now.

**Pending:** Bullet list of open items needing attention (PR feedback, unfinished tasks, blockers). Max 5 bullets.

**Next:** Single recommended action to start with and why.

That's it. No summaries of commits (they're already in context above). No walls of text. Get in, get oriented, get to work.
ENDOFFILE; echo "___ZSH_PIPESTATUS_MARKER_f9a8b7c6___:${pipestatus[*]}"
