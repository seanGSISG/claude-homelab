---
description: List notebooks, sources, or artifacts in NotebookLM
argument-hint: [notebooks|sources|artifacts]
allowed-tools: Bash(notebooklm:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

List NotebookLM items:

$ARGUMENTS

## Instructions

Use zsh-tool with `pty: true` for visible output.

**Determine what to list based on context:**

1. **List notebooks** (default, or if user says "notebooks"):
   ```bash
   notebooklm list
   ```

2. **List sources** (if user says "sources"):
   ```bash
   notebooklm source list
   ```
   Add `--json` for structured output.

3. **List artifacts** (if user says "artifacts", "downloads", "generated"):
   ```bash
   notebooklm artifact list
   ```

4. **Show current context:**
   ```bash
   notebooklm status
   ```

Present results in a clear table format with IDs, names, and status.

For detailed CLI reference, see `skills/notebooklm/references/cli-reference.md`.
