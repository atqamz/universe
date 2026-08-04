# 0009. GPU benchmarks are quarantined in their own module

## Context

The OCCT and FurMark GPU benchmarks are the only things in this repo fetched from an unversioned vendor URL.
`ocbase.com` serves its download from a `version:` path that returns different bytes when the vendor rotates a build, so the fixed-output hash breaks with no version change on our side and no notice.

Both are also distributed as binaries that expect to write next to themselves, so neither runs from a read-only store path directly.

Every other package in the repo either pins a release tag or is a local `pkgs/<name>` derivation, and adding these to `modules/home/packages.nix` would put a periodically self-breaking fetch in the middle of the list every host builds.

## Decision

Keep them in `modules/home/benchmarks.nix`, separate from `packages.nix`, and give each a shim that copies the payload into `XDG_DATA_HOME` and runs it from there.

## Consequence

A vendor rotation breaks `nix flake check` for every host, because `parts/checks.nix` builds the full `toplevel` closure.
The module boundary does not prevent that - it makes the cause obvious and keeps the blast radius to one file when the fix is to re-hash or drop the entry.

This is the one place where "pin a version" is not available as an answer, which is why it is written down instead of being inferred from the code.
