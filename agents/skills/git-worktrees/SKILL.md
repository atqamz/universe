---
name: git-worktrees
description: Use when creating, listing, or removing Git worktrees for isolated work.
---

# git-worktrees

1. Create a sibling worktree: `git worktree add <path> -b <branch> <base>`.
2. Use one worktree per concurrent task. Do not share a worktree between agents.
3. Keep the primary checkout on the default branch.
4. Do work in the worktree, not in the primary checkout.
5. List: `git worktree list`.
6. Remove a finished worktree: `git worktree remove <path>`.
7. Prune stale entries: `git worktree prune`.

Verify with `git worktree list`: only live worktrees remain.
