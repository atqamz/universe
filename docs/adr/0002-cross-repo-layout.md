# 0002. Six repos, one owner each, no repo configures another

## Context

A working machine needs six repos: `universe`, `vault`, `dotagents`, `dotfiles`, `password-store`, `zen-profile`.
They are separate because their contents have different visibility (public flake, private keys, public config) and different change cadence (a rebuild vs a live edit).

Without a stated boundary this degrades in two ways.
Package declarations drift into whichever module happens to link that package's config, and unattended timers start committing into repos other timers are pulling.

## Decision

- `universe` declares packages and system state, and owns every timer.
- `dotfiles` and `dotagents` carry config only; `modules/home/dotfiles.nix` and `dotagents.nix` only link them.
- `vault` owns key material and is the only thing `import.sh` writes.
- No timer in `universe` pushes to another repo.
  Pulls are `--ff-only` and skip when the target is dirty.

The full table of who clones and who refreshes each repo is in `docs/runbooks/install.md`.

## Consequence

A package whose config lives in `dotfiles` is still declared in `modules/home/packages.nix`.
`ninerouter-models-sync`, which rewrote and pushed `dotagents/opencode/opencode.json` on a timer, was deleted rather than fixed.
