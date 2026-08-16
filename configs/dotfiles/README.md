# dotfiles

Out-of-store dotfiles, symlinked into `~/.config` from my NixOS config ([universe](https://github.com/atqamz/universe), `modules/home/dotfiles.nix`) via `mkOutOfStoreSymlink`.
Edit in place, no rebuild; Hyprland hot-reloads `hypr/hyprland.lua` on save.

## Layout

Per-tool config. Anything host-specific keys off the hostname passed in by universe.

- `hypr/` - Hyprland, written in Lua (shared `hyprland.lua` + per-host `hosts/<hostname>.lua`)
- `zed/` - Zed editor
- `gtk/` - Thunar GTK theming
- `foot/`, `cava/`, `herdr/`, `rtk/`, `cs2/` - per-tool config

## License

MIT, see [LICENSE](LICENSE).
This is a personal repo: read it, fork it, open an issue.
Pull requests are not accepted, see [CONTRIBUTING.md](CONTRIBUTING.md).
