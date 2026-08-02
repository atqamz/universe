# 0006. Every host gets a free `-minimal` variant

## Context

The full closure does not fit in the installer ISO's tmpfs, so a fresh install cannot go straight to the real config.

## Decision

`parts/hosts.nix` generates two attrs per host: the full one, and a `-minimal` one built from `modules/nixos/minimal.nix` and `modules/home/minimal.nix`.
Install the minimal variant from the ISO, boot, then switch to the full config.

The layering is real, not decorative.
`programs.nix-ld.enable` lives in `modules/nixos/minimal.nix`, but `programs.nix-ld.libraries` lives in `modules/nixos/nix-ld.nix`, imported only from `modules/nixos/default.nix`.
Co-locating them would drag the GTK and GL closure into the minimal variants and defeat the whole point.

## Consequence

Anything added to a `minimal.nix` grows the ISO-time closure and must be justified.
`parts/checks.nix` derives its check list from `self.nixosConfigurations`, so both variants of every host are covered without a second list to keep in sync.
