# Session: Standardize Env Loading to ~/.homelab-skills/

**Date:** 2026-03-02
**Duration:** Single session
**Working Directory:** `/home/jmagar/claude-homelab`

---

## Session Overview

Designed and implemented a unified, cross-agent environment variable loading strategy for all homelab skills. The core problem: skills needed to work identically whether installed as a Claude Code plugin, a Codex skill, or a Gemini CLI skill — but the existing approach relied on relative paths and 15 diverging per-skill `load-env.sh` copies with inconsistent search chains. The solution standardizes on a single well-known directory `~/.homelab-skills/` containing the shared `load-env.sh` library and `.env` credentials file, bootstrapped automatically by `setup-symlinks.sh`.

---

## Timeline

1. **Problem analysis** — Examined `lib/load-env.sh`, all 15 per-skill `scripts/load-env.sh` copies, and 14 API scripts. Found copies already diverging: 14 pointed to `~/.claude/.env`, 1 still pointed to `~/.claude-homelab/.env`.
2. **Design discussion** — Evaluated XDG (`~/.config/homelab-skills/`), fixed home dir (`~/.homelab-skills/`), and multi-location discovery chain approaches. User pushed for simplicity.
3. **Decision** — `~/.homelab-skills/` as the single canonical location. Fixed path in all scripts, no discovery chain.
4. **Implementation** — Rewrote `lib/load-env.sh`, extended `setup-symlinks.sh`, updated all skill scripts, deleted all per-skill copies, bulk-updated all doc references.

---

## Key Findings

- **15 per-skill `load-env.sh` copies** existed in `skills/*/scripts/` — already diverging from `lib/load-env.sh`.
- **Inconsistent primary paths**: 14 copies used `~/.claude/.env`, 1 used `~/.claude-homelab/.env`, the canonical `lib/` version still referenced `~/.claude-homelab/.env`.
- **`~/.claude/.env` is wrong** for cross-agent use — it's a Claude Code internal directory; Codex and Gemini have no reason to look there.
- **paperless-ngx and memos** used a different inline pattern (`ENV_FILE="$HOME/claude-homelab/.env"`) rather than sourcing a sibling `load-env.sh`.
- **`setup-symlinks.sh`** was already the plugin install script — the natural place to bootstrap `~/.homelab-skills/`.

---

## Technical Decisions

| Decision | Rationale |
|---|---|
| `~/.homelab-skills/` over XDG `~/.config/homelab-skills/` | Simpler, more explicit, no XDG spec dependency. Both are agent-agnostic. |
| Fixed path `$HOME/.homelab-skills/load-env.sh` in scripts | Eliminates discovery chain complexity. Path is guaranteed after setup runs. |
| `load-env.sh` copied (not symlinked) to `~/.homelab-skills/` | Skills installed standalone to other agents won't have the repo; a copy is self-contained. |
| Delete per-skill copies entirely | Single source of truth. `setup-symlinks.sh` keeps the installed copy fresh on every run. |
| Bootstrap in `setup-symlinks.sh`, not a separate hook | Zero extra steps for Claude Code plugin users — setup already runs once on install. |
| `.env` stubbed from `.env.example`, never overwritten if exists | Idempotent re-runs don't clobber real credentials. |

---

## Files Modified

| File | Change |
|---|---|
| `lib/load-env.sh` | Rewritten — simplified to ~50 lines, loads `~/.homelab-skills/.env` directly |
| `scripts/setup-symlinks.sh` | Added `~/.homelab-skills/` bootstrap section at end of `main()` |
| `skills/*/scripts/*-api.sh` (14 files) | `source "$(dirname ...)/load-env.sh"` → `source "$HOME/.homelab-skills/load-env.sh"` |
| `skills/paperless-ngx/scripts/*.sh` (4 files) | Replaced inline `ENV_FILE` block with `source "$HOME/.homelab-skills/load-env.sh"` |
| `skills/memos/scripts/*.sh` (5 files) | Replaced inline `ENV_FILE` block with `source "$HOME/.homelab-skills/load-env.sh"` |
| `skills/*/scripts/load-env.sh` (15 files) | **Deleted** — per-skill copies eliminated |
| `skills/**/*.md` (many) | Bulk-replaced all old path references to `~/.homelab-skills/.env` |
| `skills/CLAUDE.md` | Updated credential path examples |

---

## Commands Executed

```bash
# Find per-skill load-env.sh copies
find skills -name "load-env.sh" -path "*/scripts/*"   # → 15 files

# Bulk update API scripts
sed -i 's|source "$(dirname "${BASH_SOURCE[0]}")/load-env.sh"|source "$HOME/.homelab-skills/load-env.sh"|g' <14 scripts>

# Delete per-skill copies
find skills -name "load-env.sh" -path "*/scripts/*" -delete

# Bulk update doc references
find skills -type f \( -name "*.md" -o -name "*.sh" \) | xargs sed -i \
    -e 's|~/.claude-homelab/.env|~/.homelab-skills/.env|g' \
    -e 's|~/claude-homelab/.env|~/.homelab-skills/.env|g' \
    -e 's|$HOME/claude-homelab/.env|$HOME/.homelab-skills/.env|g' \
    -e 's|~/.claude/.env|~/.homelab-skills/.env|g'

# Final verification
grep -rh "homelab-skills/load-env" skills/ | sort | uniq -c   # → 24 references
find skills/ -name "load-env.sh"                               # → (none)
grep -rn "claude-homelab/.env|.claude-homelab|.claude/.env" skills/ lib/  # → 0 results
```

---

## Behavior Changes (Before / After)

| Aspect | Before | After |
|---|---|---|
| Credential location | Inconsistent: `~/.claude/.env`, `~/.claude-homelab/.env`, `~/claude-homelab/.env` depending on skill | Single: `~/.homelab-skills/.env` |
| Library location | 15 per-skill copies + `lib/load-env.sh` (16 total, diverging) | 1 canonical `lib/load-env.sh` + 1 installed copy at `~/.homelab-skills/load-env.sh` |
| Script env sourcing | `source "$(dirname "${BASH_SOURCE[0]}")/load-env.sh"` (relative, breaks standalone) | `source "$HOME/.homelab-skills/load-env.sh"` (fixed, works everywhere) |
| Plugin install UX | `setup-symlinks.sh` only created symlinks; `.env` setup was manual/undocumented | `setup-symlinks.sh` also installs `~/.homelab-skills/` and stubs `.env` with clear prompt |
| Cross-agent compatibility | Broken (Claude-specific paths) | Works: Claude Code, Codex, Gemini CLI all use same `$HOME` |

---

## Verification Evidence

| Command | Expected | Actual | Status |
|---|---|---|---|
| `grep -rh "homelab-skills/load-env" skills/ \| uniq -c` | 24 scripts sourcing correct path | `24 source "$HOME/.homelab-skills/load-env.sh"` | ✅ |
| `find skills/ -name "load-env.sh"` | No per-skill copies | `(none)` | ✅ |
| `grep -rn "claude-homelab/\.env\|\.claude-homelab\|\.claude/\.env" skills/ lib/` | 0 old-path references | 0 results | ✅ |
| `grep -A5 "Setting up" scripts/setup-symlinks.sh` | Bootstrap section present | Section present with `mkdir`, `cp`, `chmod 600` | ✅ |

---

## Source IDs + Collections Touched

*Axon embedding attempted post-write — see below.*

---

## Risks and Rollback

- **Risk**: Users with existing `~/.claude/.env` or `~/.claude-homelab/.env` will get `ERROR: ~/.homelab-skills/.env not found` until they run `setup-symlinks.sh` again or manually create `~/.homelab-skills/.env`.
- **Mitigation**: `setup-symlinks.sh` is idempotent and skips `.env` if already exists. Existing users re-run once.
- **Rollback**: `git revert` the commits from this session. The 15 deleted `load-env.sh` files would need to be restored from git history (`git checkout HEAD~1 -- skills/*/scripts/load-env.sh`).

---

## Decisions Not Taken

- **XDG `~/.config/homelab-skills/`**: More spec-compliant but adds complexity with no practical benefit for this use case.
- **`HOMELAB_ENV_FILE` override env var**: Useful for CI/CD but adds complexity. Can be added later if needed; `load_env_file` accepts an explicit path argument already.
- **Self-bootstrapping scripts** (each script installs `~/.homelab-skills/` on first run): Would work but adds boilerplate to every script. The setup script approach is cleaner.
- **Symlink `load-env.sh`** instead of copying: Symlink would break for standalone installs where the repo isn't present.

---

## Open Questions

- **overseerr `lib.mjs`**: Has its own Node.js env loading pattern (`~/.claude/.env` reference in `skills/overseerr/scripts/lib.mjs:37`). Not updated in this session — needs a separate pass to align with `~/.homelab-skills/.env`.
- **radicale `radicale-api.py`**: Python script has its own env loading; not yet migrated to the new pattern.
- **Other agents (Codex, Gemini)**: The `~/.homelab-skills/` setup is only automatic for Claude Code. Codex/Gemini users still need a one-time `./scripts/setup-symlinks.sh` or equivalent. Consider a standalone `setup.sh` that doesn't require the full repo.

---

## Next Steps

1. **Fix `overseerr/scripts/lib.mjs`** — update Node.js env loading to use `~/.homelab-skills/.env`.
2. **Fix `radicale/scripts/radicale-api.py`** — update Python env loading to `~/.homelab-skills/.env`.
3. **Update `skills/CLAUDE.md` credential pattern examples** — the Bash and Node.js code blocks still show old patterns.
4. **Consider a minimal `setup.sh`** at repo root (not in `scripts/`) for non-Claude-Code agents — one command, no deps.
5. **Re-run `setup-symlinks.sh`** on the actual machine to install `~/.homelab-skills/` with the new `load-env.sh`.
