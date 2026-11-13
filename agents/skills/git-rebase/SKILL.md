---
name: git-rebase
description: Use when rebasing, rewriting history, resolving rebase conflicts, or force-pushing.
---

# git-rebase

1. Rebase only your own unpushed work, or a branch the user explicitly authorized.
2. Never force-push the default branch.
3. Fetch first: `git fetch <remote>`.
4. Start: `git rebase <base>`.
5. Resolve one file at a time. After each: `git add <path>` then `git rebase --continue`.
6. When a base changed, skip commit-and-revert pairs that cancel each other with `git rebase --skip`. Do not resolve their conflicts: replaying the revert can erase the new base's changes to those files.
7. Abort with `git rebase --abort` if the result is wrong.
8. Verify the final delta: `git diff --stat <base>..HEAD`.
9. Force-push only with `git push --force-with-lease <remote> <branch>` and only after the delta is verified.
