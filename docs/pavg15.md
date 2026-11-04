# pavg15

pavg15 is the only NixOS host managed by Universe.

## Secrets

System secrets under `modules/nixos/secrets` decrypt headlessly from the persistent SSH host key via sops-nix. The personal GPG key remains a recovery/edit recipient. The host key must therefore be restored before rebuilding a replacement server; Vault owns its recovery copy.

## Cache

`atqamz-universe.cachix.org` is the only extra Nix substituter. CI builds the pavg15 toplevel and pushes through the matching Cachix workflow. Do not add a competing GitHub Actions store cache that can make CI green without producing Cachix paths.

## Disks

The NVMe disk is the Disko layout in `hosts/disko.nix`. The second disk's btrfs partition (`/dev/sda2`, UUID `7cdaecc2-1294-4c50-9f49-0a5b29ca9dbd`) is not mounted by this configuration; it is free for reuse.

## Auto-upgrade

`nixos-upgrade.service` runs hourly and switches pavg15 to `main`. A kernel, initrd, or kernel module change applies only at the next reboot. `readlink /run/booted-system/kernel /run/current-system/kernel` shows whether one is pending.

The switch restarts `tailscale-bootstrap.service` when the `tailscaled-autoconnect` or `tailscaled-set` unit changes, because a switch does not otherwise re-apply `services.tailscale.extraSetFlags`.

To apply `main` now, on pavg15:

```sh
sudo systemctl start --no-block nixos-upgrade.service
journalctl -fu nixos-upgrade
```
