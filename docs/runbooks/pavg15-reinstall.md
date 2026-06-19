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
- The persistent SSH host key is available on a working tailnet machine (it is
  backed up in the private vault under `hosts/pavg15/`) so it can be copied to
  the installer over the tailnet. It is never committed to the public repo.

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
  sudo tailscale up --ssh --qr
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

### Restore the persistent host SSH key

`sops-nix` decrypts `atqa-password` with the machine's SSH host key
(`/etc/ssh/ssh_host_ed25519_key`), so that key must already exist *and* be the
recipient of the secret before first boot. We keep a persistent per-host key so
the secret is encrypted to it once and never rekeyed across reinstalls. The key
is kept private (in the vault under `hosts/pavg15/`), never committed to the
public repo, and copied to the installer over the tailnet at install time.

From a working tailnet machine that has the key checked out, copy both halves to
the installer (the ISO must be on the tailnet -- see step 2):

```bash
scp ssh_host_ed25519_key ssh_host_ed25519_key.pub nixos@pavg15:/tmp/
```

Then on the ISO, lock down the private half:

```bash
chmod 600 /tmp/ssh_host_ed25519_key
```

### Install

`--extra-files` copies the host key into the new system before first boot.
`--system-config` locks `root` so `nixos-install` does not stop on an
interactive password prompt; break-glass is `atqa` (wheel, passwordless sudo).

```bash
lsblk
# Confirm the NVMe device is /dev/nvme0n1 before continuing.
nix run github:nix-community/disko#disko-install -- \
  --flake github:atqamz/universe#pavg15-minimal --disk main /dev/nvme0n1 \
  --extra-files /tmp/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key \
  --extra-files /tmp/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub \
  --write-efi-boot-entries \
  --system-config '{"users":{"users":{"root":{"hashedPassword":"!"}}}}'
```

`disko-install` partitions, formats, mounts at `/mnt`, copies the closure and
the extra files, installs the bootloader, and writes the EFI boot entry.

## 4. Reboot

```bash
reboot
```

Remove the USB. The machine should boot into `greetd` → `tuigreet`.

## 5. First login

Because the persistent host key was injected at install, `sops-nix` decrypts
`atqa-password` on first boot. Log in as `atqa` with the initial password
(`1234`) and change it afterwards.

If login fails, check from a TTY that the secret materialised:

```bash
sudo ls -l /run/secrets-for-users/atqa-password
journalctl -b -u sops-install-secrets
```

If the file is missing, the injected host key does not match the secret's
recipient -- confirm the key copied to the installer is the same one whose age
is listed in `.sops.yaml`.

## 6. Bootstrap L0/L1 secrets

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

## 7. Bootstrap brain / dotai

```bash
nix run github:atqamz/universe#brain-bootstrap
```

This clones `~/dotai` and `~/brain` and builds the qmd index.

## 8. Apply full config

The ISO installed `pavg15-minimal`. After first boot, switch to the full
`pavg15` configuration:

```bash
cd ~/universe || git clone https://github.com/atqamz/universe.git ~/universe
cd ~/universe
sudo nixos-rebuild switch --flake .#pavg15
```

## 9. Verify e2e

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

## 10. Authorize Ollama cloud

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

## 11. Optional: connect WARP

```bash
warp-cli registration new
warp-cli connect
```

## 12. Final validation

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

The injected host key must be the recipient of `atqa-password`. Confirm the age
of the injected `ssh_host_ed25519_key.pub` (via `ssh-to-age`) matches the `age:`
recipient in `.sops.yaml`. The persistent host key means this never changes
across reinstalls -- if it mismatches, the wrong key was copied to the installer.
Re-run the scp + `--extra-files` step with the vault-backed key.

### Hyprland session does not start

Check `journalctl --user -u greetd` and `journalctl --user -u hyprland-session`.
Common causes: NVIDIA modules not loaded, missing firmware, or `uwsm` command
syntax mismatch.

### `brain-promote` fails with Unauthorized

Ollama cloud is not signed in. See step 10.
