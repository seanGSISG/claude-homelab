# Session: Codex Prompts Symlinks

**Date:** 2026-03-03
**Duration:** ~2 minutes
**Scope:** Symlink homelab prompts into Codex prompts directory

## Session Overview

Symlinked all `.md` files from `~/claude-homelab/prompts/` to `~/.codex/prompts/` so Codex can discover homelab prompt commands.

## Timeline

1. Listed source (`~/claude-homelab/prompts/`) and target (`~/.codex/prompts/`) directories
2. Created symlinks for all 4 `.md` files

## Key Findings

- `~/.codex/prompts/` already contained Axon-related symlinks (pointing to `/home/jmagar/workspace/axon_rust/commands/codex/`)
- Four homelab prompts available: `catch-up.md`, `check.md`, `quick-push.md`, `save-to-md.md`

## Files Modified

| File | Action | Purpose |
|------|--------|---------|
| `~/.codex/prompts/catch-up.md` | Symlink created | Points to `~/claude-homelab/prompts/catch-up.md` |
| `~/.codex/prompts/check.md` | Symlink created | Points to `~/claude-homelab/prompts/check.md` |
| `~/.codex/prompts/quick-push.md` | Symlink created | Points to `~/claude-homelab/prompts/quick-push.md` |
| `~/.codex/prompts/save-to-md.md` | Symlink created | Points to `~/claude-homelab/prompts/save-to-md.md` |

## Commands Executed

| Command | Result |
|---------|--------|
| `ls ~/claude-homelab/prompts/` | 4 `.md` files found |
| `ls -la ~/.codex/prompts/` | Existing Axon symlinks present |
| `ln -sf` loop | All 4 symlinks created successfully |

## Behavior Changes (Before/After)

| Before | After |
|--------|-------|
| Codex had no homelab prompts | Codex can discover `catch-up`, `check`, `quick-push`, `save-to-md` prompts |

## Verification Evidence

| Command | Expected | Actual | Status |
|---------|----------|--------|--------|
| `ln -sf` for each .md | Symlink created | "Linked: filename.md" x4 | PASS |

## Risks and Rollback

- **Risk:** Minimal — symlinks only, no data modified
- **Rollback:** `rm ~/.codex/prompts/{catch-up,check,quick-push,save-to-md}.md`

## Open Questions

- None

## Next Steps

- None — task complete
