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

If the machine is on the tailnet and you need MagicDNS, start `tailscaled` and
authenticate:

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
nix-shell -p tailscale --run '
  sudo systemd-run --unit=tailscaled tailscaled
  sleep 3
  sudo tailscale up --ssh
'
```

If `systemd-run` is unavailable, run the daemon in the background directly:

```bash
nix-shell -p tailscale --run '
  nohup sudo tailscaled > /tmp/tailscaled.log 2>&1 &
  sleep 3
  sudo tailscale up --ssh --qr
'
```

## 3. Prepare disk with disko

The disk layout is declared in `hosts/pavg15/disko.nix`. It wipes `/dev/nvme0n1`,
creates an EFI system partition, a LUKS-randomized swap partition, and a single
BTRFS volume with `root`, `home`, and `nix` subvolumes.

**This wipes the disk.** Ensure `/home/atqa` is backed up if you want to keep
it.

The full `pavg15` closure is too large to build inside the NixOS minimal ISO's
tmpfs, so install the `pavg15-minimal` configuration first, then switch to the
full config after first boot.

```bash
lsblk
# Confirm the NVMe device is /dev/nvme0n1 before continuing.
nix run --extra-experimental-features 'nix-command flakes' github:nix-community/disko#disko-install -- --flake https://github.com/atqamz/universe.git#pavg15-minimal --disk main /dev/nvme0n1
```

If GitHub rate-limits the flake fetch, clone first:

```bash
git clone https://github.com/atqamz/universe.git /tmp/universe
cd /tmp/universe
nix run --extra-experimental-features 'nix-command flakes' github:nix-community/disko#disko-install -- --flake .#pavg15-minimal --disk main /dev/nvme0n1
```

`disko-install` will partition, format, mount everything at `/mnt`, and then
run `nixos-install` for you.

## 4. Set root password

`disko-install` runs `nixos-install` internally and prompts for the `root`
password. Set one for emergency break-glass only; normal login uses `atqa`
via the `sops` secret.

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

## 9. Apply full config

The ISO installed `pavg15-minimal`. After first boot, switch to the full
`pavg15` configuration:

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
