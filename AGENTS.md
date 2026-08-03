# AGENTS.md

Repo-specific rules. Global rules apply unless overridden here.

## Layout

- `parts/` — flake-parts modules: hosts, checks, formatter, devshells, apps, packages.
- `modules/nixos/`, `modules/home/` — system + home-manager config.
- `lib/mkHost.nix` — host builder. `hosts/` — per-host hardware + disko.
- `pkgs/` — local packages. `pkgs/default.nix` is the single list; the overlay, `perSystem.packages`, and the weekly update matrix all read it.
- `docs/adr/` — the decisions this file only states the rules for. Read `docs/adr/README.md` before arguing with a rule here.

## Rules

- No comments in `.nix`. Code speaks. Stricter than global: none at all, not even "why" (`docs/adr/0007-no-comments-in-nix.md`).
Rationale goes in an ADR, not the file.
- Keep `# shellcheck disable=` pragmas — `writeShellApplication` runs shellcheck at build.
- Before commit: `nix fmt`, then `nix flake check`.
- "Ship" means: commit + push + PR + merge if green + apply
- Apply on a live machine with no flake attr: `sudo nixos-rebuild switch --flake /home/atqa/universe`.
It resolves `nixosConfigurations.$(hostname)` itself.
Never hardcode a host attr, and never copy one out of a doc or an older session - switching a machine to the wrong host silently rewrites `networking.hostName`, swaps its hardware config (kernel modules, microcode, PRIME bus IDs, undervolt), and `system.autoUpgrade`'s flakeref interpolates that same `hostName`, so the wrong host reapplies itself on every timer run.
Only the from-ISO install path names a host explicitly, because the installer boots as `nixos` (`docs/runbooks/install.md`, `docs/adr/0001-host-attr-resolution.md`).
- Cachix auth token only in GH secret `CACHIX_AUTH_TOKEN`.

## Packaging

- Local packages live in `pkgs/<name>/default.nix` and are listed once in `pkgs/default.nix`. `modules/nixos/overlays.nix` merges that set into the overlay and `parts/packages.nix` exposes it as `perSystem.packages`; adding a package means one directory and one line, and `.github/workflows/update-packages.yaml` picks it up automatically via `nix eval --apply builtins.attrNames`.
`pkgs/default.nix` must be `import`ed with `lib` and `callPackage` passed explicitly, never `callPackage`d. In the overlay, `final.callPackage ../../pkgs { }` is infinite recursion - the attr *names* of the overlay's result cannot depend on `final`, so `lib` comes from `prev`; in `parts/packages.nix`, `callPackage` would wrap the set in `makeOverridable` and leak `override`/`overrideDerivation` into `perSystem.packages`, which fails the type check.
- `codedb` is a prebuilt release binary; its own `update`/`nuke` subcommands don't apply under Nix — bump the version with `nix-update` (uses `passthru.updateScript`).
- The five `*-axi` packages are one call each to `mkAxi` (`pkgs/axi/default.nix`), which owns the shared `buildNpmPackage` shape and the vendored-lockfile `postPatch`. Because `version` and the hashes then sit in the caller rather than where `meta` is defined, both `mkAxi`'s `updateScript` and the update workflow pass `--override-filename pkgs/<name>/default.nix` so `nix-update` edits the right file.
- `rtk` is overridden in the same overlay with `RUSTFLAGS = "--cap-lints warn"` - upstream's `Cargo.toml` sets `[lints.rust] warnings = "deny"`, so any dead code a newer rustc starts flagging fails the test-binary build and takes `nix flake check` down with it. Capping keeps the test suite running; drop the override once nixpkgs ships an rtk that compiles clean.
- `claude` (`modules/home/packages.nix`) wraps sadjow's `claude-code` flake input and prefixes PATH with a bun-backed `node` shim — NixOS has no system JS runtime, and Claude plugin hooks that shell out to `node` need one.
- `zed` (`modules/home/packages.nix`) is wrapped with its language servers on PATH (`nil`, `go`, `gopls`, `rust-analyzer`, `pyright`, `typescript-language-server`) rather than letting Zed fetch them. Zed's Go extension shells out to `go install golang.org/x/tools/gopls@latest`, so with no `go` on PATH it creates an empty `~/.local/share/zed/languages/gopls/` and the server never starts — a silent failure, unlike `rust-analyzer` which Zed downloads as a static binary. Zed also downloads and runs its own prebuilt `node` for the JS servers; that only executes because `programs.nix-ld` is enabled globally, so nix-ld is load-bearing for the editor, not just for Unity.
- `unityhub` (`modules/home/unity.nix`, which also owns the `unity-editor` wrapper and puts `${config.home.homeDirectory}/.unity/bin` on the login PATH for Unity's CLI tools) prefixes `ffmpeg` onto PATH so Unity's FSBTool can encode WebGL AAC audio. The NVIDIA PRIME offload env those wrappers need is shared with `modules/nixos/gaming.nix` via `lib/prime.nix`.
Those CLI tools exec the editor binary raw, with no FHS wrapper in the chain, so its GL/X11/GTK/ICU deps come from `programs.nix-ld.libraries` (`modules/nixos/nix-ld.nix`) - the empirically minimal set of the editor's unresolved `ldd` entries, not the full FHS superset. Why that module is imported from `modules/nixos/default.nix` and not from `minimal.nix`: `docs/adr/0006-minimal-host-variants.md`.
- The OCCT and FurMark GPU benchmarks are in `modules/home/benchmarks.nix`, not `packages.nix`: they are the only place the repo fetches unversioned vendor URLs (`ocbase.com`'s `version:` path serves different bytes when the vendor rotates a build, breaking the hash), and each needs a copy-to-`XDG_DATA_HOME`-then-run shim.
- `qmd` (`pkgs/qmd`) is `buildNpmPackage` for an upstream that ships no `package-lock.json` (only `bun.lock`/`pnpm-lock.yaml`) — the lockfile was generated once via `npm install --package-lock-only` against the release tag and vendored. Native deps that ship prebuilt platform binaries (tree-sitter-*, sqlite-vec, node-llama-cpp) work fine under `buildNpmPackage`'s default `npm ci --ignore-scripts`; only deps with no prebuilt binary (better-sqlite3) need a manual `node-gyp rebuild --release` in `preBuild`. `autoPatchelfHook` fixes up the prebuilt ELF binaries; optional GPU-backend variants (CUDA/Vulkan `.so`s) are intentionally left unpatched and qmd is wrapped with `QMD_LLAMA_GPU=false` and the nixpkgs Node runtime because this package exposes the CPU search path only.

## Dotfiles / dotagents symlinks

- `~/dotfiles` and `~/dotagents` are separate repos, wired in via `config.lib.file.mkOutOfStoreSymlink` (`modules/home/dotfiles.nix`, `dotagents.nix`) so edits there apply live without a rebuild. The symlink target must be an absolute home-relative string (`${config.home.homeDirectory}/...`); a relative one breaks live-editing silently.
- Caelestia's `shell.json` is per-host (`dotfiles/caelestia/hosts/${hostname}.json`, `hostname` comes from `lib/mkHost.nix`'s specialArgs) and needs `force = true` on that `home.file` entry — caelestia's own atomic writes to the path clobber a plain symlink otherwise. `modules/home/caelestia.nix` also runs an activation script that normalizes a few keys via `jq`.

## Eye comfort

- `modules/home/nightlight.nix` enables `hyprsunset` but deliberately leaves `services.hyprsunset.settings` empty: that option writes `xdg.configFile."hypr/hyprsunset.conf"`, which collides with the whole-directory `mkOutOfStoreSymlink` `dotfiles.nix` puts at `~/.config/hypr`. The profiles live in `dotfiles/hypr/hyprsunset.conf` instead, tunable with no rebuild. `reading-mode` (bound to `mod + R` in `dotfiles/hypr/hyprland.lua`) toggles against the schedule and restores it with `hyprctl hyprsunset reset`.
Temperature and gamma need no per-monitor config: hyprsunset binds every `wl_output` and applies one CTM each, so external screens are covered as soon as they are connected.
- `modules/home/auto-brightness.nix` runs `wluma` off the ALS at `/sys/bus/iio/devices/iio:device0`, gated to the host that has one. It writes `/sys/class/backlight/*/brightness` directly, which needs the `SUBSYSTEM=="backlight"` udev rule in `modules/nixos/power.nix` - group `video` alone is not enough, and `brightnessctl` never needed it because it goes through logind.
- The external monitor has no backlight class, so its entry is an `output.ddcutil` one driven over DP AUX, which is why `power.nix` sets `hardware.i2c.enable` - that rule's `uaccess` tag is what grants access, since wluma's unit runs `PrivateUsers=true` and would lose a plain `i2c` group membership.
Two traps: `name` is matched as a *substring* of the output description, so a bare `DP-1` also matches `eDP-1` and one config steals the other's screen - `(DP-1)` with the parens does not.
And `udevadm trigger` after a rebuild needs `--subsystem-match=i2c-dev`, not `i2c`.
`identifier` is what wluma matches against the DDC display name (`ddcutil detect`), and a mismatch is only a warning, so an unplugged or swapped monitor degrades to internal-only.

## Sync timers

- Every pull-only repo sync is one entry in the `repos` list in `modules/home/repo-sync.nix` (`universe`, `dotagents`, `dotfiles`, `vault`, `password-store`), plus one `github-sync` sweep over `~/github`. Add a repo by adding a row, not a module. The shared pattern: `writeShellApplication` locks down PATH, the dirty-check uses `git status --porcelain --untracked-files=no` (counting untracked files self-deadlocks the timer), and pulls are `--ff-only`, skipped silently when dirty or diverged.
- Every timer-driven user service is declared through `services.userTimers` (`modules/home/user-timers.nix`), never as a hand-written `systemd.user.services` + `systemd.user.timers` pair.
The option generates both units and structurally guarantees `OnFailure = [ "notify-failure@%n.service" ]` (`modules/home/notify-failure.nix`), which desktop-notifies with the last 5 journal lines - a sync that silently stopped working for weeks is the failure mode that wiring exists to prevent, and it used to be a rule an agent could forget.
`onActivation` (`never` / `run` / `try`) is what decides whether home-manager activation also runs the command and whether its failure aborts the rebuild; `unitExtra` / `serviceExtra` / `wantedBy` cover the per-unit outliers. A unit with no timer at all (`zen-profile-logout-push`) stays hand-written.
- `rtk-init` and `codedb-register` (`modules/home/rtk.nix`, `codedb.nix`) re-apply the Claude Code hook/MCP registration on a daily systemd timer as a self-heal, since that config lives outside the Nix store.
- `zen-profile-sync` (`modules/home/zen-profile-sync.nix`) pulls the age-encrypted Zen profile hourly and on session start, self-seeding a fresh headless profile if none exists, and skips the pull while Zen is running rather than failing.
Push is gated to `sfx14` only (`pushHost` in that file), so every other machine is read-only and cannot clobber the blob. On sfx14 the push runs on a 30min timer *and* at logout; the timer is what matters, because a logout push has no network and no pinentry - it is why the sync was silently dead for weeks with 25 unpushed commits.
Automated commits there use `-c commit.gpgsign=false`, and a run with no new snapshot still flushes pending commits.
Neither unit is part of `nix run .#bootstrap` — see `parts/apps.nix` for what bootstrap actually clones and which timers `bootstrap-check` asserts.
- `treehouse-prune` (`modules/home/treehouse-prune.nix`) is weekly, not daily, and has no `home.activation` hook unlike its siblings above: it deletes worktree pools, so it may only ever run on its own schedule, never as a side effect of a rebuild.
Deliberately no `--prune-orphans`: treehouse cannot run its uncommitted-changes or merged-HEAD checks once a backing repo is gone, so orphans stay reported-only and are reaped by hand.

## Secrets

- Recipient/rotation rules for `modules/nixos/secrets/*.sops.yaml` are documented at the top of `.sops.yaml` — read that before touching a secret. Universe's recipients are per-host SSH keys (headless decrypt at activation), deliberately a different set from the vault repo's user-age keys.
- `tailscale-oauth` (`modules/nixos/network.nix`) is a steady-state OAuth client secret used as `authKeyFile`, not a one-shot auth key.

## CI / flake hygiene

- `nix flake check` (`parts/checks.nix`) derives its checks from `self.nixosConfigurations`, so it builds the full `toplevel` closure for every host including the `-minimal` variants, with no second host list to keep in sync. That pulls in caelestia-shell, which always compiles from source, hence the `free-disk-space` step in `.github/workflows/ci.yaml`.
- Cachix is the only extra substituter and CI must not cache the Nix store: a restored store means nothing is newly built, so `cachix-action` pushes nothing and every machine rebuilds from source. See `docs/adr/0005-cachix-only-substituter.md` before adding any store cache back.
- Dependabot + auto-merge (`.github/dependabot.yaml`, `.github/workflows/automerge.yaml`) replaced a hand-rolled flake-autoupdate timer.
- `modules/nixos/github-runner.nix` defines `services.orgRunner` and is imported directly by `hosts/pavg15/default.nix`, not by `modules/nixos/default.nix` - the self-hosted runner is one machine's job, so no other host carries it.
- `system.autoUpgrade` (`modules/nixos/auto-upgrade.nix`) deliberately points at a `git+https://` flakeref rather than `github:` - `github:` flakerefs hit the rate-limited GitHub API and can silently pin a stale rev on a 403.

## Install / bootstrap

- Full install/reinstall procedure lives in `docs/runbooks/install.md` (console) and `install-anywhere.md` (remote over tailnet) — keep those current rather than re-describing steps here.
- Host SSH keys are persistent per host, backed up in the vault repo (`~/vault/hosts/<host>/*.age`+`.pub`), and re-injected via `nixos-anywhere`/`disko-install --extra-files` on every reinstall so `sops-nix` never needs rekeying.
- `gpg-preset` (`modules/home/gpg-preset.nix`) presets the GPG passphrase into the agent at login for headless git/ssh signing — needed because gpg-agent's cache clears on reboot.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
