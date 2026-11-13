# Universe

Universe is personal infrastructure, not a workstation distribution.

## Ownership

- `hosts/pavg15` and `modules/nixos` own the pavg15 NixOS server.
- `hosts/sfx14` owns machine-specific sfx14 units only. It is not a workstation configuration layer.
- `agents/global.md` owns durable personal agent defaults. `agents/link` installs it as `~/AGENTS.md`.
- `agents/bootstrap` owns the minimal harness bootstrap files.
- `atqamz/skills` owns personally authored reusable skills. `agents/skills.ref` pins the released tag and `agents/skills-install` installs it with `gh skill`.
- Vault owns private identity and secret bootstrap material.
- `password-store` owns password entries.
- Omarchy owns the sfx14 operating system, desktop, packages, and baseline user configuration.
- Project repositories own their own development environments and project-specific agent instructions.

Do not reintroduce Home Manager, Omanixy, an sfx14 NixOS configuration, desktop dotfiles, general harness settings, model routing, or a workstation configuration layer without a new concrete requirement. The sfx14 Hyprland overrides in `hosts/sfx14/*.lua` are the only linked desktop config. The bootstrap files in `agents/bootstrap` and the OpenCode `instructions` entry are the only harness touch points.

## Always

- Before acting, load the matching skill from the harness skill list. Skills own procedures; this file owns repository invariants. Do not duplicate skill rules here.
- Write skills as strict imperative manuals. Put lookup material in `references/` and longer rationale in `docs/`.
- Prefer deleting obsolete machinery over adapting it.
- Keep pavg15 changes independent from workstation bootstrap and agent policy.
- Keep agent runtime directories owned by Omarchy and their harnesses. `agents/link` writes only `~/AGENTS.md`, its marked bootstrap files, and the OpenCode `instructions` entry; `agents/skills-install` writes skill copies through `gh skill`.
- Do not vendor skill copies back into Universe.
- Never read, print, decrypt, or commit private key material or plaintext secrets.
- sfx14 `sudo` asks for a password and an agent shell has no TTY to answer it. Spawn a real terminal for the prompt instead of asking for the password in chat: write the root work to a script that tees its output to a log, launch it with `setsid -f foot --title="..." bash <script>`, then watch the log rather than handing the task back.
- Run `nix fmt` and `nix flake check` for Nix changes when Nix is available.
- `.gitignore` is an allowlist. Add a new path before running `git status --short --ignored`, and confirm no new file is ignored.
- Write no comments in code. Keep only lines a tool reads: shebangs and linter directives. `nix flake check` enforces this.
