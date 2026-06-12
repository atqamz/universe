# Memory

- Canonical memory is `~/brain` (git, auto-pulled). It supersedes the old
  per-project `~/.claude/projects/*/memory/`. Do not write per-project memory.
- Capture is automatic: the Stop hook digests each session into `~/brain/log/`.
  You do not hand-write `log/`.
- Recall: when a prompt might be answered from past work, consult the brain —
  read `~/brain/index.md`, open the matching `~/brain/notes/<slug>.md`, cite it.
  Use `brain-recall <query>` (qmd-ranked, grep fallback) when available.
- Canon (`notes/`) changes only through a reviewed PR on the `brain` repo. Do not
  edit `notes/` casually; propose promotions from `log/` via PR.
