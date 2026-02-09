# GitHub PR Comment Handler

Systematically address review comments on GitHub pull requests using the GitHub CLI (`gh`).

## What It Does

- Fetches all comments and review threads from the current branch's open PR
- Presents comments in a numbered, organized format
- Lets you select which comments to address
- Applies fixes for selected review feedback
- Integrates with GitHub CLI for seamless authentication

All operations use the `gh` CLI tool for GitHub API access.

## Setup

### Prerequisites

1. **GitHub CLI installed:**
   ```bash
   # Check if gh is installed
   gh --version

   # Install if needed (Ubuntu/Debian)
   sudo apt install gh

   # Or download from https://cli.github.com/
   ```

2. **Authenticate with GitHub:**
   ```bash
   # First time only
   gh auth login

   # Verify authentication and scopes
   gh auth status
   ```

### Required Permissions

The `gh` CLI needs these scopes:
- `repo` - Full control of private repositories
- `workflow` - Update GitHub Action workflows

If authentication fails during usage, re-run:
```bash
gh auth login --scopes repo,workflow
```

## Usage Examples

### Basic Workflow

1. **Ensure you're on the PR branch:**
   ```bash
   git branch --show-current
   ```

2. **Invoke the skill:**
   Ask Claude: "Address the PR comments" or "Fix review feedback"

3. **Claude will:**
   - Run `scripts/fetch_comments.py` to get all comments
   - Number and summarize each review thread
   - Ask which comments you want to address
   - Apply fixes for selected items

### Example Interaction

```
User: "Address the PR comments"

Claude:
- Runs fetch_comments.py
- Shows numbered list of comments:

  1. [alice] Line 42 in api.py: Use async/await instead of callbacks
  2. [bob] Line 15 in README.md: Fix typo "teh" → "the"
  3. [alice] Line 89 in api.py: Add error handling for network failures

Claude: "Which comments would you like me to address? (e.g., 1,3)"

User: "1 and 3"

Claude: Applies fixes for comments 1 and 3
```

## How It Works

1. **Fetch Comments** - `scripts/fetch_comments.py` uses `gh api` to get PR comments
2. **Present Summary** - Claude numbers and summarizes each review thread
3. **User Selection** - You choose which comments to address
4. **Apply Fixes** - Claude implements changes for selected feedback

## Troubleshooting

### "gh: command not found"

Install GitHub CLI:
```bash
# Ubuntu/Debian
sudo apt install gh

# macOS
brew install gh

# Or download from https://cli.github.com/
```

### "gh auth status" fails

Re-authenticate with proper scopes:
```bash
gh auth login --scopes repo,workflow
gh auth status
```

### "No pull request found for current branch"

Ensure:
1. You're on a branch (not `main`)
2. The branch has an open PR
3. You're in a git repository

Check with:
```bash
git branch --show-current
gh pr status
```

### Rate limiting errors

Wait a few minutes or authenticate to increase rate limits:
```bash
gh auth login
```

## Notes

- Requires active internet connection for GitHub API
- Works with both public and private repositories
- Respects GitHub API rate limits
- Uses elevated network access for `gh` commands
- Comments are read-only until you select which to address

## Reference

- **GitHub CLI Docs:** https://cli.github.com/manual/
- **GitHub API:** https://docs.github.com/en/rest
- **PR Review API:** https://docs.github.com/en/rest/pulls/reviews

---

**Version:** 1.1.0
**Type:** Read-Write (Safe)
**Dependencies:** GitHub CLI (`gh`), Python 3
