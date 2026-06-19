# pavg15 NixOS reinstall runbook

Boot the standard NixOS minimal ISO and reinstall `pavg15` from the universe
flake. This is the e2e gate for migrating `sfx14` to NixOS.

## Prerequisites

- `~/Downloads/nixos-minimal-26.05.1183.6b316287bae2-x86_64-linux.iso` copied to
  a USB with `cp` or `dd`.
- `universe` repo is public and cloneable via HTTPS (anon flake).
- Tailscale ACL already allows `pavg15` and your tailnet SSH access.
- `gh` is authenticated in your tailnet (via another machine) so you can open
  PRs/issues if needed.

## 1. Boot the installer

```bash
# From a working machine, write the ISO to a USB.
sudo cp ~/Downloads/nixos-minimal-26.05.1183.6b316287bae2-x86_64-linux.iso /dev/sdX
sync
```

Boot pavg15 from the USB. Choose the NixOS installer entry. You will land at a
root shell.

## 2. Network

The ISO uses DHCP by default. Verify:

```bash
ping -c 3 github.com
```

If the machine is on the tailnet and you need MagicDNS, you can run:

```bash
nix run nixpkgs#tailscale -- up --ssh
```

## 3. Prepare disk

Current pavg15 layout (BTRFS on one NVMe, separate ESP, swap partition). You
can either reuse the existing subvolumes or wipe and recreate.

### Option A: reuse existing subvolumes (faster, preserves `/home`)

```bash
lsblk
# Example: NVMe at /dev/nvme0n1, ESP at /dev/nvme0n1p1, root subvol at /dev/nvme0n1p2
mount /dev/disk/by-uuid/8af27f86-7b1c-4981-a94b-435bc553c01e /mnt -o subvol=root
mkdir -p /mnt/boot /mnt/home /mnt/nix
mount /dev/disk/by-uuid/37A8-FAF8 /mnt/boot
mount /dev/disk/by-uuid/8af27f86-7b1c-4981-a94b-435bc553c01e /mnt/home -o subvol=home
mount /dev/disk/by-uuid/8af27f86-7b1c-4981-a94b-435bc553c01e /mnt/nix -o subvol=nix
swapon /dev/disk/by-uuid/ffe1203e-f8c7-4fa1-95c7-7406fb87ae29
```

### Option B: full wipe

Only do this if `/home/atqa` is backed up or you intend to restore later.

```bash
# Wipe existing filesystems and recreate partitions with your preferred tool
# (fdisk/gdisk/parted), then:
mkfs.vfat -F 32 -n boot /dev/nvme0n1p1
mkfs.btrfs -L nixos /dev/nvme0n1p2
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
umount /mnt
mount /dev/nvme0n1p2 /mnt -o subvol=root
mkdir -p /mnt/boot /mnt/home /mnt/nix
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/nvme0n1p2 /mnt/home -o subvol=home
mount /dev/nvme0n1p2 /mnt/nix -o subvol=nix
mkswap /dev/nvme0n1p3
swapon /dev/nvme0n1p3
```

## 4. Install

```bash
# Enable flakes in the installer environment.
nix-shell -p git nixos-install-tools --run "nixos-install --flake https://github.com/atqamz/universe.git/pavg15"
```

If HTTPS flake fetch is slow or unavailable, clone first:

```bash
git clone https://github.com/atqamz/universe.git /tmp/universe
cd /tmp/universe
nixos-install --flake .#pavg15
```

Set the `root` password when prompted (only for emergency; normal login uses
`atqa` via `sops` secret).

## 5. Reboot

```bash
reboot
```

Remove the USB. The machine should boot into `greetd` → `tuigreet`.

## 6. First login

The `atqa` user password is read from `/run/secrets/atqa-password` via
`sops-nix` using the host SSH key. Type the current password.

If login fails, check from a TTY:

```bash
journalctl -u systemd-cryptsetup@...
# or for sops-nix:
sudo cat /run/secrets/atqa-password
```

## 7. Bootstrap L0/L1 secrets

Login as `atqa`, open a terminal:

```bash
nix run --extra-experimental-features 'nix-command flakes' github:atqamz/universe#secrets-bootstrap
```

This clones `~/secrets` and runs `import.sh`, populating:

- age keys
- GPG keys
- SSH keys / authorized keys
- Git signing config

Verify:

```bash
ssh-add -l
gh auth status
gpg -K
```

## 8. Bootstrap brain / dotai

```bash
nix run github:atqamz/universe#brain-bootstrap
```

This clones `~/dotai` and `~/brain` and builds the qmd index.

## 9. Apply full config (if not already)

If you installed from the live flake, the full config is already active. To
update or repair:

```bash
cd ~/universe || git clone https://github.com/atqamz/universe.git ~/universe
cd ~/universe
sudo nixos-rebuild switch --flake .#pavg15
```

## 10. Verify e2e

Run the built-in check:

```bash
nix run .#bootstrap-check
```

It reports pass/fail for:

- `atqa` user exists with correct groups
- `tailscale` is up (`tailscale status`)
- `sshd` / tailscale-ssh reachable
- `secrets-bootstrap` state present (`~/secrets/.git`, `~/.ssh/id_ed25519.pub`)
- `brain-bootstrap` state present (`~/brain/.git`, `~/dotai/.git`, qmd index)
- `ollama.service` is active and `/api/tags` responds
- `brain-promote` dry-run reaches ollama and completes
- `secrets-sync`, `brain-sync`, `flake-autoupdate`, `brain-promote` timers are
  enabled
- `greetd`/`hyprland` session can start (no config errors)

## 11. Authorize Ollama cloud

The first boot starts `ollama.service` but it is not signed in. Run:

```bash
ollama signin
```

Open the printed URL in a browser already logged into ollama.com. Then:

```bash
systemctl --user restart ollama
BRAIN_PROMOTE_DRY_RUN=1 brain-promote
```

If this succeeds, the daily 04:00 timer will work.

## 12. Optional: connect WARP

```bash
warp-cli registration new
warp-cli connect
```

## 13. Final validation

Reboot once more and confirm everything survives:

```bash
sudo reboot
```

After login, run `nix run .#bootstrap-check` again.

## Troubleshooting

### `nixos-install` cannot fetch flake

Use the local clone path:

```bash
nixos-install --flake /tmp/universe#pavg15
```

### sops-nix fails to decrypt password

The host SSH key must match the one in `secrets/age/keys.txt.gpg` / the sops
recipient list. After `secrets-bootstrap`, the imported age key must include the
host fingerprint. If reinstalling changes host keys, re-encrypt the password
secret on another machine.

### Hyprland session does not start

Check `journalctl --user -u greetd` and `journalctl --user -u hyprland-session`.
Common causes: NVIDIA modules not loaded, missing firmware, or `uwsm` command
syntax mismatch.

### `brain-promote` fails with Unauthorized

Ollama cloud is not signed in. See step 11.
