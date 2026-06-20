# NixOS install runbook (remote, over the tailnet)

Same install as `install.md`, driven from another working machine over the
tailnet for when a console isn't convenient. Only boot + install differ;
post-boot bootstrap is identical -- continue from `install.md` step 6.

```bash
export HOST=sfx14
```

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
  sudo tailscale up --ssh --qr
'
```

Authenticate via the QR / URL. Once `tailscale status` shows the installer, the
console is no longer needed.

## 2. From the working machine: ssh in

```bash
ssh nixos@$HOST
```

Tailscale SSH authenticates by tailnet identity; no password. The live `nixos`
user has passwordless sudo.

## 3. Copy the persistent host key

From the working machine (which has the vault checked out at `~/vault`):

```bash
scp ~/vault/hosts/$HOST/ssh_host_ed25519_key{,.pub} nixos@$HOST:/tmp/
ssh nixos@$HOST 'chmod 600 /tmp/ssh_host_ed25519_key'
```

## 4. Install (remote)

```bash
ssh nixos@$HOST '
  lsblk
  sudo nix run github:nix-community/disko#disko-install -- \
    --flake github:atqamz/universe#'"$HOST"'-minimal --disk main /dev/nvme0n1 \
    --extra-files /tmp/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key \
    --extra-files /tmp/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub \
    --write-efi-boot-entries \
    --system-config "{\"users\":{\"users\":{\"root\":{\"hashedPassword\":\"!\"}}}}"
'
```

Confirm `lsblk` shows the NVMe as `/dev/nvme0n1` before committing.

## 5. Reboot

```bash
ssh nixos@$HOST sudo reboot
```

The tailnet connection drops. After the machine boots to its text login console,
continue from **`install.md` step 6 (First login)** -- the rest is identical
(greetd appears only once the full config is applied in install.md step 9).
