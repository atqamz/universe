# NixOS install runbook (USB at console)

Boot the standard NixOS minimal ISO and install a universe host from the flake.
Set the target host once and reuse it throughout:

```bash
export HOST=sfx14   # or pavg15
```

Works for any host defined in the flake. The remote tailnet-driven variant is in
`install-anywhere.md`.

## 0. Back up /home (destructive)

`disko` wipes the whole disk. If the machine is a daily driver, back up
`/home/atqa` to an external drive first:

```bash
sudo rsync -aHAX --info=progress2 /home/atqa/ /run/media/atqa/<external>/${HOST}-home/
```

Verify the copy before continuing. Everything below destroys the disk.

## Prerequisites

- A NixOS minimal ISO written to a USB (`sudo cp nixos-minimal-*.iso /dev/sdX; sync`).
- `universe` is public and cloneable via HTTPS (anon flake).
- Tailscale ACL already allows `$HOST` and your tailnet SSH access.
- `gh` authenticated on another tailnet machine (for PRs/issues if needed).
- The persistent SSH host key for `$HOST` is backed up in the private vault under
  `hosts/$HOST/` and reachable from a working tailnet machine, so it can be
  copied to the installer. It is never committed to the public repo.

## 1. Boot the installer

Boot `$HOST` from the USB, choose the NixOS installer entry, land at a root
shell.

## 2. Network

DHCP is automatic. Verify:

```bash
ping -c 3 github.com
```

For MagicDNS / tailnet:

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
nix-shell -p tailscale --run '
  sudo systemd-run --unit=tailscaled tailscaled
  sleep 3
  sudo tailscale up --ssh --qr --advertise-tags=tag:universe
'
```

If `systemd-run` is unavailable, run the daemon directly:

```bash
nix-shell -p tailscale --run '
  nohup sudo tailscaled > /tmp/tailscaled.log 2>&1 &
  sleep 3
  sudo tailscale up --ssh --qr --advertise-tags=tag:universe
'
```

## 3. Restore the persistent host SSH key

`sops-nix` decrypts `atqa-password` with the machine's SSH host key
(`/etc/ssh/ssh_host_ed25519_key`), so that key must exist and be a recipient of
the secret before first boot. We keep a persistent per-host key so the secret is
encrypted to it once and never rekeyed across reinstalls.

From a working tailnet machine that has the vault checked out, decrypt the
passphrase-protected private half and copy both to the installer:

```bash
age -d ~/vault/hosts/$HOST/ssh_host_ed25519_key.age > /tmp/ssh_host_ed25519_key
scp /tmp/ssh_host_ed25519_key ~/vault/hosts/$HOST/ssh_host_ed25519_key.pub nixos@nixos:/tmp/
shred -u /tmp/ssh_host_ed25519_key
```

On the installer, lock down the private half:

```bash
chmod 600 /tmp/ssh_host_ed25519_key
```

## 4. Install

The full closure is too large for the ISO's tmpfs, so install the `-minimal`
variant first, then switch to the full config after first boot. `--extra-files`
injects the host key before first boot; `--system-config` locks `root` so the
install does not stop on a password prompt (break-glass is `atqa`, wheel,
passwordless sudo).

```bash
lsblk
# Confirm the NVMe device is /dev/nvme0n1 before continuing.
nix run github:nix-community/disko#disko-install -- \
  --flake github:atqamz/universe#$HOST-minimal --disk main /dev/nvme0n1 \
  --extra-files /tmp/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key \
  --extra-files /tmp/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub \
  --write-efi-boot-entries \
  --system-config '{"users":{"users":{"root":{"hashedPassword":"!"}}}}'
```

disko partitions (EFI + plain 32G swap for hibernate + BTRFS root/home/nix),
copies the closure and host key, installs the bootloader, writes the EFI entry.

## 5. Reboot

```bash
reboot
```

Remove the USB. The minimal config has no display manager, so the machine boots
to a text login console (getty). The graphical `greetd` -> `tuigreet` greeter
appears only after the full config is applied in step 9.

## 6. First login

The injected host key lets `sops-nix` decrypt `atqa-password` on first boot. At
the text console, log in as `atqa` with the initial password (`1234`); change it
after.

If login fails, from a TTY:

```bash
sudo ls -l /run/secrets-for-users/atqa-password
journalctl -b -u sops-install-secrets
```

Missing file -> the injected host key is not the secret's recipient. Confirm its
age (`ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`) matches the `age:` entry
for this host in `.sops.yaml`.

## 7. Bootstrap L0/L1 secrets

```bash
nix run --extra-experimental-features 'nix-command flakes' github:atqamz/universe#secrets-bootstrap
```

Clones `~/vault` and runs `import.sh`, populating age/GPG/SSH keys, git signing
config, and the gpg preset passphrase (`~/.gnupg/.preset-passphrase`, 0400) so
the `gpg-preset` login service unlocks the auth/sign subkeys headlessly after
each reboot. Verify:

```bash
ssh-add -l
gh auth status
gpg -K
```

## 8. Bootstrap brain / dotai

```bash
nix run github:atqamz/universe#brain-bootstrap
```

Clones `~/dotai` and `~/brain` and builds the qmd index.

## 9. Apply full config

```bash
cd ~/universe || git clone https://github.com/atqamz/universe.git ~/universe
cd ~/universe
sudo nixos-rebuild switch --flake .#$HOST
```

## 10. Verify e2e

```bash
nix run .#bootstrap-check
```

It reports pass/fail for the `atqa` user and groups, tailscale, sshd, the
secrets/brain bootstrap state, `ollama.service`, the `brain-promote` dry-run, the
sync timers, and a clean `greetd`/`hyprland` start.

## 11. Authorize Ollama cloud

```bash
ollama signin
```

Open the printed URL in a browser logged into ollama.com. Then:

```bash
systemctl --user restart ollama
BRAIN_PROMOTE_DRY_RUN=1 brain-promote
```

## 12. Verify hibernate

```bash
systemctl hibernate
```

Power back on; the prior session should resume. Hibernate uses the plain 32G
swap partition (`boot.resumeDevice = /dev/disk/by-partlabel/disk-main-swap`).

## 13. Final validation

```bash
sudo reboot
```

After login, run `nix run .#bootstrap-check` again.

## Troubleshooting

### `nixos-install` cannot fetch flake

Use a local clone path:

```bash
nixos-install --flake /tmp/universe#$HOST
```

### sops-nix fails to decrypt password

The injected host key must be the recipient of `atqa-password`. Confirm the age
of the injected `ssh_host_ed25519_key.pub` (via `ssh-to-age`) matches the `age:`
recipient for this host in `.sops.yaml`. The persistent host key means this never
changes across reinstalls -- a mismatch means the wrong key was copied. Re-run
the scp + `--extra-files` step with the vault-backed key.

### Hyprland session does not start

Check `journalctl --user -u greetd` and `journalctl --user -u hyprland-session`.
Common causes: NVIDIA modules not loaded, missing firmware, `uwsm` syntax
mismatch, or wrong PRIME bus IDs in `hosts/$HOST/default.nix`.

### `brain-promote` fails with Unauthorized

Ollama cloud is not signed in. See step 11.

### `github ssh auth` fails after a reboot

git-over-ssh uses the gpg-agent `[A]` auth subkey; gpg-agent clears its cache on
reboot. The `gpg-preset` user service presets the passphrase at login from
`~/.gnupg/.preset-passphrase`. If it fails:

```bash
systemctl --user status gpg-preset
ls -l ~/.gnupg/.preset-passphrase
```

Missing file -> `secrets-bootstrap` did not place it; the vault must contain
`gpg/passphrase.sops.txt`.

### Hibernate does not resume

Confirm the swap partition is plain (no `randomEncryption` -- a per-boot random
key makes resume impossible) and large enough for RAM. `boot.resumeDevice` must
point at `/dev/disk/by-partlabel/disk-main-swap`. Check `journalctl -b | grep -i
resume`.
