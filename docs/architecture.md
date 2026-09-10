# Architecture

Universe is personal infrastructure, not a workstation distribution.

Ownership is explicit:

- Omarchy owns the sfx14 operating system, desktop, packages, and baseline user experience.
- Universe owns the pavg15 NixOS server configuration and personally authored agent policy/skills.
- Vault owns private identity and secret bootstrap material.
- password-store owns password entries.
- Each project owns its own development environment and project-specific agent instructions.

Universe does not restore or freeze Omarchy configuration. Do not add Home Manager, Omanixy, sfx14 NixOS configuration, or a general dotfile manager to recreate the workstation state.

Personal agent policy is deliberately narrower than dotfiles. `agents/global.md` is linked into each harness's native global-instruction path. Personally authored skills live once under `agents/skills` and are linked per skill into shared runtime skill directories so Omarchy and the harnesses can continue managing their own entries.
