---
allowed-tools: Bash, TodoWrite
description: Git add all, commit with Claude, and push to current/new feature branch
---

## Context

- Current branch: !`git branch --show-current`
- Git status: !`git status --short`
- Remote info: !`git remote -v | head -1`

## Your task

1. Check if we're on a feature branch (not main/master)
2. If on main/master, create a new feature branch with a descriptive name based on the changes
3. Stage all changes with `git add .`
4. Create a meaningful commit message following the repo's conventions
5. Push to remote (use -u flag if it's a new branch)

Important:
- Always create the commit with Claude's co-authorship signature
- If creating a new branch, name it based on the changes (e.g., feat/add-user-auth, fix/navbar-styling)
- Use `git push -u origin <branch>` for new branches
- Use `git push` for existing branches

End with a summary of what was pushed and the branch name.