# universe

Personal NixOS configuration as a flake.

## Hosts

| Host   | Description                          |
| ------ | ------------------------------------ |
| pavg15 | HP Pavilion Gaming 15 — Hyprland + caelestia |

## Layout

- `flake.nix` — inputs + flake-parts entry point
- `parts/` — flake-parts modules (hosts, formatter, checks, dev shell)
- `hosts/<name>/` — host-specific config + generated hardware
- `modules/nixos/` — one-concern system modules
- `modules/home/` — one-concern Home-Manager modules
- `lib/mkHost.nix` — host factory (wires Home-Manager as a NixOS module)

## Build

```bash
sudo nixos-rebuild switch --flake .#pavg15
```

## Develop

```bash
nix develop      # or: direnv allow
nix fmt          # format
nix flake check  # lint + build checks
```
