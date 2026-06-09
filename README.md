# universe

NixOS configuration.

## Hosts

- **pavg15** — Hyprland + caelestia shell. AMD Renoir iGPU primary (eDP-1), NVIDIA GTX 1650 offload-only (HDMI). greetd + tuigreet + uwsm. home-manager as a NixOS module.

## Layout

| File | Purpose |
| --- | --- |
| `flake.nix` | Inputs (nixpkgs unstable, home-manager, caelestia-shell, zen-browser) and `nixosConfigurations`. |
| `configuration.nix` | System: boot, GPU, login, audio, networking. |
| `home.nix` | home-manager: caelestia shell, hyprland config, apps, cursor. |
| `hardware-configuration.nix` | Generated hardware/filesystem config for pavg15. |

## Build

```sh
sudo nixos-rebuild switch --flake .#pavg15
```
