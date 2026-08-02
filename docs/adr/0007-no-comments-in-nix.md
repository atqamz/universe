# 0007. Nix files carry no comments; rationale lives here

## Context

The repo rule is no comments in `.nix`, stricter than the global rule: none at all, not even a "why".
In practice a few load-bearing whys accumulated as inline comments anyway, because they were genuinely worth recording and there was nowhere else to put them.
The repo ended up in the worst of both states: a rule that was not followed, and rationale scattered where nobody greps for it.

## Decision

Keep the rule. Give the rationale a home: this directory for decisions, `AGENTS.md` for the resulting rules, the top of `.sops.yaml` for recipient policy.
The only thing allowed in a `.nix` file is a functional pragma, such as `# shellcheck disable=`, which `writeShellApplication` needs at build time.

## Consequence

The two comments that existed were moved here.

`modules/home/nix-access-token.nix` writes `~/.config/nix/nix.conf` with an absolute `!include`, not a relative one: `nix.conf` is a store symlink, so a relative include resolves against the store directory.
It also sets `tarball-ttl = 0`, because authentication alone does not make `nix run github:owner/repo` current -- the default 3600s cache serves a pre-merge build for an hour afterwards with no warning and an unchanged version string.
The cost is a conditional GET per flake call, and a flake ref cannot resolve at all while offline.

`modules/home/file-management.nix` sets `xdg.configFile."mimeapps.list".force = true` because its own activation step turns the managed symlink into a real writable file, so each switch would otherwise back it up to `mimeapps.list.bak` and collide with the previous backup.
Same reason as the `force = true` entries in `dotfiles.nix` and `dotagents.nix`; see ADR 0003.
