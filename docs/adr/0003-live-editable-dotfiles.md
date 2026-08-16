# 0003. Dotfiles are out-of-store symlinks, not store copies

## Context

Home-manager's default is to copy config into the store and symlink to it.
That makes every tweak to a Hyprland binding or a Zed setting a rebuild.
For config that is iterated on interactively, the rebuild cost dominates.

## Decision

Link `~/universe/configs/dotfiles` and `~/universe/configs/dotagents` content with `config.lib.file.mkOutOfStoreSymlink` so edits apply live.
The target must be an absolute home-relative string (`${config.home.homeDirectory}/universe/configs/...`); a relative target breaks live editing silently.

Files that the owning application rewrites in place (`mimeapps.list`, agent `settings.json`) additionally need `force = true`.
Without it, the app's atomic write replaces the symlink, and the next activation tries to back the real file up to `.bak`, collides with the previous backup, and fails.

## Consequence

Reproducibility is traded for iteration speed on config only, never on packages.
A fresh machine is not complete until the normal `~/universe` checkout is present, which is why `doctor` asserts the canonical `configs/dotfiles` and `configs/dotagents` subtrees exist and that live links resolve into them.
