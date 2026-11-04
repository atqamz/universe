# universe

Personal infrastructure for one NixOS server and a small amount of portable personal agent policy.

`AGENTS.md` defines what Universe owns and what it leaves to Omarchy, Vault, and password-store. `docs/workstation.md` covers fresh Omarchy bootstrap.

## pavg15

Build or switch the server with:

```bash
sudo nixos-rebuild switch --flake .#pavg15
```

The server uses Disko, sops-nix, Tailscale, and automatic upgrades.

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
