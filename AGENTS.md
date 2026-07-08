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

## Packaging

- `codedb` and `no-mistakes` are packaged via a nixpkgs overlay (`modules/nixos/overlays.nix` -> `pkgs/codedb`, `pkgs/no-mistakes`). `codedb` is a prebuilt release binary; its own `update`/`nuke` subcommands don't apply under Nix — bump the version with `nix-update` (uses `passthru.updateScript`).
- `claude` (`modules/home/packages.nix`) wraps sadjow's `claude-code` flake input and prefixes PATH with a bun-backed `node` shim — NixOS has no system JS runtime, and Claude plugin hooks that shell out to `node` need one.
- `unityhub` (same file) prefixes `ffmpeg` onto PATH so Unity's FSBTool can encode WebGL AAC audio.

## Dotfiles / dotagents symlinks

- `~/dotfiles` and `~/dotagents` are separate repos, wired in via `config.lib.file.mkOutOfStoreSymlink` (`modules/home/dotfiles.nix`, `dotagents.nix`) so edits there apply live without a rebuild. The symlink target must be an absolute home-relative string (`${config.home.homeDirectory}/...`); a relative one breaks live-editing silently.
- Caelestia's `shell.json` is per-host (`dotfiles/caelestia/hosts/${hostname}.json`, `hostname` comes from `lib/mkHost.nix`'s specialArgs) and needs `force = true` on that `home.file` entry — caelestia's own atomic writes to the path clobber a plain symlink otherwise. `modules/home/caelestia.nix` also runs an activation script that normalizes a few keys via `jq`.

## Sync timers

- The `*-sync` services (`modules/home/dotfiles-sync.nix`, `dotagents-sync.nix`, and siblings) share one pattern: `writeShellApplication` locks down PATH, the dirty-check uses `git status --porcelain --untracked-files=no` (counting untracked files self-deadlocks the timer), and pulls are `--ff-only`, skipped silently when dirty or diverged.
- `rtk-init` and `codedb-register` (`modules/home/rtk.nix`, `codedb.nix`) re-apply the Claude Code hook/MCP registration on a daily systemd timer as a self-heal, since that config lives outside the Nix store.
- `zen-profile-sync` (`modules/home/zen-profile.nix`) pulls the synced Zen profile on session start, self-seeding a fresh headless profile first if none exists; push runs on logout. Neither is part of `nix run .#bootstrap` — see `parts/apps.nix` for what bootstrap actually clones.

## Secrets

- Recipient/rotation rules for `modules/nixos/secrets/*.sops.yaml` are documented at the top of `.sops.yaml` — read that before touching a secret. Universe's recipients are per-host SSH keys (headless decrypt at activation), deliberately a different set from the vault repo's user-age keys.
- `tailscale-oauth` (`modules/nixos/network.nix`) is a steady-state OAuth client secret used as `authKeyFile`, not a one-shot auth key.

## CI / flake hygiene

- `nix flake check` (`parts/checks.nix`) builds the full `toplevel` closure for every host, including the `-minimal` variants — this pulls in caelestia-shell, which always compiles from source (no upstream Cachix), hence the `free-disk-space` step and capped `cache-nix-action` size in `.github/workflows/ci.yml`.
- Dependabot + auto-merge (`.github/dependabot.yml`, `.github/workflows/automerge.yml`) replaced a hand-rolled flake-autoupdate timer.
- `system.autoUpgrade` (`modules/nixos/auto-upgrade.nix`) deliberately points at a `git+https://` flakeref rather than `github:` — `github:` flakerefs hit the rate-limited GitHub API and can silently pin a stale rev on a 403.

## Install / bootstrap

- Full install/reinstall procedure lives in `docs/runbooks/install.md` (console) and `install-anywhere.md` (remote over tailnet) — keep those current rather than re-describing steps here.
- Host SSH keys are persistent per host, backed up in the vault repo (`~/vault/hosts/<host>/*.age`+`.pub`), and re-injected via `nixos-anywhere`/`disko-install --extra-files` on every reinstall so `sops-nix` never needs rekeying.
- `gpg-preset` (`modules/home/gpg-preset.nix`) presets the GPG passphrase into the agent at login for headless git/ssh signing — needed because gpg-agent's cache clears on reboot.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
