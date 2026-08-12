# 0017. Foot is the default terminal and WezTerm is the graphical backup

## Context

The workstation's ordinary terminal path used WezTerm's native Wayland and GPU renderer.
Foot was already installed and configured as a lightweight alternative, but it was not the desktop default.

The two GUI terminals should provide different recovery paths when one terminal or one client-side graphics backend is unhealthy.

## Decision

Foot is the normal desktop terminal.
It remains a direct, independent process per launch with server mode disabled, and it uses native Wayland through its existing live configuration.

WezTerm remains installed as an explicit alternate terminal.
Its declarative configuration disables native Wayland and selects the `Software` frontend, so it uses XWayland and software rasterization instead of sharing Foot's native-Wayland path or relying on GPU rendering.

The desktop configuration owns which terminal launches by default, while Universe owns package enablement and WezTerm behavior.

## Consequence

The normal shell surface has a smaller and more predictable client-side failure domain.
WezTerm remains available for workflows that need it and can serve as a distinct graphical recovery path.

The split does not claim to solve a compositor, kernel, or GPU failure that affects the whole graphical session.
A Linux virtual terminal remains the recovery path when the compositor itself is unavailable.

The change is cross-repository and ordered.
The paired `dotfiles` change (atqamz/dotfiles#9) must merge before this configuration is applied to a machine, because that repository owns the keybinds and the Caelestia launcher.
Applying Universe first would put WezTerm on XWayland and software rasterization while it is still the terminal the desktop launches by default.
