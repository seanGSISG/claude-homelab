---
description: Add, list, or manage sources in a NotebookLM notebook
argument-hint: add <url|file> | list | wait <id> | fulltext <id> | add-research "query"
allowed-tools: Bash(notebooklm:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Manage NotebookLM sources:

$ARGUMENTS

## Instructions

Use zsh-tool with `pty: true` for visible output.

**Source subcommands:**

1. **Add source:** `notebooklm source add "https://url.com"` or `notebooklm source add ./file.pdf`
   - Supports: URLs, YouTube, PDFs, Google Docs, text, Markdown, Word, audio, video, images

2. **List sources:** `notebooklm source list`
   - Add `--json` for structured output

3. **Wait for processing:** `notebooklm source wait <source_id>`

4. **Get full text:** `notebooklm source fulltext <source_id>`

5. **Web research (fast):** `notebooklm source add-research "query"`

6. **Web research (deep):** `notebooklm source add-research "query" --mode deep --no-wait`
   - Follow up with: `notebooklm research wait --import-all`

**Options:**
- `-n <notebook_id>` — Target a specific notebook
- `--notebook <notebook_id>` — Same as above

If the user just provides a URL or file without a subcommand, assume `add`.

For detailed CLI reference, see `skills/notebooklm/references/cli-reference.md`.
