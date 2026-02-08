---
description: Run web research and import results as notebook sources
argument-hint: "search query" [--mode fast|deep]
allowed-tools: Bash(notebooklm:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Run web research via NotebookLM:

$ARGUMENTS

## Instructions

Use zsh-tool with `pty: true` for visible output.

**Research modes:**

1. **Fast research** (30s - 2 min):
   ```bash
   notebooklm source add-research "query"
   ```

2. **Deep research** (15 - 30+ min):
   ```bash
   notebooklm source add-research "query" --mode deep --no-wait
   ```
   Follow up with:
   ```bash
   notebooklm research wait --import-all
   ```

3. **Check research status:**
   ```bash
   notebooklm research status
   ```

**Options:**
- `--mode fast|deep` — Research depth (default: fast)
- `--no-wait` — Don't wait for completion (recommended for deep)
- `-n <notebook_id>` — Target a specific notebook

Research results are automatically imported as notebook sources when complete.

For detailed CLI reference, see `skills/notebooklm/references/cli-reference.md`.
