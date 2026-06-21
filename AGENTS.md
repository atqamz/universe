# AGENTS.md

Repo-specific rules. Global rules apply unless overridden here.

## Layout

- `parts/` — flake-parts modules: hosts, checks, formatter, devshells, apps.
- `modules/nixos/`, `modules/home/` — system + home-manager config.
- `lib/mkHost.nix` — host builder. `hosts/` — per-host hardware + disko.

## Rules

- No comments in `.nix`. Code speaks. Stricter than global: none at all, not even "why".
- Keep `# shellcheck disable=` pragmas — `writeShellApplication` runs shellcheck at build.
- Before commit: `nix fmt`, then `nix flake check`.
- "Ship" means: commit + push + PR + merge if green + apply
- Cachix auth token only in GH secret `CACHIX_AUTH_TOKEN`.
