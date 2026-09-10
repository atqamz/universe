# universe

Personal infrastructure for one NixOS server and a small amount of portable personal agent policy.

## Ownership

- `pavg15`: NixOS server managed by this flake.
- `sfx14`: Omarchy workstation. Universe does not manage its desktop or baseline `~/.config`.
- `agents/`: global personal agent defaults and personally authored skills.
- `vault`: private identity and secret bootstrap, in its own repository.
- `password-store`: password entries, in its own repository.

See `docs/architecture.md` for the boundary and `docs/workstation.md` for fresh Omarchy bootstrap.

## pavg15

Build or switch the server with:

```bash
sudo nixos-rebuild switch --flake .#pavg15
```

The server continues to use Disko, sops-nix, Tailscale, automatic upgrades, and its CI runner configuration.

## Agents

Universe does not manage Claude Code, Codex, or OpenCode settings. It only owns `agents/global.md` and the skills under `agents/skills`.

On an Omarchy workstation after cloning Universe:

```bash
~/universe/agents/link
```

The linker refuses to overwrite existing real files or foreign symlinks.

## Develop

```bash
nix develop
nix fmt
nix flake check
```
