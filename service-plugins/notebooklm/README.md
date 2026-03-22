# NotebookLM Automation

Complete programmatic access to Google NotebookLM via the `notebooklm-py` CLI. Create notebooks, add sources, chat with content, generate artifacts, and download results -- including capabilities not available in the web UI.

## What It Does

- **Notebook Management** -- Create, list, delete, rename notebooks
- **Source Ingestion** -- Add URLs, YouTube videos, PDFs, Google Docs, audio, video, images
- **AI Chat** -- Query your sources with citations and references
- **Artifact Generation** -- Podcasts, videos, slide decks, infographics, reports, mind maps, data tables, quizzes, flashcards
- **Batch Operations** -- Download all artifacts, export quizzes as JSON/Markdown/HTML
- **Deep Web Research** -- Automated web research with source import
- **Multi-Language** -- 80+ languages for artifact generation

## Setup

### 1. Install the CLI

```bash
# From PyPI (recommended)
pip install notebooklm-py

# Install the Claude Code skill
notebooklm skill install
```

### 2. Authenticate

```bash
notebooklm login          # Opens browser for Google OAuth
notebooklm list           # Verify authentication works
```

### 3. Verify

```bash
notebooklm status         # Should show "Authenticated as: email@..."
notebooklm list --json    # Should return valid JSON
```

## Usage Examples

### Create a Podcast from URLs

```bash
notebooklm create "Research: AI Agents"
notebooklm source add "https://docs.anthropic.com/..."
notebooklm source add "https://arxiv.org/abs/..."
# Wait for sources to process
notebooklm source list --json
# Generate podcast
notebooklm generate audio "Focus on practical applications"
# Check and download when ready
notebooklm artifact list
notebooklm download audio ./podcast.mp3
```

### Analyze Documents

```bash
notebooklm create "Analysis: Q4 Report"
notebooklm source add ./report.pdf
notebooklm ask "What are the key takeaways?"
notebooklm ask "Compare revenue growth across quarters"
```

### Deep Research

```bash
notebooklm create "Research: Quantum Computing 2026"
notebooklm source add-research "quantum computing breakthroughs" --mode deep --no-wait
notebooklm research wait --import-all
notebooklm ask "What are the most promising approaches?"
```

### Generate Multiple Artifacts

```bash
notebooklm generate report --format briefing-doc
notebooklm generate mind-map
notebooklm generate data-table "Compare all approaches by cost, scalability, and maturity"
notebooklm generate quiz --difficulty medium
```

## Artifact Types

| Type | Format | Download | Typical Time |
|------|--------|----------|-------------|
| Podcast | deep-dive, brief, critique, debate | .mp3 | 10-20 min |
| Video | explainer, brief (multiple styles) | .mp4 | 15-45 min |
| Slide Deck | detailed, presenter | .pdf | 5-15 min |
| Infographic | landscape, portrait, square | .png | 5-15 min |
| Report | briefing-doc, study-guide, blog-post | .md | 5-15 min |
| Mind Map | (instant) | .json | instant |
| Data Table | (requires description) | .csv | 5-15 min |
| Quiz | easy, medium, hard | .json/.md/.html | 5-15 min |
| Flashcards | easy, medium, hard | .json/.md/.html | 5-15 min |

## Parallel Agent Workflows

For multi-agent environments (e.g., with agentic-research-orchestration):

- Always use `-n <notebook_id>` or `--notebook <notebook_id>` instead of `notebooklm use`
- Use full UUIDs to avoid ambiguity
- Set unique `NOTEBOOKLM_HOME` per agent for isolation
- Use `--new` flag on `ask` commands to avoid conversation ID conflicts

## Wrapper Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `nlm-bulk-add.sh` | Add multiple sources | `./scripts/nlm-bulk-add.sh <notebook_id> <urls...>` |
| `nlm-research.sh` | Run deep web research | `./scripts/nlm-research.sh <notebook_id> "query"` |
| `nlm-generate.sh` | Generate artifacts | `./scripts/nlm-generate.sh -n <notebook_id> --all` |
| `nlm-download.sh` | Download artifacts | `./scripts/nlm-download.sh -n <notebook_id> -o ./output/` |

## Troubleshooting

- **Auth errors**: Run `notebooklm auth check --test` then `notebooklm login`
- **Rate limiting**: Wait 5-10 minutes and retry
- **Generation failed**: Check `notebooklm artifact list` for status, use web UI as fallback
- **No notebook context**: Use `-n <id>` flag instead of `notebooklm use`

## Reference

- [NotebookLM Web UI](https://notebooklm.google.com/)
- [notebooklm-py GitHub](https://github.com/teng-lin/notebooklm-py)
- [CLI Reference](./references/cli-reference.md)
- [Python API Reference](./references/python-api.md)
- [Configuration Guide](./references/configuration.md)
- [Troubleshooting](./references/troubleshooting.md)

## Security

- Auth tokens are stored locally in `~/.notebooklm/`
- Never commit auth files to version control
- Use `NOTEBOOKLM_AUTH_JSON` env var for CI/CD (from secrets)
- Set restrictive permissions: `chmod 600 ~/.notebooklm/storage_state.json`
