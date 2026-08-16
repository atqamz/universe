# dotfiles

Out-of-store live-editable application configuration, part of the [universe](https://github.com/atqamz/universe) monorepo at `universe/configs/dotfiles`.
Universe links it into `~/.config` from `modules/home/dotfiles.nix` via `mkOutOfStoreSymlink`.
Edit in place, no rebuild; Hyprland hot-reloads `hypr/hyprland.lua` on save.

## Layout

Per-tool config. Anything host-specific keys off the hostname passed in by universe.

- `hypr/` - Hyprland, written in Lua (shared `hyprland.lua` + per-host `hosts/<hostname>.lua`)
- `zed/` - Zed editor
- `gtk/` - Thunar GTK theming
- `foot/`, `cava/`, `herdr/`, `rtk/`, `cs2/` - per-tool config

## License

MIT, see the universe [LICENSE](../LICENSE).
Pull requests are not accepted; see the universe [CONTRIBUTING.md](../CONTRIBUTING.md).
