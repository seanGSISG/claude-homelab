Stage, commit, and push current work safely — with version bump, changelog update, and session capture.

## Workflow

### 1. Orient
- Detect current branch. If on `main` or `master`, create a descriptive feature branch based on the changes.
- Run `git diff --stat HEAD` to understand the scope of changes.
- Run `git log --oneline -5` to understand recent commit conventions.

### 2. Bump version (before staging)

Detect the project type and bump the version based on the commit message you'll generate:

**Detection order** (use the first match):
1. `Cargo.toml` → Rust project → bump `version = "X.Y.Z"` in `[package]`
2. `package.json` → Node project → bump `"version": "X.Y.Z"`
3. `pyproject.toml` → Python project → bump `version = "X.Y.Z"` in `[project]`

**Bump rules** (based on the commit message prefix you'll draft in step 4):
- `feat!:` or `BREAKING CHANGE` → **major** (X+1.0.0)
- `feat` or `feat(...)` → **minor** (X.Y+1.0)
- Everything else (`fix`, `chore`, `refactor`, `test`, `docs`, etc.) → **patch** (X.Y.Z+1)

**Process:**
1. Read the current version from the manifest
2. Draft the commit message mentally (you'll finalize it in step 4)
3. Determine bump type from the commit prefix
4. Calculate the new version
5. Edit the manifest file with the new version
6. If Rust: run `cargo check` to update `Cargo.lock` (it records the version)
7. Report: `Version: X.Y.Z → A.B.C (bump type)`

**Skip conditions:**
- Version is `0.0.0` or `0.0.1` (project not yet versioned)
- No manifest file found
- The `--no-bump` flag was passed as a skill argument

### 3. Update CHANGELOG.md (before staging)
If a `CHANGELOG.md` exists in the repo root:
- Find the most recently documented commit SHA in the changelog table.
- Run `git log --oneline <last_sha>..HEAD` to find undocumented commits.
- If there are new commits, update the changelog:
  - Add new rows to the commit summary table (newest first).
  - Update the Highlights section with grouped summaries.
  - Keep existing structure and style.
- If no CHANGELOG.md exists, skip this step.

### 4. Stage, commit, push
- Stage all changes with `git add .`.
- Create a meaningful commit message following repository conventions.
- Always include co-authorship: `Co-authored-by: Claude <noreply@anthropic.com>`
- Push:
  - New branch: `git push -u origin <branch>`
  - Existing branch: `git push`

### 5. Post-push: save session context
After push succeeds, save a session markdown doc to `docs/sessions/YYYY-MM-DD-description.md`,
embed it into Qdrant via `axon embed`, and capture to Neo4j memory.

When writing Neo4j entities/relations, always include:

**Entities:**
- One `commit` entity per SHA pushed (observations: SHA, message, branch, files changed)
- A `repository` entity for the repo (observations: remote URL, branch)
- A `session_doc` entity for the session markdown (observations: file path, Qdrant collection, embed job ID)

**Relations:**
- `commit → repository : PUSHED_TO`
- `commit → session_doc : DOCUMENTED_IN`
- `session_doc → repository : BELONGS_TO`
- `commit → commit : PRECEDED_BY` (chain in push order, newest → oldest)

## Constraints
- Never force push.
- Do not rewrite history.
- If no changes are staged, report and stop.
- The version bump and changelog update ride in the same commit as the code changes.

## Return
- Branch name and whether it was newly created
- Version bump applied (old → new, bump type) or skipped reason
- Each commit hash and message pushed
- Push destination
- Session doc path and Qdrant embed job ID
