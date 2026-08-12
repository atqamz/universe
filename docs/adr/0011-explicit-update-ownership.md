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
`koma` is the named exception to the disabled-self-update rule: it exposes no opt-out switch, so the rule is not to run `koma update` (`0014-koma-comes-from-its-upstream-flake.md`).
