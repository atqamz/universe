# 0002. Six repos, one owner each

## Context

A working machine needs six repos: `universe`, `vault`, `dotagents`, `dotfiles`, `password-store`, and `zen-profile`.
They have different visibility, mutation patterns, and recovery requirements.
Without an ownership rule, package declarations drift into config repos and unattended automation starts writing human-maintained repositories.

## Decision

- `universe` owns declarative machine state, packages, services, timers, and runtime health contracts.
- `dotfiles` and `dotagents` own live-editable application and agent configuration. Universe links them but does not rewrite or push them.
- `vault` owns key material and secret export/import logic.
- `password-store` owns password entries.
- Human-maintained sibling repos are maintained through deliberate Git workflows. Universe links them but does not pull, push, or rewrite them.
- `zen-profile` is the explicit exception: it contains machine-generated replicated state rather than authored configuration. Exactly one host has `universe.roles.zenProfileWriter = true`; every other host is read-only.

The install runbook is authoritative for how each repo is cloned and refreshed.

## Consequence

A package remains declared in Universe even when its configuration lives in `dotfiles` or `dotagents`.
Adding another cross-repo writer requires a new architecture decision; the Zen exception is not precedent for pushing human-maintained repositories.
