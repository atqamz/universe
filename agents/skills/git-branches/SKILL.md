---
name: git-branches
description: Use when creating, naming, switching, renaming, or deleting local or remote branches.
---

# git-branches

1. Start from the default branch: `git switch <default>` then `git pull --ff-only`.
2. Name issue branches `<issue-number>-<slug>`. Name other branches `<slug>`.
3. Do not create an issue only to name a branch.
4. Follow the upstream repository's branch convention when it has one.
5. Create: `git switch -c <branch> <base>`.
6. Rename: `git branch -m <new-name>`.
7. Delete a merged local branch: `git branch -d <branch>`.
8. Delete a remote branch: `git push <remote> --delete <branch>`.
9. Merge promptly. Do not keep long-lived branches.

Verify with `git branch -vv`: the branch has the expected name, base, and upstream.
