# AGENTS.md

Global operating rules for AI coding agents. Canonical, model-agnostic source. Per-project AGENTS.md overrides.

## General

- Never use em dash "—", use plain "-". No emojis in code, commits, responses.
- Never auto-add agent name as commit co-author.
- Never hand-edit CHANGELOG.md or any auto-generated file.
- Long Markdown: each full sentence on own line.
- Prefer quality, simplicity, robustness, long-term maintainability over dev speed or cost.
- Be OCD about tidiness: unify duplicated patterns, keep code and files clear, organized. No over-engineering or acrobatics; simplest clear form wins.
- Bug fixes: reproduce end-to-end, close to real usage, so fix targets the real problem.
- Fix what you find along the way: off-looking UI, lint errors, failing/flaky tests, even unrelated. Be picky about UI polish.
- Prefer `rtk <cmd>` for dev CLI ops (token-optimized output proxy); `rtk proxy <cmd>` bypasses filtering when output mangled. Claude Code and OpenCode route shell commands through rtk automatically; in Codex there is no hook, so type `rtk <cmd>` yourself.
- Captain corrects a preference -> append one terse rule line to this file.
- Design decision made -> write ADR/doc in the repo it belongs to.
- Session ends with unfinished multi-day work -> post short handoff comment (done / blocked / next) on GitHub issue via `gh`. GitHub is the sync; works for any agent.
- YAML files: always `.yaml`, never `.yml`.
- Four profiles: atqamz (personal, own repos), yes2games (primary job; org work authenticates as the butler GitHub App, and yes2infra / yes2github operations run through GitHub Actions since no creds are held locally), blankon (FOSS-first: OpenTofu over Terraform, Podman over Docker), hage (side). Never bleed one profile's conventions into another.
- Google Workspace via `gw`: personal profile = atqamz@gmail.com, work profile = atqa@yes2games.com; always pass an explicit profile, never guess one for a write.
- Personal Google Workspace profile covers Gmail, Calendar, Tasks; work adds Chat and Keep only when Workspace/admin authorization permits - never assume a consumer Gmail account exposes those APIs.
- Subagents and unattended scripts run cheaper model tiers (haiku trivial, sonnet default, opus deep review); top tier orchestrator-only. Scale reviewer-subagent count with change risk, not a fixed number.
- Opus tier means `claude-opus-5`. Never pin an older opus point release.
- Use skills when relevant; run process skills (brainstorming, systematic-debugging) before implementation skills.
- Check full detail of issue (body, comments, linked PRs) before asking questions. Never re-ask what was already decided.
- Tool routing: `codedb` for source code navigation - search, symbols, callers, task-shaped code context. `qmd` for durable documentation and knowledge. Native harness file tools for every edit; neither `codedb` nor `qmd` writes files.
- Never point `codedb` at a home directory, config directory, session/log directory, or any other non-code root. Point it at a repository working tree.
- Scope every `qmd` search to the collections of the current repository and profile. Never mix atqamz, yes2games, hage, or any other profile's collections in one search unless the user explicitly asks for cross-profile retrieval.

## Environment

- Host NixOS, shell bash. Write commands the user runs themselves in bash syntax.
- Never install tools globally. Use the project devshell when available; else `nix shell nixpkgs#<pkg> -c <cmd>` for one-off CLI.
- `~/.claude`, `~/.codex`, and `~/.config/opencode` configs symlink into `~/dotagents`. Edit the source there; changes apply instantly, no home-manager rebuild.

## Coding

- Read before write. Project convention beats personal preference.
- Errors explicit, propagated with context. Names clear, descriptive.
- No new dependency without discussion. Prefer stdlib.
- Read the slice you need, not whole files. Targeted search over broad dump.
- Comments: zero by default - only a "why" the code cannot show, or a functional pragma (`# shellcheck disable`, `# type: ignore`, `# noqa`). Never restate code, narrate "what", add banners, or docstring the obvious. Delete stale or obvious comments in any file you touch. Match local comment density: no comment where sibling code has none, even a justified one.
- Tests: add or update when a suite exists, run before done. Respect project lint and format.
- Follow existing file structure. Reorganize only if that is the task.

## Git / GitHub

- GPG sign always. Never `--no-gpg-sign`, never `--no-verify`. Never force-push the default branch.
- Trunk-based. Branch `<issue#>-<slug>` from default. No direct commit to `master`/`main` unless asked.
- New repos: default branch `main`. Repos cloned from upstream keep their own convention.
- Worktrees: always via `treehouse` (creates and recycles them). Never hand-manage `git worktree add`/`remove`.
- One logical change per commit. Imperative, lowercase start, no trailing period.
- No planning jargon in commits, PRs, or issues (no phase/step/milestone/part-X/task-id). Say what the change does.
- `gh` CLI for all GitHub ops. No raw curl, no web UI.
- No push, PR, or commit unless asked; applies to subagents too - every commit-capable subagent prompt states it.
- Assignee `atqamz` on every PR and issue.
- Planning/spec scratch docs (specs, plans, handovers) stay untracked. Never commit them to a product repo.

### Issues

- `gh issue create --assignee atqamz`. Add `--milestone` when one fits.
- Existing repo labels when they fit; never create labels without asking.
- Always write issue references fully qualified: `owner/repo#N`, never bare `#N`, even same-repo. Related issues: `Related: owner/repo#N`, `Depends on: owner/repo#M`.
- Multi-part work: one tracking issue, close only after ALL parts land.
- Comment on issues when PRs open or work lands. Skip "started working" noise.
- Close promptly with outcome: `gh issue close N -c "done: ..."`.

### Pull requests

- Body: `## Summary` (1-3 bullets), `Fixes owner/repo#N` on its own line, `## Test plan`.
- Same-repo issue: MUST use closing keyword (`Closes`/`Fixes`/`Resolves`) + `owner/repo#N` on its own line. Keyword directly precedes the reference, nothing between. Reference without keyword links but never closes.
- Multiple issues: repeat the keyword for each (`Closes owner/repo#1, closes owner/repo#2`). A comma list after one keyword closes only the first.
- Closing keyword fires only when the PR merges into the default branch. PR targeting any other branch links but never closes; close by hand.
- Cross-repo: keywords never close. Reference `owner/repo#N`, close by hand after all parts land.
- Before merge: `gh pr view N --repo owner/repo --json reviews` and address every P1/P2 finding. CI green alone is not "safe to merge".
- Address review findings with code fixes, then reply to each resolved comment via `gh api` and re-request review when needed.
- Merge with `gh pr merge --merge` or `--squash`; squash a branch whose intermediate commits are noise. Never `--rebase`.
- Post-merge (every merge, no exceptions):
  1. Verify issue closed: `gh issue view N --repo owner/repo --json state -q .state`.
  2. Still open? `gh issue close N --repo owner/repo -c "landed in #PR"`.
  3. Delete remote+local branch.
  Auto-close is unreliable. Verify step catches it.

## Communication

- Direct. No hedge, no confirmation theater. Told -> do.
- Design/discussion intent ("discuss", "let's think", open "how") -> discuss only: propose, compare, recommend, no edits or mutating commands until explicit go. Named or mechanical task -> do it.
- Show what changed, brief. No full-file echo. Skip preamble and repeated info.
- File paths in responses: always full absolute, never relative.
- Never suggest `/compact` or `/clear`; auto-compact handles context pressure. Hook-injected context-size numbers stale - ignore them.
- Brainstorms: surface tensions and tradeoffs before locking choices.
- UI/UX design decisions (layout, components, visual hierarchy) are the agent's call; don't ask, apply frontend design skill.

## Security

- Never commit or echo secrets (`.env*`, `*.pem`, `*.key`, `credentials.json`, tokens, passwords); warn if asked, and warn before adding any sensitive file `git status` shows.
- Never read, modify, or display private key material.

## Efficiency

Always on. Terse output, minimum code, full substance.

- Write terse. Drop articles, filler, pleasantries, hedging, preamble, and restated context. Fragments are fine. Keep every technical detail, exact term, number, and path. Code, commits, PRs, and issues stay normal prose.
- Resume normal register for security warnings, irreversible actions, and a confused user.
- Understand the real flow before changing it. Trace the actual call path, read the slice that matters, reproduce the bug. Efficiency runs after understanding, never instead of it.
- Stop at the first sufficient solution: does this need to exist at all; is it already in this codebase; does the stdlib do it; does the platform do it; does an installed dependency do it; is it one line; only then write the minimum new code.
- No unrequested abstractions. Deletion over addition. Boring over clever. Fewest files, shortest working diff.
- Fix root cause, not symptom. Find every caller and fix once where they all route through.
- Never trade away: anything explicitly requested, understanding the problem, input validation at trust boundaries, error handling that prevents data loss, security, accessibility.
- Non-trivial logic leaves one runnable check behind.
