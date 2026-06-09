# Universe — Ground Rules & Repository Structure

Date: 2026-06-09
Status: approved (design)
Issues: #3 (this spec) · feeds #1, #2, #4

## Purpose

Define the conventions, folder structure, and tooling for the `universe`
NixOS configuration repository so all subsequent work (issues #1, #2, #4)
builds on a stable, idiomatic foundation. This spec is the target for
issue #3 ("follow nix config best practices for folder structure and more").

## 1. Direction & scope

- `universe` is a **full NixOS flake**, multi-host-ready, with `pavg15` as the
  only real host for now. Other host directories are added only when a real
  host exists (YAGNI; no empty slots).
- Home-Manager is wired **as a NixOS module** (single `nixos-rebuild switch`),
  not as a standalone `homeConfigurations` output.
- `nixpkgs` tracks `nixos-unstable`; `home-manager` follows `nixpkgs`.
- `flake-parts` orchestrates flake outputs.
- The earlier `dotnix/HANDOVER.md` plan (Home-Manager-only + pavg15 moving to
  CachyOS distro) is **abandoned**. CachyOS is only a kernel swap on NixOS.
- Old repos (`dotnix`, `dotmachines`, `dotfiles`) are **reference material**,
  retired after `universe` stabilizes. Data repos (`secrets`, `raw`,
  `password-store`) stay **external** permanently.

## 2. Folder structure

```
flake.nix          inputs + flake-parts mkFlake (thin)
parts/
  hosts.nix        nixosConfigurations.* via lib/mkHost
  devshells.nix    perSystem devShell (fmt + lint tools)
  formatter.nix    treefmt-nix -> nixfmt-rfc-style
  checks.nix       git-hooks: statix / deadnix / treefmt
hosts/
  pavg15/
    default.nix    host entry: imports modules + stateVersion + host knobs
    hardware.nix   generated (renamed from hardware-configuration.nix)
modules/
  nixos/           one-concern system modules (boot, gpu, desktop, audio, network, ...)
  home/            one-concern Home-Manager modules (shell, git, hypr, caelestia, packages, ...)
lib/
  mkHost.nix       host factory; wires Home-Manager-as-module + common modules
.envrc             use flake (direnv)
.github/workflows/ CI: nix flake check + build pavg15
```

- `flake.nix` stays thin: inputs plus `flake-parts.lib.mkFlake` with
  `systems = [ "x86_64-linux" ]` and `imports = [ ./parts ]` (or each
  `parts/*.nix`).
- Each aspect of the flake is its own `parts/` flakeModule.
- A host directory holds only what is host-specific; shared configuration lives
  in `modules/`.

## 3. Flake inputs & wiring

Inputs:

- `nixpkgs` — `github:nixos/nixpkgs/nixos-unstable`
- `home-manager` — `follows = "nixpkgs"`
- `flake-parts`
- `treefmt-nix`
- `git-hooks.nix` (formerly `pre-commit-hooks.nix`)
- `caelestia-shell`
- `zen-browser`

Every non-`nixpkgs` input sets `inputs.nixpkgs.follows = "nixpkgs"` to dedupe.

Wiring:

- `parts/hosts.nix` declares `nixosConfigurations.<host>` through `lib/mkHost`.
- `parts/formatter.nix` imports the `treefmt-nix` flakeModule and enables
  `nixfmt-rfc-style`.
- `parts/checks.nix` imports the `git-hooks.nix` flakeModule, enables `statix`,
  `deadnix`, and `treefmt`, and exposes the pre-commit shell hook into the
  devShell.
- `parts/devshells.nix` provides the `default` devShell with formatter and lint
  tools available; `.envrc` contains `use flake`.
- Inputs reach modules via `specialArgs` (NixOS) and `extraSpecialArgs`
  (Home-Manager), threaded by `lib/mkHost`.

Exact module option names are pinned during implementation against the locked
`flake.lock`.

## 4. Module conventions

- **One concern per file.** `modules/nixos/` for system, `modules/home/` for
  Home-Manager.
- A host is **thin**: `hosts/<name>/default.nix` imports the modules it needs,
  imports `hardware.nix`, sets `stateVersion`, and sets host-specific knobs
  (monitors, GPU bus ids, hostname).
- Cross-host common configuration lives in a base module set that hosts opt
  into.
- Package placement: prefer `programs.*` / `services.*` over a raw package.
  System-wide packages go in `environment.systemPackages` inside the matching
  NixOS module; user packages go in `home.packages` inside the matching Home
  module; per-host packages go in that host's `default.nix`.
- **No secret is ever inlined in any `.nix` file** (the Nix store is
  world-readable). The secrets mechanism is decided in issue #4.
- `stateVersion` is pinned and not bumped casually.

## 5. Code style

- **Comments are very minimal — the code speaks for itself.** A comment is
  written only for a genuinely non-obvious *why* that cannot be expressed in
  code (a hardware bus id, an upstream-bug workaround). No "what" comments, no
  section-banner comments.
- Names follow the upstream `nixpkgs` / Home-Manager option names; a file name
  states its single concern (`gpu.nix`, `shell.nix`).
- Formatting is `nixfmt-rfc-style`, enforced by treefmt and the pre-commit hook.
  Manual formatting is not debated.
- `deadnix` (no dead bindings) and `statix` (no anti-patterns) gate both CI and
  the pre-commit hook.
- Pure-eval friendly: flake inputs only, no `<nixpkgs>` channel references, no
  surprising import-from-derivation.

## 6. Git / GitHub

The repository adopts the global conventions (unlike `dotfiles`, which
overrides to direct-push):

- Trunk-based. Branch `<issue#>-<slug>` from `main`.
- One logical change per commit; imperative, lowercase subject, no trailing
  period.
- PRs via `gh`, assignee `atqamz`, merge with `--merge` only.
- GPG-signed always. No `Co-Authored-By`. No planning jargon.

## 7. Definition of done (verification)

A change is done only when:

- `nix flake check` passes (evaluation plus `statix` / `deadnix` / `treefmt` /
  pre-commit checks).
- `nixos-rebuild build --flake .#pavg15` builds (not just parses).
- CI (GitHub Actions) runs `nix flake check` and builds `pavg15` on the PR.

Parse-only (`nix-instantiate --parse`) is not verification.

## 8. Secrets (deferred to issue #4)

`secrets`, `raw`, and `password-store` stay external repositories. `universe`
consumes `secrets` via `sops-nix` using an age key for headless decryption at
boot. No secret is committed to `universe`. The full fresh-install bootstrap
workflow is specified in issue #4's own design.

## 9. Issue mapping

- **#3** — this spec. Implementation restructures the repo to the layout above
  and adds the tooling.
- **#1** (remove GNOME deps) — its own spec. Principle: achieve removal by *not
  installing*, not by purging. Replacements to decide in that spec: `nautilus`
  (file manager), and whether `gnome-keyring` (Secret Service) and the polkit
  agent stay or are replaced.
- **#2** (align keybindings) — its own work. Keybindings are declarative in
  `modules/home/hypr.nix` (hyprlang backend), single source, with the map
  aligned to the definitions in `dotfiles` / `dotnix` / `dotmachines`.
- **#4** (secrets bootstrap) — its own spec.

## 10. Old-repo retirement

- `dotnix` — reference; archive after `universe` is stable and `pavg15` is
  daily-driven.
- `dotmachines` — keep until `sfx14` leaves Fedora; then archive.
- `dotfiles` — keep for `sfx14`; absorb the tool-agnostic shell configs
  (`bash`, `git`, `tmux`, `readline`, `zed`) into `modules/home` as `programs.*`.
  The hand-rolled `quickshell` QML module is dropped (upstream `caelestia`
  supersedes it). The hypr config is reconciled into the Nix module, not
  symlinked.
- `secrets` / `raw` / `password-store` — kept permanently, external.

## Build order

1. Issue #3 — restructure to this layout + tooling (depends on this spec).
2. Issue #1 — remove GNOME deps (own spec).
3. Issue #2 — align keybindings (own work).
4. Issue #4 — secrets bootstrap (own spec).
