# Architecture decision records

One file per decision that is expensive to rediscover.
Short by design: context, decision, consequence.
`AGENTS.md` states the resulting rules and points here for the reasoning.

| ADR | Decision |
| --- | --- |
| [0001](0001-host-attr-resolution.md) | Never name a host attr when rebuilding a live machine |
| [0002](0002-cross-repo-layout.md) | Six repos, one owner each, no repo configures another |
| [0003](0003-live-editable-dotfiles.md) | Dotfiles are out-of-store symlinks, not store copies |
| [0004](0004-per-host-ssh-keys-as-sops-recipients.md) | Per-host SSH keys decrypt system secrets headlessly |
| [0005](0005-cachix-only-substituter.md) | Cachix is the only extra substituter, in CI and on machines |
| [0006](0006-minimal-host-variants.md) | Every host gets a free `-minimal` variant |
| [0007](0007-no-comments-in-nix.md) | Nix files carry no comments; rationale lives here |
