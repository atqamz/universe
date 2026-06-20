# AGENTS.md

NixOS config. flake-parts. One host: `pavg15` (+ `pavg15-minimal` variant).

## Layout

- `flake.nix` — inputs + outputs.
- `parts/` — flake-parts modules: hosts, checks, formatter, devshells, apps.
- `modules/nixos/`, `modules/home/` — system + home-manager config.
- `lib/mkHost.nix` — host builder.
- `hosts/` — per-host hardware + disko.

## Code

- No comments in `.nix`. Code speaks. Name things well instead.
- Keep `# shellcheck disable=` pragmas in embedded scripts. Load-bearing: `writeShellApplication` runs shellcheck at build.
- Embedded scripts use `pkgs.writeShellApplication`.

## Before commit

- `nix fmt` — format (nixfmt via treefmt).
- `nix flake check` — builds both toplevels + statix + deadnix + treefmt.
- Cheap eval, no full build: `nix eval .#nixosConfigurations.pavg15.config.system.build.toplevel.drvPath`.
- `nix develop` — devshell, installs pre-commit hooks (statix, deadnix, treefmt).

## Git

- Branch from `master`. No direct commit to `master`.
- Branch name `<issue#>-<slug>`.
- One change per commit. Subject imperative, lowercase, no period. No planning jargon.
- GPG sign always. Never `--no-gpg-sign`, never `--no-verify`.

## GitHub

- `gh` CLI for all ops. Assignee `atqamz`.
- PR: push `-u`, `gh pr create`. Body `## Summary` + `Fixes #N` + `## Test plan`.
- Merge `gh pr merge --merge` only. No squash, no rebase.
- Dependabot runs weekly, auto-merges on green.

## Secrets

- Never commit secrets. sops-nix + private `vault` repo hold them.
- Cachix auth token lives only in GH secret `CACHIX_AUTH_TOKEN`. Public key in `modules/nixos/nix.nix` is fine.
