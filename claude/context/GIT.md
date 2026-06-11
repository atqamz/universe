# Git

- No `Co-Authored-By`.
- Trunk-based. Branch from default. No direct commit to `master`/`main` unless asked.
- Branch name: `<issue#>-<slug>` (`42-fix-auth-timeout`). No issue → descriptive slug.
- One logical change per commit. Imperative, lowercase start, no trailing period. Body optional.
- No planning jargon: no "phase"/"step"/"milestone"/"part X of Y"/"stage", spec-tracking, task IDs (`02-01`, `phase-3`). Say what commit does, not where it fits.
- GPG sign always on. Never `--no-gpg-sign`, `-c commit.gpgsign=false`.
- Never `--no-verify`.
- Never force-push default branch.
- Merge via PR on GitHub. No local merge.
- No push/PR unless asked.
