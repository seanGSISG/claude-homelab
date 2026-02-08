---
description: Chat with NotebookLM about your notebook's content
argument-hint: "your question here"
allowed-tools: Bash(notebooklm:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Ask NotebookLM a question about the current notebook's content:

$ARGUMENTS

## Instructions

Use zsh-tool with `pty: true` for visible output.

Run `notebooklm ask` with the provided question:

```bash
notebooklm ask "question here"
```

**Options** (only add if user specifies):
- `--json` — Include source references in output
- `-n <notebook_id>` — Target a specific notebook

If no notebook context is set, check with `notebooklm status` first and suggest using `notebooklm use <id>`.

Present the answer clearly, including any source references if `--json` was used.

For detailed CLI reference, see `skills/notebooklm/references/cli-reference.md`.
