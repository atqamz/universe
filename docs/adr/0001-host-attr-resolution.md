# 0001. Never name a host attr when rebuilding a live machine

## Context

`nixosConfigurations` holds one attr per host plus a `-minimal` variant of each.
`nixos-rebuild` defaults to `nixosConfigurations.$(hostname)` when no attr is given.

Naming the wrong attr does not fail loudly.
It rewrites `networking.hostName`, swaps the hardware config (kernel modules, microcode, PRIME bus IDs, undervolt), and because `system.autoUpgrade`'s flakeref interpolates `hostName`, the wrong host then reapplies itself on every timer run.
A copied command from a doc or an older session is the realistic way this happens.

## Decision

On a booted machine, always `sudo nixos-rebuild switch --flake /home/atqa/universe` with no attr.
Only the from-ISO install path names a host explicitly, because the installer boots as `nixos` and has no correct hostname to resolve.

## Consequence

Docs and runbooks must not contain a post-boot `--flake .#<host>`.
`docs/runbooks/install.md` step 4 is the single place a host name is written by hand.
