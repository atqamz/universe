---
name: git-remotes
description: Use when adding, changing, fetching, or removing Git remotes or upstream tracking.
---

# git-remotes

1. List: `git remote -v`.
2. Add: `git remote add <name> <url>`.
3. Change a URL: `git remote set-url <name> <url>`.
4. Fetch and prune: `git fetch --prune <name>`.
5. Set upstream: `git branch --set-upstream-to=<remote>/<branch>`.
6. Remove: `git remote remove <name>`.
7. Never rewrite a shared remote URL or remove a remote without explicit authorization.

Verify with `git remote -v` and `git branch -vv`.
