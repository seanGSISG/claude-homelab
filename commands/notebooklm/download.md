---
description: Download generated artifacts (audio, video, report, quiz, etc.)
argument-hint: audio|video|report|mind-map|quiz|flashcards|data-table|slide-deck [output-path]
allowed-tools: Bash(notebooklm:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Download a NotebookLM artifact:

$ARGUMENTS

## Instructions

Use zsh-tool with `pty: true` for visible output.

**Ask the user for confirmation before running** — this writes to the filesystem.

**Download commands:**

```bash
notebooklm download audio ./output.mp3
notebooklm download video ./output.mp4
notebooklm download report ./report.md
notebooklm download mind-map ./map.json
notebooklm download data-table ./data.csv
notebooklm download quiz ./quiz.json
notebooklm download flashcards ./cards.json
notebooklm download slide-deck ./slides.pdf
notebooklm download infographic ./info.png
```

**Options:**
- `--all` — Download all artifacts of a type
- `--format json|md|html` — Export format (quiz/flashcards)
- `-n <notebook_id>` — Target a specific notebook

**Prerequisite:** The artifact must be fully generated. Check with `notebooklm artifact list` first.

For detailed CLI reference, see `skills/notebooklm/references/cli-reference.md`.
