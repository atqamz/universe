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

Universe owns `agents/global.md`, the bootstrap files in `agents/bootstrap`, and the `agents/skills.ref` pin. Skill content lives in `atqamz/skills` and is installed with `gh skill`.

On an Omarchy workstation after cloning Universe:

```bash
~/universe/agents/link
~/universe/agents/skills-install
```

`agents/link` installs `~/AGENTS.md`, writes the marked bootstrap files for Claude Code, Codex, and omp, and adds `~/AGENTS.md` to OpenCode's `instructions`. `agents/skills-install` installs the pinned `atqamz/skills` release into `~/.agents/skills`, `~/.claude/skills`, and `~/.config/opencode/skills`. Pinned skills are skipped by `gh skill update`; bump `agents/skills.ref` to move them.

## Develop

```bash
nix develop
nix fmt
nix flake check
```
