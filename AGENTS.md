# AGENTS.md

Global operating rules for AI coding agents. Model-agnostic canonical source. `CLAUDE.md` is a thin `@AGENTS.md` import. Defaults — project-level instruction file overrides.

## Force-read filename convention

Agent tools auto-load ("force-read") one instruction file at session start, by filename:

- `CLAUDE.md` — Claude Code
- `AGENTS.md` — Codex, GitHub Copilot, Cursor, Zed; cross-vendor standard

Canonical rules live in `AGENTS.md`: broadest support, read verbatim. `CLAUDE.md` is a one-line `@AGENTS.md` import so all tools share one source — read raw by Codex (no `@import` expand), `@path`-expanded by Claude. Same filenames at project root override these globals.

## Git

- No `Co-Authored-By`.
- Trunk-based. Branch from default. No direct commit to `master`/`main` unless asked.
- Branch name `<issue#>-<slug>` (`42-fix-auth-timeout`). No issue → descriptive slug.
- One logical change per commit. Imperative, lowercase start, no trailing period. Body optional.
- No planning jargon: no "phase"/"step"/"milestone"/"part X of Y"/"stage", spec-tracking, task IDs (`02-01`, `phase-3`). Say what commit does, not where it fits.
- GPG sign always. Never `--no-gpg-sign`, `-c commit.gpgsign=false`.
- Never `--no-verify`.
- Never force-push default branch.
- Merge via PR on GitHub. No local merge.
- No push/PR unless asked.

## GitHub

- `gh` CLI for all GitHub ops (PR, issue, checks, release, API). No raw `curl`, no web UI.
- PR create: push `-u`, then `gh pr create`. Title <70 chars. Body: `## Summary` (1-3 bullets), `Fixes #N` if applies, `## Test plan`.
- Cross-repo ref `<org>/<repo>#<number>`.
- Inspect: `gh pr view`, `gh pr checks`, `gh pr diff`.
- Issue: `gh issue view`, `gh issue list`, `gh issue create`.
- Alias `gh co <number>` = `gh pr checkout`.
- Assignee `atqamz` every PR/issue (`--assignee atqamz`).
- Merge `gh pr merge --merge` only. No squash/rebase.
- No planning jargon in issue/PR title/body. Say work done.
- Post-merge: delete remote branch (`gh pr merge --delete-branch` or `git push origin --delete <branch>`), `git worktree remove <path>`, `git branch -d <branch>`.

## Coding

- Read before write. Project convention beats personal.
- Errors explicit. Propagate with context.
- Names clear, descriptive, match project.
- Add/update tests when suite exists. Run before done.
- Respect project lint/format. Run if available.
- No new dep without discussion. Prefer stdlib.
- Comments: code speaks — clear names, small units, structure carry intent. Default none. Add one ONLY for a non-obvious "why" code can't express (workaround, constraint, gotcha) or a functional pragma (`# shellcheck disable`, `# type: ignore`, `# noqa`). Never "what", never restate code, never banner/divider/section headers, never narrate steps (`// fetch user then validate`), never docstring a self-evident function, never TODO/placeholder filler. Delete stale/redundant/obvious comments on sight, including pre-existing ones in any file you touch.
- Follow existing file structure. Reorganize only if task.

## Communication

- Direct. No hedge, no over-qualify.
- Don't plan on unknowns. Ask until clear, then plan.
- Ask when ambiguous. One question beats wrong assumption.
- No confirmation theater. Told → do.
- Design/discussion intent ("discuss"/"let's think"/open "how") → discuss only: propose, compare, recommend. No edits/mutating cmds till explicit go ("do it"/"go"). Named/mechanical → told → do.
- Show what changed. Brief summary after edits. No full file echo.
- Skip preamble, repeated info.
- No emojis in code, commits, responses.
- Action over discussion. Path clear → write code.

## Security

- Never commit secrets: `.env`, API keys, tokens, passwords, private keys. Warn if asked.
- Don't echo secrets in output or logs.
- Sensitive patterns `.env*`, `credentials.json`, `*.pem`, `*.key`, `id_rsa*`. Don't read unless explicitly asked with clear context.
- `git status` shows sensitive file → warn before adding.
- Never modify or display private key material.

## Context discipline

- Most tools auto-summarize near context limit. Don't nag to compact/clear on token count alone — keep working.
- Suggest fresh context only when next task genuinely unrelated (no shared state). Suggest compaction only when actively losing needed earlier context, not preemptively.
- Prefer self-contained chunks: finish a logical unit before next. Clean handoffs, not a token ceiling.
- Don't pre-load unneeded context: read the slice you need, not whole files; targeted search over broad dump.

## Memory

- Canonical memory is `~/brain` (git, auto-pulled). Supersedes per-project memory. Don't write per-project memory.
- Capture automatic: a Stop hook digests each session into `~/brain/log/`. Don't hand-write `log/`.
- Recall: when a prompt might be answered from past work, consult brain — read `~/brain/index.md`, open matching `~/brain/notes/<slug>.md`, cite it. Use `brain-recall <query>` (qmd-ranked, grep fallback) when available. Don't bulk-read; index first, then the one matching note.
- `notes/` is canon (trust it); `log/` append-only provenance (verify, don't cite blindly).
- Canon (`notes/`) changes only via reviewed PR on `brain` repo. Propose promotions from `log/` via PR; don't edit `notes/` casually.
