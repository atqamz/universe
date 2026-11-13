---
name: git-commits
description: Use when staging changes or writing a commit.
---

# git-commits

1. Read the full diff before staging: `git diff` and `git status --short`.
2. Stage explicit paths. Do not use `git add -A` unless every change belongs to the commit.
3. Keep one self-contained change per commit. Separate refactors from features.
4. Write the subject in the imperative, lowercase first word, no trailing period.
5. Do not use planning terms such as phase, step, or milestone in the subject.
6. Put only what the code cannot carry in the body: why, measurements, external constraints, failure modes, manual steps. Wrap at 72 columns.
7. Never add a `Co-Authored-By` trailer or any attribution naming a model or tool.
8. Never bypass hooks, verification, or commit signing.
9. Commit: `git commit`.

Verify with `git show --stat --oneline HEAD` and `git status --short`: only the intended change is committed.
