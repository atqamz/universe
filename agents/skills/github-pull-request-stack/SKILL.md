---
name: github-pull-request-stack
description: Use when creating, syncing, checking out, rebasing, or merging a GitHub pull request stack with gh stack.
---

# github-pull-request-stack

1. Use the `gh stack` extension. Do not build a stack with repeated `gh pr create --base`.
2. Initialize: `gh stack init <branch>...` or `gh stack init --base <base> <branch>`.
3. Add a layer: `gh stack add <branch>` or `gh stack add -Am "<message>" <branch>`.
4. Submit: `gh stack submit`; use `gh stack submit --auto` in non-interactive runs.
5. Check out: `gh stack checkout <stack-number|pr-number|pr-url|branch>`.
6. Sync: `gh stack sync`.
7. Rebase: `gh stack rebase`; after conflicts, `gh stack rebase --continue` or `gh stack rebase --abort`.
8. View: `gh stack view --short` or `gh stack view --json`.
9. Merge: `gh stack merge <stack-number|pr-number> --yes --squash`.
10. Merge bottom-up. Let GitHub retarget bases. Do not rebase each layer and wait for checks again.
11. Link every pull request to the tracking issue as the template requires, and record direct dependencies with `Depends on:`.
12. Put a closing relationship only on the pull request whose merge completes the issue, unless the user explicitly requests every layer.

Verify with `gh stack view --json` and `gh issue view <N> --json state`.
