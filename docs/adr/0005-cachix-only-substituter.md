# 0005. Cachix is the only extra substituter, in CI and on machines

## Context

`nix flake check` builds the full `toplevel` closure for every host including the `-minimal` variants, which pulls in caelestia-shell and other inputs with no upstream cache.
The machines then need those same paths, twice a day, via `system.autoUpgrade`.

CI previously ran `nix-community/cache-nix-action` before `cachix/cachix-action`.
The GitHub Actions cache restored the store, so nothing was newly built during the check, so `cachix-action`'s post-build push had no paths to upload.
CI was green and the cache was empty: the laptop rebuilt every closure from source, measured at 2h45m CPU and 15.5G peak per upgrade.

## Decision

One cache. Cachix serves both CI and the machines.
No GitHub Actions store cache in `ci.yaml`.

## Consequence

Cold CI runs are slower, which is what `jlumbroso/free-disk-space` is there for.
`nix.settings.extra-substituters` on the machines and the `cachix-action` name must stay in sync (`atqamz-universe`).
A 404 for a host closure in the cache means CI pushed nothing and is the signal that this regressed.
