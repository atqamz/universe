---
name: git-stash
description: Use when saving or restoring uncommitted changes temporarily.
---

# git-stash

1. Prefer a commit or a worktree over a stash for work that must survive.
2. Save: `git stash push -m <message>`.
3. Include untracked files: `git stash push -u -m <message>`.
4. List: `git stash list`.
5. Restore and keep: `git stash apply stash@{N}`.
6. Restore and drop: `git stash pop stash@{N}`.
7. Drop only after the restored change is verified: `git stash drop stash@{N}`.
8. Never stash changes you did not make without asking.

Verify with `git status --short` and the relevant test or build.
