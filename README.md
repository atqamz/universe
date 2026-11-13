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

Universe owns `agents/global.md`, the bootstrap files in `agents/bootstrap`, and the skills under `agents/skills`. It does not install external skill managers or refresh timers.

On an Omarchy workstation after cloning Universe:

```bash
~/universe/agents/link
```

The linker installs `~/AGENTS.md`, writes the marked bootstrap files for Claude Code, Codex, and omp, adds `~/AGENTS.md` to OpenCode's `instructions`, and links each skill into `~/.agents/skills`, `~/.claude/skills`, and `~/.codex/skills`. It refuses to replace an existing real file or a foreign symlink.

## Develop

```bash
nix develop
nix fmt
nix flake check
```
