# 0006. Every host gets a genuinely minimal variant

## Context

The full closure does not fit in the installer ISO's tmpfs, so a fresh install cannot go straight to the normal desktop configuration.
A `-minimal` attr is useful only if both shared modules and host-specific composition stay bootstrap-sized.

## Decision

`parts/hosts.nix` generates a full and `-minimal` configuration for every host through `lib/mkHost.nix`.

Each host has two layers:

- `hosts/<host>/default.nix` contains only identity, generated hardware/disko imports, and capability or role declarations required by shared modules.
- `hosts/<host>/full.nix` contains full-machine features such as PRIME policy, laptop power tuning, video acceleration, or work runner services.

`minimal = true` never imports `hosts/<host>/full.nix` and uses `modules/nixos/minimal.nix` plus `modules/home/minimal.nix`.
The full configuration adds the shared full modules and the host full layer.

The same rule applies to shared modules: `minimal.nix` contains only what is needed to boot, authenticate, reach the network, decrypt system secrets, and bootstrap the full machine.

## Consequence

A new feature belongs in a minimal layer only when first-boot bootstrap requires it.
`parts/checks.nix` still derives build checks from all generated `nixosConfigurations`, so every full and minimal variant remains covered without a second host list.
