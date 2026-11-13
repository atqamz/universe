---
name: git-merge
description: Use when merging one local branch into another or resolving merge conflicts.
---

# git-merge

1. Start from a clean worktree: `git status --short` prints nothing.
2. Fetch the remote base: `git fetch <remote>`.
3. Switch to the receiving branch and fast-forward it: `git switch <target>` then `git merge --ff-only <remote>/<target>`.
4. Merge the other branch with `git merge --no-ff <branch>` unless the repository convention says otherwise.
5. Resolve conflicts file by file. Never resolve by taking one side wholesale.
6. After resolving: `git add <path>`, then `git commit` if the merge stopped.
7. Abort with `git merge --abort` if the result is wrong.
8. Never merge the default branch into a feature branch just to update it. Rebase instead.

Verify with `git log --oneline --graph -5` and `git diff --stat <base>..HEAD`.
