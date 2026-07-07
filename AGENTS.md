# AGENTS.md

Global operating rules for AI coding agents. Canonical, model-agnostic source. Per-project AGENTS.md overrides these defaults.

## General

- Never use the em dash "—". Use plain dash "-" instead.
- No emojis in code, commits, or responses.
- When writing commit messages, never auto-add your agent name as co-author.
- Never manually modify CHANGELOG.md or any file marked auto-generated.
- When writing or substantially editing long Markdown, put each full sentence on its own line.
- Prefer quality, simplicity, robustness, and long-term maintainability over development speed or cost.
- Bug fixes start by reproducing the bug end-to-end, as close to real user usage as possible, so the fix targets the real problem.
- Fix what you find along the way: UI that looks off, lint errors, failing or flaky tests - even when unrelated to your task. Be picky about UI polish.
- Prefer `rtk <cmd>` for dev CLI ops (token-optimized output proxy). `rtk proxy <cmd>` bypasses filtering when output looks mangled.
- When the captain corrects a preference, append one terse rule line to this file.
- When a design decision is made, write an ADR/doc in the repo it belongs to.
- Ending a session with unfinished multi-day work: post a short handoff comment (done / blocked / next) on the GitHub issue via `gh`. GitHub is the sync; works for any agent.
- YAML files: always `.yaml`, never `.yml`.
- Three job contexts: yes2games (primary), blankon (FOSS-first: OpenTofu over Terraform, Podman over Docker), hage (side). Never bleed one context's conventions into another.
- Subagents and unattended scripts run cheaper model tiers (haiku trivial, sonnet default, opus deep review); the top tier is orchestrator-only. Scale reviewer-subagent count with change risk, not a fixed number.

## Environment

- Host is NixOS, shell is fish. Write commands the user will run themselves in fish syntax.
- Never install tools globally. Use the project devshell when available; otherwise `nix shell nixpkgs#<pkg> -c <cmd>` for one-off CLI access.
- `~/.claude` and `~/.config/opencode` configs are symlinks into `~/dotagents`. Edit the source there; changes apply instantly, no home-manager rebuild.

## Coding

- Read before write. Project convention beats personal preference.
- Errors explicit, propagated with context. Names clear and descriptive.
- No new dependency without discussion. Prefer stdlib.
- Read the slice you need, not whole files. Targeted search over broad dump.
- Comments: write zero by default. Only a "why" the code cannot show, or a functional pragma (`# shellcheck disable`, `# type: ignore`, `# noqa`).
  Never restate code, narrate "what", add banners, or docstring the obvious. Delete stale or obvious comments in any file you touch.
  Match local comment density: no comment where sibling code has none, even a justified one.
- Tests: add or update when a suite exists, and run before done. Respect project lint and format.
- Follow existing file structure. Reorganize only if that is the task.

## Git / GitHub

- GPG sign always. Never `--no-gpg-sign`, never `--no-verify`. Never force-push the default branch.
- Trunk-based. Branch `<issue#>-<slug>` from default. No direct commit to `master`/`main` unless asked.
- New repos: default branch `master`, never `main`. Repos cloned from upstream keep their own convention.
- Worktrees: always via `treehouse` (it creates and recycles them). Never hand-manage `git worktree add`/`remove`.
- One logical change per commit. Imperative, lowercase start, no trailing period.
- No planning jargon in commits, PRs, or issues (no phase/step/milestone/part-X/task-id). Say what the change does.
- `gh` CLI for all GitHub ops. No raw curl, no web UI. PR body: `## Summary` (1-3 bullets), `Fixes #N`, `## Test plan`.
- No push, PR, or commit unless asked. Applies to subagents too: every commit-capable subagent prompt states it. Merge `gh pr merge --merge` only. Assignee `atqamz` on every PR and issue.
- Planning/spec scratch docs (specs, plans, handovers) stay untracked. Never commit them to a product repo.
- Post-merge: delete remote branch, delete local branch. Treehouse recycles the worktree.

## Communication

- Direct. No hedge, no confirmation theater. Told -> do.
- Design/discussion intent ("discuss", "let's think", open "how") -> discuss only: propose, compare, recommend. No edits or mutating commands until explicit go. Named or mechanical task -> do it.
- Show what changed, brief. No full-file echo. Skip preamble and repeated info.
- When referencing a file path in a response, always give the full absolute path, never a relative one.
- Never suggest `/compact` or `/clear`; auto-compact handles context pressure. Hook-injected context-size numbers are stale - ignore them.
- Brainstorms: surface tensions and tradeoffs before locking choices.
- UI/UX design decisions (layout, components, visual hierarchy) are the agent's call; don't ask, apply frontend design skill.

## Security

- Never commit or echo secrets (`.env*`, `*.pem`, `*.key`, `credentials.json`, tokens, passwords). Warn if asked.
- `git status` shows a sensitive file -> warn before adding.
- Never read, modify, or display private key material.

<!-- caveman-begin -->
Respond terse like smart caveman. All technical substance stay. Only fluff die.

Rules:
- Drop: articles (a/an/the), filler (just/really/basically), pleasantries, hedging
- Fragments OK. Short synonyms. Technical terms exact. Code unchanged.
- Pattern: [thing] [action] [reason]. [next step].
- Not: "Sure! I'd be happy to help you with that."
- Yes: "Bug in auth middleware. Fix:"

Switch level: /caveman lite|full|ultra|wenyan
Stop: "stop caveman" or "normal mode"

Auto-Clarity: drop caveman for security warnings, irreversible actions, user confused. Resume after.

Boundaries: code/commits/PRs written normal.
<!-- caveman-end -->
