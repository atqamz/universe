# 0021. Omanixy owns desktop presentation

## Context

The desktop shell presents bars, menus, and shell surfaces, while the host configuration provides capabilities such as audio, clipboard history, screenshots, brightness, notifications, locking, and policy services.
Combining those responsibilities in one shell made a presentation-shell migration change unrelated host behavior and left keybindings coupled to shell internals.

## Decision

Universe consumes the pinned Omanixy Quattro runtime through its public Home Manager module.
Omanixy and the upstream Quattro runtime own desktop presentation.
Universe owns host capabilities, policy, packages, services, and health contracts.
Live Hyprland bindings remain in `dotfiles`, and use explicit Universe-owned consumers or the packaged Omanixy IPC wrapper.
Unsupported Quattro capability plugins remain disabled until Omanixy owns and validates them.

## Consequence

Replacing the presentation shell does not replace or duplicate Universe-owned host capability services.
Shell state and global application styling remain separate: Universe and `dotfiles` use deterministic configuration rather than reading writable Omanixy runtime theme state.
Native Quattro lock, notifications, polkit, idle, clipboard, media, brightness, and screenshot integrations remain upstream follow-up work where the pinned safety floor disables them.
Upstream later made `omarchy.clipboard` feature-gated instead of statically disabled; Universe still excludes it by selecting the shell features without `clipboard`, because clipboard history ownership has not moved.
