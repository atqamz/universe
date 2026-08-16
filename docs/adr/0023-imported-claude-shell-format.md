# Imported Claude shell formatting

## Context

The consolidated `configs/dotagents` tree is checked by Universe's root validation.
The two imported Claude shell scripts use an established four-space style that the configured `shfmt` wrapper rewrites throughout the files.

## Decision

Exclude only `configs/dotagents/claude/fetch-usage.sh` and `configs/dotagents/claude/statusline-command.sh` from treefmt.
Keep them covered by the root pre-commit `shellcheck` hook.

## Consequence

The canonical config tree has no blanket formatter or pre-commit exclusion.
The two intentionally preserved shell formats remain stable while shell correctness is still checked by the root validation surface.
