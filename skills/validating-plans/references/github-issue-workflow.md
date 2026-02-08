# GitHub Issue Creation (Post-Validation)

After successful validation (✅ PASS or ⚠️ PASS WITH NOTES), offer to create a GitHub issue.

## Prerequisites Check

```bash
# Verify GitHub CLI installed
if ! command -v gh &>/dev/null; then
    echo "🔴 GitHub CLI not installed"
    echo "Install: https://cli.github.com/"
    exit 1
fi

# Verify gh authenticated
if ! gh auth status &>/dev/null; then
    echo "🔴 GitHub CLI not authenticated"
    echo "Run: gh auth login"
    exit 1
fi

# Detect repository from git remote
REPO_URL=$(git remote get-url origin 2>/dev/null)
if [[ -z "$REPO_URL" ]]; then
    echo "🔴 No git remote 'origin' found"
    exit 1
fi

# Extract owner/repo from URL
REPO=$(echo "$REPO_URL" | sed -E 's|.+github\.com[:/]([^/]+/[^/]+)(\.git)?$|\1|')
echo "📦 Repository: $REPO"
```

## User Confirmation Prompt

After validation passes:

```
✅ Validation Complete

**Plan:** `<plan-file-path>`
**Status:** PASS (ready for execution)

**Next Step: Create GitHub Issue**

Would you like to create a GitHub issue containing this validated plan?

The issue will include:
- Full plan content as issue body
- Label: "implementation-plan"
- Label: "validated"

Repository: <repo>

Create issue? (y/n):
```

## Issue Creation Logic

If user confirms (y):

```bash
#!/bin/bash
PLAN_FILE="$1"
REPO="$2"

# Extract plan title from header
PLAN_TITLE=$(grep -m1 '^# ' "$PLAN_FILE" | sed 's/^# //' | sed 's/ Implementation Plan$//')

# Read full plan content
PLAN_BODY=$(cat "$PLAN_FILE")

# Add validation metadata to issue body
ISSUE_BODY="**Validated Plan** ✅

Validation completed: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

---

$PLAN_BODY

---

**Validation Notes:**
- All file references verified
- Dependencies confirmed to exist
- TDD compliance checked
- Ready for implementation

**Implementation:**
Use \`/superpowers:executing-plans\` in Claude Code to execute this plan task-by-task.
"

# Create issue using gh CLI
echo "Creating GitHub issue..."

ISSUE_URL=$(gh issue create \
  --repo "$REPO" \
  --title "Implementation: $PLAN_TITLE" \
  --body "$ISSUE_BODY" \
  --label "implementation-plan" \
  --label "validated" \
  2>&1)

if [[ $? -eq 0 ]]; then
    echo "✅ GitHub issue created successfully!"
    echo "🔗 $ISSUE_URL"
else
    echo "🔴 Failed to create issue:"
    echo "$ISSUE_URL"
    exit 1
fi
```
