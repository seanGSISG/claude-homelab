---
description: Create a new NotebookLM notebook and optionally add sources
argument-hint: "Notebook Title" [url1] [url2] ...
allowed-tools: Bash(notebooklm:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Create a new NotebookLM notebook using the CLI:

$ARGUMENTS

## Instructions

Use zsh-tool with `pty: true` for visible output.

1. **Create the notebook:**
   ```bash
   notebooklm create "Title"
   ```

2. **If URLs or files were provided**, add them as sources:
   ```bash
   notebooklm source add "https://url1.com"
   notebooklm source add ./file.pdf
   ```

3. **Report** the notebook ID and any added sources.

**Supported source types:** URLs, YouTube links, PDFs, Google Docs, text files, Markdown, Word docs, audio, video, images.

For detailed CLI reference, see `skills/notebooklm/references/cli-reference.md`.
