# 0009. OCCT is quarantined in its own module

## Context

OCCT is the only thing in this repo fetched from an unversioned vendor URL.
`ocbase.com` serves its download from a `version:` path that returns different bytes when the vendor rotates a build, so the fixed-output hash breaks with no version change on our side and no notice.

It is also distributed as a binary that expects to write next to itself, so it cannot run from a read-only store path directly.

Every other package in the repo either pins a release tag or is a local `pkgs/<name>` derivation, and adding it to `modules/home/packages.nix` would put a periodically self-breaking fetch in the middle of the list every host builds.

## Decision

Keep it in `modules/home/benchmarks.nix`, separate from `packages.nix`, and give it a shim that copies the payload into `XDG_DATA_HOME` and runs it from there.

## Consequence

A vendor rotation breaks `nix flake check` for every host, because `parts/checks.nix` builds the full `toplevel` closure.
The module boundary does not prevent that - it makes the cause obvious and keeps the blast radius to one file when the fix is to re-hash or drop the entry.

This is the one place where "pin a version" is not available as an answer, which is why it is written down instead of being inferred from the code.
