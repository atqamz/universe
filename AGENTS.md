# AGENTS.md

Repo-specific rules. Global rules apply unless overridden here.

## Standard

This repository optimizes for explicit ownership, reproducibility, deterministic state, observable failure, and small blast radius rather than minimum line count.
Do not preserve an abstraction merely because it already exists: every abstraction must encode a real invariant or have more than one genuine consumer.

## Layout

- `parts/` — flake-parts modules for hosts, checks, formatter, dev shell, apps, and packages.
- `hosts/<name>/default.nix` — minimal-safe identity/hardware layer. `hosts/<name>/full.nix` — full-host features. Host-only supporting modules live beside them.
- `modules/nixos/`, `modules/home/` — shared system and Home Manager concerns.
- `lib/mkHost.nix` — composes host base/full layers with shared base/full layers.
- `pkgs/` — local packages. `pkgs/default.nix` is the single package registry consumed by the overlay, flake packages, and weekly updater.
- `docs/adr/` — architecture decisions that are expensive to rediscover. Read the index before changing an invariant.

## Non-negotiable rules

- No comments in `.nix`; rationale belongs in an ADR (`docs/adr/0007-no-comments-in-nix.md`). Shell comments inside generated shell code, including required shellcheck pragmas, are fine.
- Before commit: `nix fmt`, then `nix flake check`. After applying a machine/runtime change: `nix run .#doctor` too.
- "Ship" means commit + push + PR + merge if green + apply.
- Rebuild a live machine with `sudo nixos-rebuild switch --flake /home/atqa/universe` or `--flake .`; never name a host attr on a live machine. Only the installer names `$HOST-minimal` (`docs/adr/0001-host-attr-resolution.md`).
- Cachix auth exists only as the GitHub secret `CACHIX_AUTH_TOKEN`.

## Host composition

- A `-minimal` configuration may import only `hosts/<host>/default.nix` and `modules/nixos/minimal.nix` plus the flake integration modules; it must not import Home Manager. `modules/home/minimal.nix` is the base layer of the full Home Manager configuration only. Full-only host code belongs in `hosts/<host>/full.nix` or a module imported from it (`docs/adr/0006-minimal-host-variants.md`).
- Shared modules consume `universe.capabilities.*` or `universe.roles.*` through NixOS/Home Manager configuration. Do not use `hostname == ...` as a feature flag (`docs/adr/0010-host-capabilities-not-hostname-flags.md`). `hostname` is still correct where the identity itself selects data, such as `dotfiles/caelestia/hosts/${hostname}.json`.
- Host-specific services belong with the host when there is only one real consumer. Do not build a generic option layer around one machine's job merely to make the file look reusable.

## State and update ownership

Every mutable artifact has exactly one owner (`docs/adr/0002-cross-repo-layout.md`, `docs/adr/0011-explicit-update-ownership.md`).

- Universe owns declarative machine state, packages, services, timers, and health contracts.
- `dotfiles` / `dotagents` own live-editable config; Universe links but does not push them.
- `vault` owns key material; `password-store` owns password entries.
- `zen-profile` is machine-generated state with exactly one writer, declared by `universe.roles.zenProfileWriter`.
- Nix-owned binaries do not self-update. Update them through their flake/package owner.
- Runtime-managed payloads are explicit exceptions. Their installer version and repair mechanism are still declared by Universe.
- Compatibility shims are scoped to the program that needs them. Claude's Bun-backed `node`/`npx` exist only in Claude's wrapper PATH, not globally.

## Automation and failure semantics

- Every timer-driven Home Manager job uses `services.userTimers` unless it genuinely is not a timer. That abstraction attaches `notify-failure@` automatically.
- Expected non-action is success: dirty repo, application currently running, another valid sync holding a lock.
- Broken repair is failure: auth/network failure, divergence, invalid encrypted data, registration failure, or a command that could not restore its invariant. Do not hide these behind `|| true` (`docs/adr/0012-automation-failures-are-observable.md`).
- Use `onActivation = "try"` when activation should not block a rebuild but the same command must still fail under systemd.
- Retry policy belongs to systemd when practical. A watcher detects an edge and triggers a oneshot job; it does not become an invisible retry engine.
- `writeShellApplication` must declare every external command it calls in `runtimeInputs`, or invoke an explicit Nix store path. Ambient workstation PATH is not a dependency declaration.

## Doctor

`nix run .#doctor` is the runtime contract checker; `bootstrap-check` is a compatibility alias.

- Installed user timers/services are derived from evaluated Home Manager systemd configuration, not copied into a manual list.
- Critical host-specific system services/timers are declared through `universe.doctor.*`.
- Home-relative symlink contracts are registered in `universe.doctor.symlinks`: both direct writable symlinks that bypass the Home Manager store hop, and read-only live instruction links that must resolve to a canonical source.
- A new persistent service, timer, direct-link contract, or host responsibility should become doctor-visible by construction rather than by remembering another checklist.

## Live dotfiles and agent configuration

- Read-only live config uses `config.lib.file.mkOutOfStoreSymlink` to absolute paths under `config.home.homeDirectory` (`docs/adr/0003-live-editable-dotfiles.md`).
- Config that the application rewrites atomically cannot traverse Home Manager's store-hop symlink. Claude `settings.json` and OpenCode `opencode.json` are direct writable links generated from one `writableLinks` map in `modules/home/dotagents.nix`; the same map feeds activation, user tmpfiles, and doctor checks.
- Caelestia `shell.json` remains host-specific and `force = true` because Caelestia atomically replaces that path.

## Packaging and developer tools

- Add a local package in `pkgs/<name>/default.nix` and one entry in `pkgs/default.nix`. The overlay, `perSystem.packages`, and weekly updater derive from that registry.
- `pkgs/default.nix` is imported with `lib` and `callPackage` passed explicitly; do not `callPackage` the package set itself. In the overlay the attr names cannot depend on `final`; in `parts/packages.nix`, wrapping the set with `callPackage` leaks override attrs into the flake package set.
- `modules/home/packages.nix` is passive inventory. Application behavior belongs in a named module: Zed in `zed.nix`, browsers in `browsers.nix`, AI tool wrappers/update policy in `ai-tools.nix`, Unity in `unity.nix`.
- Zed is wrapped with its language servers on PATH. `nixd` is the single Nix LSP; keep `go` beside `gopls` because Zed's Go extension may invoke the Go toolchain.
- Direnv is owned by Home Manager with `nix-direnv`; do not hand-write `direnv.toml` or separately install `direnv` in the generic package list.
- Unity runs on `programs.nix-ld`, not a separate FHS wrapper (`docs/adr/0008-unity-runs-on-nix-ld-not-fhs.md`).
- OCCT/FurMark stay quarantined in `modules/home/benchmarks.nix` because their vendor URLs are unversioned (`docs/adr/0009-gpu-benchmarks-fetch-unversioned-urls.md`).

### qmd

`qmd` is `buildNpmPackage` for an upstream that ships no `package-lock.json`; Universe vendors one generated against the release tag.
`nix-update` cannot regenerate it. If upstream dependency ranges changed and `npm ci` fails with `ENOTCACHED`, regenerate the lockfile against the new tag and refresh `npmDepsHash` manually.
Security advisories in the vendored lockfile are handled manually; repo-level Dependabot security updates are deliberately disabled because its npm fetcher cannot use this package layout and the relevant alerts are commonly transitive.
Check whether an advisory is dev-only before changing the package: `npmInstallHook` prunes dev dependencies.
Native prebuilt ELF dependencies are fixed by `autoPatchelfHook`; `better-sqlite3` is the exception that is rebuilt. qmd is intentionally CPU-only and wrapped with the nixpkgs Node runtime.

## SFX14 power and display policy

- `hosts/sfx14/power.nix` is the single owner of SFX14 CPU power state. `low`, `normal`, and `high` are canonical 15 W, 20 W, and 25 W states; each sets RAPL, PPD, EPP, and undervolt-timer state from any prior mode.
- NVIDIA voltage/frequency policy is independent from CPU power mode. Do not make a generic power name secretly lower or raise GPU policy.
- The selected CPU mode is restored after resume; GPU tuning is reapplied after resume as a separate invariant.
- SFX14-only i2c/backlight permissions live with the SFX14 power/display feature, not in shared power configuration.
- `auto-brightness.nix` consumes `universe.capabilities.ambientLight`; it must not know which hostname owns the sensor.

## Zen profile replication

- All hosts may pull only while Zen is stopped. Exactly one host may push; the writer is a role, not a hardcoded hostname.
- The managed file set is explicit. Pull is replace semantics for that set, so deletion on the writer propagates.
- Snapshot comparison happens on deterministic plaintext tar data before `age`; randomized ciphertext is never used as a change detector.
- Pull and push share one lock around the Git repo.
- The close watcher only detects running -> stopped and starts `zen-profile-push.service`. The oneshot push owns failure, notification, and systemd retry.
- Automated snapshot commits disable GPG signing and use the dedicated `zen-profile-sync` identity.

## Runner isolation

- The pavg15 GitHub runner is a host-only feature in `hosts/pavg15/runner.nix` (`docs/adr/0013-runner-workloads-are-rootless-and-isolated.md`).
- Each concurrent runner has its own system user, subordinate IDs, work directory, and rootless Podman API/socket. Never mount the host rootful Docker/Podman socket into a workflow runner.
- The `github-runner` auth user owns the App private key. Job users receive only a short-lived runner registration token, never the App private key or installation token.
- Runners are ephemeral and their work/container state is cleaned between jobs. Keep runner auto-update disabled; bump the container tag deliberately.

## CI / flake hygiene

- `parts/checks.nix` derives every full/minimal NixOS toplevel check from `self.nixosConfigurations`; do not maintain a second host list.
- Flake app implementations are also derivation checks, so `writeShellApplication` scripts are built/shellchecked by `nix flake check` rather than merely having valid app schemas.
- Pre-commit covers treefmt, statix, deadnix, shellcheck, and actionlint.
- Cachix is the only extra substituter; do not add a restored Nix-store CI cache (`docs/adr/0005-cachix-only-substituter.md`).
- The package updater rebases onto current `main` before its final `nix flake check`; the exact checked commit is the commit pushed. Its GITHUB_TOKEN push does not get a second CI run, so this ordering is a correctness boundary.
- Dependabot auto-merge remains gated on the normal build/check workflow.
- `system.autoUpgrade` intentionally uses `git+https://` rather than `github:` to avoid the GitHub API rate-limit path.

## Secrets and install

- Recipient/rotation rules for system SOPS files live at the top of `.sops.yaml`; host SSH keys are persistent per-host recipients (`docs/adr/0004-per-host-ssh-keys-as-sops-recipients.md`).
- `tailscale-oauth` is a steady-state OAuth client secret used by the Tailscale service.
- Full install/reinstall procedure lives in `docs/runbooks/install.md` and `install-anywhere.md`. Keep those current instead of restating procedural steps here.
- The Termux bootstrap treats `https://github.com/atqamz.keys` as the exact source of truth for `authorized_keys`; rerunning it must revoke keys removed from GitHub, not only append new ones.

## Maintaining this file

Keep only durable rules and expensive-to-rediscover traps here.
Implementation cadence, exact service internals, and other facts obvious from code belong in code, not duplicated prose.
When an implementation change invalidates an invariant, update the ADR and rule in the same change.
