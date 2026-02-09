# GitHub PR Comments - Quick Reference

Common commands and patterns for addressing PR comments.

## Quick Commands

### Check PR Status

```bash
# View current branch's PR
gh pr view

# Show PR status
gh pr status

# Get PR number
gh pr view --json number --jq '.number'
```

---

### View Comments

```bash
# View all comments in PR
gh pr view --comments

# View PR diff
gh pr diff

# View specific file diff
gh pr diff -- src/api.py
```

---

### Fetch Comments (Script)

```bash
# Run fetch script
python3 scripts/fetch_comments.py

# Output:
# 1. [alice] Line 42 in api.py: Use async/await
# 2. [bob] Line 15 in README.md: Fix typo
```

---

## Common Workflows

### Address Review Feedback

1. **Fetch comments:**
   ```bash
   python3 scripts/fetch_comments.py
   ```

2. **Read numbered list of comments**

3. **Apply fixes for selected comments**

4. **Commit changes:**
   ```bash
   git add -A
   git commit -m "Address PR feedback: Fix items 1, 3, 5"
   git push
   ```

5. **Reply to comments:**
   ```bash
   gh pr comment --body "Fixed in latest commit"
   ```

---

### Approve After Fixes

```bash
# After addressing all comments
gh pr review --approve --body "All issues addressed, LGTM!"
```

---

### Request More Changes

```bash
gh pr review --request-changes --body "Please also update the tests"
```

---

## Comment Patterns

### Line-Specific Comments

Review comments have these fields:
- `path` - File path
- `line` - Line number
- `body` - Comment text
- `user.login` - Reviewer username

**Example:**
```
File: src/api.py
Line: 42
User: alice
Comment: "Use async/await instead of callbacks for better readability"
```

---

### General Comments

Issue comments (not line-specific):
- `body` - Comment text
- `user.login` - Commenter username

**Example:**
```
User: bob
Comment: "Great work! Just a few minor suggestions below."
```

---

## Authentication Quick Check

```bash
# Check if authenticated
gh auth status

# If not, login
gh auth login --scopes repo,workflow

# Verify scopes
gh auth status
```

---

## Parsing Comments (Python Example)

```python
import subprocess
import json

# Get PR number
pr_info = subprocess.run(
    ["gh", "pr", "view", "--json", "number"],
    capture_output=True,
    text=True,
    check=True
)
pr_number = json.loads(pr_info.stdout)["number"]

# Get repository info
repo_info = subprocess.run(
    ["gh", "repo", "view", "--json", "owner,name"],
    capture_output=True,
    text=True,
    check=True
)
repo = json.loads(repo_info.stdout)
owner = repo["owner"]["login"]
name = repo["name"]

# Fetch review comments
comments = subprocess.run(
    ["gh", "api", f"repos/{owner}/{name}/pulls/{pr_number}/comments"],
    capture_output=True,
    text=True,
    check=True
)
review_comments = json.loads(comments.stdout)

# Print numbered list
for i, comment in enumerate(review_comments, 1):
    user = comment["user"]["login"]
    path = comment["path"]
    line = comment.get("line", "N/A")
    body = comment["body"].split('\n')[0]  # First line only
    print(f"{i}. [{user}] Line {line} in {path}: {body}")
```

---

## Error Recovery

### PR Not Found

```bash
# Check if you're on a branch with PR
git branch --show-current

# Check PR status
gh pr status

# Create PR if needed
gh pr create
```

---

### Auth Issues

```bash
# Re-authenticate
gh auth login --scopes repo,workflow

# Force refresh token
gh auth refresh
```

---

### Rate Limiting

```bash
# Check rate limit status
gh api rate_limit

# Wait if limit exceeded, or:
# - Authenticate for higher limits
# - Cache API responses
```

---

## Bash Shortcuts

### Get PR URL

```bash
gh pr view --json url --jq '.url'
```

---

### Get Comment Count

```bash
gh pr view --json comments --jq '.comments | length'
```

---

### Get PR Author

```bash
gh pr view --json author --jq '.author.login'
```

---

### Check PR State

```bash
gh pr view --json state --jq '.state'
```

---

## Complete Example Workflow

```bash
#!/bin/bash
set -euo pipefail

echo "=== Addressing PR Comments ==="

# 1. Check authentication
if ! gh auth status &>/dev/null; then
    echo "Not authenticated. Please run: gh auth login"
    exit 1
fi

# 2. Fetch PR info
echo "Fetching PR information..."
PR_NUM=$(gh pr view --json number --jq '.number')
PR_TITLE=$(gh pr view --json title --jq '.title')
echo "PR #$PR_NUM: $PR_TITLE"

# 3. Fetch and display comments
echo -e "\nFetching comments..."
python3 scripts/fetch_comments.py

# 4. User selects comments to address
read -p "Which comments to address? (e.g., 1,3,5): " SELECTED

# 5. Apply fixes (manual or automated)
echo "Applying fixes for selected comments..."
# ... implementation-specific ...

# 6. Commit and push
git add -A
git commit -m "Address PR comments: #$SELECTED"
git push

# 7. Reply to addressed comments
gh pr comment --body "Fixed issues #$SELECTED in latest commit"

echo "✅ Comments addressed successfully!"
```

---

## Tips

- **Always fetch fresh comments** - Don't work from stale comment list
- **Number your fixes** - Reference comment numbers in commit messages
- **Reply when done** - Let reviewers know issues are addressed
- **Test before pushing** - Ensure fixes actually work
- **Group related fixes** - One commit per logical group of changes

---

**Quick Reference Card:**

| Task | Command |
|------|---------|
| View PR | `gh pr view` |
| View comments | `gh pr view --comments` |
| View diff | `gh pr diff` |
| Fetch comments | `python3 scripts/fetch_comments.py` |
| Add comment | `gh pr comment --body "text"` |
| Approve PR | `gh pr review --approve` |
| Request changes | `gh pr review --request-changes` |
| Check auth | `gh auth status` |
| Login | `gh auth login` |

---

**Remember:** Always address the root cause, not just the symptom mentioned in the comment!
