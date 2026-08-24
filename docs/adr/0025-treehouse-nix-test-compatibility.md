# Treehouse Nix test compatibility

## Context

Treehouse 2.3.0 added release-gate tests that create shell fixtures with `/usr/bin/env bash` and execute a Python-backed attestation parser.

The Nix sandbox does not provide the host FHS path `/usr/bin/env`, and the upstream package declares only `git` as a native check input.

As a result, the latest Treehouse source fails its package checks in this repository even though the same source passes on a normal GitHub Actions runner.

## Decision

The NixOS overlay exposes the latest Treehouse package as `pkgs.treehouse` with `python3` added to its native check inputs.

The overlay also rewrites the two test fixture shebangs to the pinned Nix Bash path before the upstream check phase.

Universe consumers use this overlaid package while the runtime source and version remain owned by the Treehouse flake input.

## Consequence

Treehouse remains current without disabling its test suite or maintaining a copied package expression.

The overlay must be rechecked whenever the Treehouse input changes, and it can be removed once upstream declares the Python check dependency and avoids the non-portable fixture shebangs.
