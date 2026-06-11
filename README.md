# dotai

Claude operating config (CLAUDE.md, context rules, settings, hooks). Symlinked live
into `~/.claude` by the `universe` home-manager config (`modules/home/dotai.nix`)
via `mkOutOfStoreSymlink` — edits are instantly live, no rebuild. Stable; rarely
commits. Memory lives in the separate `brain` repo.
