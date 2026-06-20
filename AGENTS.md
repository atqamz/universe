# AGENTS.md

Repo-specific rules. Global rules apply unless overridden here.

## Layout

- `parts/` — flake-parts modules: hosts, checks, formatter, devshells, apps.
- `modules/nixos/`, `modules/home/` — system + home-manager config.
- `lib/mkHost.nix` — host builder. `hosts/` — per-host hardware + disko.

## Rules

- No comments in `.nix`. Code speaks. (Override: global keeps "why" comments; here, none.)
- Keep `# shellcheck disable=` pragmas — `writeShellApplication` runs shellcheck at build.
- Before commit: `nix fmt`, then `nix flake check`.
- Cachix auth token only in GH secret `CACHIX_AUTH_TOKEN`.
