# universe

Personal NixOS configuration as a flake.

Hyprland + [caelestia](https://github.com/caelestia-dots/shell) desktop across two laptops, built with flake-parts, home-manager, sops-nix, and disko.

## Hosts

Each host builds a full variant and a stripped `-minimal` variant.

| Host   | Machine                              | Desktop              |
| ------ | ------------------------------------ | -------------------- |
| pavg15 | HP Pavilion Gaming 15-ec1047ax (AMD) | Hyprland + caelestia |
| sfx14  | Acer Swift X SFX14-72G-79PY          | Hyprland + caelestia |

## Layout

- `flake.nix` - inputs and flake-parts entry point
- `parts/` - flake-parts modules (hosts, formatter, checks, dev shell, apps)
- `hosts/<name>/` - host-specific config and generated hardware; `hosts/disko.nix` is the shared disk layout
- `modules/nixos/` - one-concern system modules (`default.nix` full, `minimal.nix` base)
- `modules/home/` - one-concern home-manager modules
- `lib/mkHost.nix` - host factory, wires home-manager in as a NixOS module

Config that must stay live-editable (dotfiles, agent config) is symlinked out of the store from the sibling [dotfiles](https://github.com/atqamz/dotfiles) and [dotagents](https://github.com/atqamz/dotagents) repos.

## Build

```bash
sudo nixos-rebuild switch --flake .#<host>
```

## Install

Fresh install or reinstall of a host: `docs/runbooks/install.md` (USB at the console) or `docs/runbooks/install-anywhere.md` (remote over the tailnet).

## Develop

```bash
nix develop      # or: direnv allow
nix fmt          # format
nix flake check  # lint and build every host
```

## License

MIT, see [LICENSE](LICENSE).
This is a personal repo: read it, fork it, open an issue.
Pull requests are not accepted, see [CONTRIBUTING.md](CONTRIBUTING.md).
