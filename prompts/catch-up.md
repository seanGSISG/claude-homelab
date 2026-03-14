Get up to speed on the current project quickly and output a short actionable briefing.

Gather context in parallel where possible:
1. Branch and recent commits (`git branch --show-current`, `git log --oneline -10`).
2. If an open PR exists, inspect PR comments and summarize the 3 most recent unresolved threads as action items.
3. Read the most recent session log in `docs/sessions/` and extract completed work, pending work, and blockers.
4. Check active plans in `docs/plans/` (exclude `docs/plans/complete/`) and note current phase.

Output constraints:
- Keep the result under 20 lines.
- Do not dump raw command output.
- Focus on actionable intelligence.

Output format:
Status: 1-2 sentences on current state.
Pending:
- Up to 5 bullets of open items.
Next: one recommended first action and why.
