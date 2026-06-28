# AGENTS.md

Global operating rules for AI coding agents. Canonical, model-agnostic source. Per-project AGENTS.md overrides these defaults.

## General

- Never use the em dash "—". Use plain dash "-" instead.
- No emojis in code, commits, or responses.
- When writing commit messages, never auto-add your agent name as co-author.
- Never manually modify CHANGELOG.md or any file marked auto-generated.
- When writing or substantially editing long Markdown, put each full sentence on its own line.
  Preserve normal Markdown structure, but avoid wrapping multiple sentences onto one physical line.
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- When doing bug fixes, always start by reproducing the bug in an E2E setting as closely aligned to real end-user usage as possible.
  This makes sure you find the real problem so your fix actually solves it.
- When end-to-end testing a product, be picky about the UI and obsessed with pixel perfection.
  If something clearly looks off, even if not directly related to your task, try to get it fixed along the way.
- Apply that same high standard to engineering excellence: lint, test failures, and test flakiness.
  If you see one, even if not caused by your current work, still get it fixed.
- Prefer `rtk <cmd>` for dev CLI ops when available (token-optimized proxy).

## Coding

- Read before write. Project convention beats personal preference.
- Errors explicit, propagated with context. Names clear and descriptive.
- No new dependency without discussion. Prefer stdlib.
- Read the slice you need, not whole files. Targeted search over broad dump.
- Comments: write zero by default. Only a "why" the code cannot show, or a functional pragma (`# shellcheck disable`, `# type: ignore`, `# noqa`).
  Never restate code, narrate "what", add banners, or docstring the obvious. Delete stale or obvious comments in any file you touch.
- Tests: add or update when a suite exists, and run before done. Respect project lint and format.
- Follow existing file structure. Reorganize only if that is the task.

## Git / GitHub

- GPG sign always. Never `--no-gpg-sign`, never `--no-verify`. Never force-push the default branch.
- Trunk-based. Branch `<issue#>-<slug>` from default. No direct commit to `master`/`main` unless asked.
- Worktrees: always via `treehouse` (it creates and recycles them). Never hand-manage `git worktree add`/`remove`.
- One logical change per commit. Imperative, lowercase start, no trailing period.
- No planning jargon in commits, PRs, or issues (no phase/step/milestone/part-X/task-id). Say what the change does.
- `gh` CLI for all GitHub ops. No raw curl, no web UI. PR body: `## Summary` (1-3 bullets), `Fixes #N`, `## Test plan`.
- No push, PR, or commit unless asked. Merge `gh pr merge --merge` only. Assignee `atqamz` on every PR and issue.
- Post-merge: delete remote branch, delete local branch. Treehouse recycles the worktree.

## Communication

- Direct. No hedge, no confirmation theater. Told -> do.
- Design/discussion intent ("discuss", "let's think", open "how") -> discuss only: propose, compare, recommend. No edits or mutating commands until explicit go. Named or mechanical task -> do it.
- Show what changed, brief. No full-file echo. Skip preamble and repeated info.

## Security

- Never commit or echo secrets (`.env*`, `*.pem`, `*.key`, `credentials.json`, tokens, passwords). Warn if asked.
- `git status` shows a sensitive file -> warn before adding.
- Never read, modify, or display private key material.

## Memory

- Canonical memory is `~/brain` (git, auto-pulled). Don't write per-project memory.
- Recall: read `~/brain/index.md`, open the matching `notes/<slug>.md`, cite it. Use `brain-recall <query>` when available. Don't bulk-read.
- `notes/` is canon. `log/` is append-only provenance (a Stop hook writes it; don't hand-write). Canon changes via reviewed PR only.
