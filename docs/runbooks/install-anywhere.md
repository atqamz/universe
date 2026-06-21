# NixOS install runbook (remote, over the tailnet)

Same install as `install.md`, driven from another working machine over the
tailnet for when a console isn't convenient. Only boot + install differ;
post-boot bootstrap is identical -- continue from `install.md` step 6.

## 0. Back up /home (destructive)

Same as `install.md` step 0. The disk wipe is irreversible.

## 1. At the console: minimal bring-up

You still need brief console access to boot the ISO and get it on the tailnet
(the installer has no remote access until tailscale is up):

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
nix-shell -p tailscale --run '
  sudo systemd-run --unit=tailscaled tailscaled
  sleep 3
  sudo tailscale up --ssh --qr --advertise-tags=tag:universe
'
```

Authenticate via the QR / URL. Once `tailscale status` shows the installer, the
console is no longer needed.

## 2. Verify ssh from the working machine

```bash
export TARGET=nixos # or machine name registered on tailscale, can be "nixos-1"
export HOST=sfx14   # or pavg15
```

```bash
ssh nixos@$TARGET true
```

Tailscale SSH authenticates by tailnet identity; no password. The live `nixos`
user has passwordless sudo.

## 3. Install (remote, one shot)

Run entirely from the working machine, which has the vault at `~/vault` and an
`~/universe` checkout. The persistent host key is staged into a temp dir
mirroring its target path and handed to `nixos-anywhere --extra-files`, which
copies it into the new system before first boot so `sops-nix` can decrypt
`atqa-password`. The private half is passphrase-encrypted in the vault, so
decrypt it first.

`nixos-anywhere` detects the already-booted installer and **skips kexec**, so
nothing drops the network -- the install runs over the existing tailnet ssh,
WiFi included. It partitions and mounts the real disk via `disko`, then copies
the full closure (built on the working machine) straight to the mounted target
store. No ISO tmpfs limit, so there is no `-minimal` stage here: the full
`.#$HOST` config installs directly.

```bash
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
install -d -m755 "$tmp/etc/ssh"
age -d ~/vault/hosts/$HOST/ssh_host_ed25519_key.age > "$tmp/etc/ssh/ssh_host_ed25519_key"
chmod 600 "$tmp/etc/ssh/ssh_host_ed25519_key"
cp ~/vault/hosts/$HOST/ssh_host_ed25519_key.pub "$tmp/etc/ssh/ssh_host_ed25519_key.pub"

cd ~/universe
nix run github:nix-community/nixos-anywhere -- \
  --flake .#$HOST \
  --extra-files "$tmp" \
  --target-host nixos@$TARGET
```

The disk device comes from `hosts/$HOST/disko.nix` (`device = "/dev/nvme0n1"`);
confirm it matches the target before running. `nixos-anywhere` reboots the host
itself once the install finishes.

## 4. Continue bootstrap

The tailnet connection drops on the reboot. After the machine boots to its text
login console, continue from **`install.md` step 6 (First login)** -- the rest
is identical (greetd appears only once the full config is applied in install.md
step 9).
