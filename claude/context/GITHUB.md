# GitHub

- `gh` CLI for all GitHub ops (PR, issue, checks, release, API). No raw `curl`, no web UI.
- PR create: push `-u`, then `gh pr create`. Title <70 chars. Body: `## Summary` (1-3 bullets), `Fixes #N` if applies, `## Test plan`.
- Cross-repo ref: `<org>/<repo>#<number>`.
- Inspect: `gh pr view`, `gh pr checks`, `gh pr diff`.
- Issue: `gh issue view`, `gh issue list`, `gh issue create`.
- Alias: `gh co <number>` = `gh pr checkout`.
- Assignee `atqamz` every PR/issue (`--assignee atqamz`).
- Merge `gh pr merge --merge` only. No squash/rebase.
- No planning jargon in issue/PR title/body. Say work done.
- Post-merge: delete remote branch (`gh pr merge --delete-branch` or `git push origin --delete <branch>`), `git worktree remove <path>`, `git branch -d <branch>`.
