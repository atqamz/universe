# 0011. Every mutable artifact has one update owner

## Context

Nix reproducibility is weakened when a Nix-installed binary also replaces itself at runtime, or when an unpinned installer changes independently of the configuration that invokes it.
Live-editable Git configuration and machine-generated runtime state are intentionally mutable, but they need different ownership rules from packaged software.

## Decision

Classify mutable artifacts by owner:

- Nix-owned binaries are updated only through flake/package changes; application self-update is disabled wherever the application offers a switch, and otherwise contained by policy.
- Git-backed live configuration is owned by its sibling repo and linked into the home directory; declarative Git client configuration is owned by Home Manager.
- Runtime-managed payloads such as globally installed agent skills may change outside the Nix store, but the installer/version and repair mechanism are declared by Universe.
- Machine-generated replicated state may be written only by its designated writer role.
- The `main` branch is the acceptance boundary for externally sourced executable content. Update discovery may be automated, but Dependabot updates are merged deliberately and custom package updates are dispatched deliberately before `system.autoUpgrade` deploys the approved state.

Compatibility shims are scoped to the program that requires them. They do not redefine common executables globally unless that is an explicit workstation policy.

## Consequence

OpenCode stays Nix-owned instead of bypassing the nixpkgs auto-update guard.
The `skills` CLI invoked by `skills-sync` is version-pinned and runs only when that command is invoked deliberately.
Claude's Bun-backed `node`/`npx` compatibility exists only in Claude's wrapper PATH.
`hand` at `~/.local/bin/hand` is a runtime-managed payload: Home Manager activation installs it only when absent, and `hand update` owns every subsequent overwrite and channel switch (`modules/home/hand.nix`).
It is deliberately not a flake input, a `home.packages` entry, or a `nix profile install`, because those all make the path read-only, and `hand update` rewrites the binary in place both to update it and to select a release channel.
The absent-only activation check is what keeps activation and `hand update` from fighting over the file on every switch; `universe.doctor.paths` is what reports the binary going missing.
The install step is gated behind `universe.capabilities.handFleet`, enabled only on the host that runs a hand fleet (sfx14), so a headless host such as pavg15 never gains an activation-time GitHub download or a doctor requirement for a tool it does not use.
A download failure warns to stderr and lets activation succeed, since a transient GitHub outage must not fail a `nixos-rebuild switch`, let alone an unattended `system.autoUpgrade` run; only a checksum verification failure is fatal, because that is not transient and continuing quietly would install unverified content.
