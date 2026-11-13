---
name: git-recovery
description: Use when recovering lost commits, undoing a reset, rebase, or merge, or inspecting the reflog.
---

# git-recovery

1. Inspect first: `git reflog --date=iso`.
2. Restore a lost commit on a branch: `git branch <name> <reflog-commit>`.
3. Undo a reset: save the current state first, then `git reset --hard <reflog-commit>`.
4. Undo a rebase: find the pre-rebase reflog entry and reset to it.
5. Undo a merge: `git reset --hard ORIG_HEAD`.
6. Find unreachable objects: `git fsck --lost-found`.
7. Never run `git gc --prune=now` while recovering.
8. Verify the recovered tree with `git show --stat <commit>` before continuing.
