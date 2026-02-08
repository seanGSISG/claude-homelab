---
description: Generate artifacts (podcast, video, quiz, report, mind map, etc.)
argument-hint: audio|video|quiz|report|mind-map|flashcards|slide-deck|infographic|data-table ["instructions"]
allowed-tools: Bash(notebooklm:*), mcp__plugin_zsh-tool_zsh-tool__zsh
---

Generate a NotebookLM artifact:

$ARGUMENTS

## Instructions

Use zsh-tool with `pty: true` for visible output.

**Ask the user for confirmation before running** — generation is long-running and may fail.

**Generation types and options:**

| Type | Command | Key Options |
|------|---------|-------------|
| Podcast | `generate audio` | `--format [deep-dive\|brief\|critique\|debate]`, `--length [short\|default\|long]` |
| Video | `generate video` | `--format [explainer\|brief]`, `--style [auto\|classic\|whiteboard\|kawaii\|anime\|watercolor\|retro-print\|heritage\|paper-craft]` |
| Slide Deck | `generate slide-deck` | `--format [detailed\|presenter]`, `--length [default\|short]` |
| Infographic | `generate infographic` | `--orientation [landscape\|portrait\|square]`, `--detail [concise\|standard\|detailed]` |
| Report | `generate report` | `--format [briefing-doc\|study-guide\|blog-post\|custom]` |
| Mind Map | `generate mind-map` | (sync, instant) |
| Data Table | `generate data-table` | description required |
| Quiz | `generate quiz` | `--difficulty [easy\|medium\|hard]`, `--quantity [fewer\|standard\|more]` |
| Flashcards | `generate flashcards` | `--difficulty [easy\|medium\|hard]`, `--quantity [fewer\|standard\|more]` |

**All types support:** `-s/--source`, `--language`, `--json`, `--retry N`

**Processing times:** Audio 10-20 min, Video 15-45 min, Quiz/Report 5-15 min, Mind Map instant.

After generation starts, suggest checking status with `notebooklm artifact list` or waiting with `notebooklm artifact wait <id>`.

For detailed CLI reference, see `skills/notebooklm/references/cli-reference.md`.
