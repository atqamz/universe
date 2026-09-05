# 0002. Repository boundaries follow trust and mutation semantics

## Context

A working machine needs a set of repositories: `universe`, `vault`, and `password-store`.
They have different visibility, mutation patterns, and recovery requirements.
Without an ownership rule, package declarations drift into config repositories and unattended automation starts writing human-maintained repositories.

## Decision

Repository boundaries follow trust and mutation semantics, not config category names.

- `universe` owns declarative machine state, packages, services, timers, runtime health contracts, and the live-editable public config under `configs/dotfiles` and `configs/dotagents`.
- `configs/dotfiles` and `configs/dotagents` own their live-editable application and agent configuration. Universe links them out of the store but does not rewrite or push them.
- `vault` owns key material and secret export/import logic.
- `password-store` owns password entries.
- Human-maintained config is maintained through deliberate Git workflows inside the Universe checkout. Universe links it but does not pull, push, or rewrite the subtrees separately.

The install runbook is authoritative for how each repository is cloned and refreshed.

## Consequence

A package remains declared in Universe even when its configuration lives in `configs/dotfiles` or `configs/dotagents`.
Public human-authored machine configuration and live-editable config now share the Universe repository, so coordinated desktop or agent changes land atomically in one review, branch, and merge instead of being split across sibling repositories.
Private provisioning material stays behind the `vault` trust boundary, and password entries stay with their own runtime owner.
Adding another cross-repo writer requires a new architecture decision.
