# Universe

Universe is personal infrastructure, not a workstation distribution.

## Ownership

- `hosts/pavg15` and `modules/nixos` own the pavg15 NixOS server.
- `hosts/sfx14` owns machine-specific sfx14 units only. It is not a workstation configuration layer.
- `agents/global.md` owns durable personal agent defaults.
- `agents/skills` owns personally authored reusable skills.
- Vault owns private identity and secret bootstrap material.
- `password-store` owns password entries.
- Omarchy owns the sfx14 operating system, desktop, packages, and baseline user configuration.
- Project repositories own their own development environments and project-specific agent instructions.

Do not reintroduce Home Manager, Omanixy, an sfx14 NixOS configuration, desktop dotfiles, harness settings, model routing, or a general workstation configuration layer without a new concrete requirement.

## Changes

- Prefer deleting obsolete machinery over adapting it.
- Keep pavg15 changes independent from workstation bootstrap and agent policy.
- Keep agent runtime directories owned by Omarchy and their harnesses. Link only the individual files or skills Universe owns.
- Never read, print, decrypt, or commit private key material or plaintext secrets.
- sfx14 `sudo` asks for a password and an agent shell has no TTY to answer it. Spawn a real terminal for the prompt instead of asking for the password in chat: write the root work to a script that tees its output to a log, launch it with `setsid -f foot --title="..." bash <script>`, then watch the log rather than handing the task back.
- Run `nix fmt` and `nix flake check` for Nix changes when Nix is available.
