# secrets-sync design (issue #4)

Handle how secrets and `password-store` are imported and kept in sync across
devices after a fresh install. The `raw` repo is out of scope (dropped — no
benefit; a separate universe audit issue tracks its removal).

## Goal

One canonical vault, all devices pull from it. A new ssh/gpg key created on any
device flows into the vault and reaches every other device. Rotation is fast. No
regenerate-per-device. The chosen model is **auto-pull, deliberate-push**
(approach A): pulling vault state is automated; pushing key material is a single
deliberate command, because binary SOPS blobs cannot auto-merge on concurrent
rotation and pushing private-key material is security-sensitive.

## Current state

The vault `atqamz/secrets` (checked out at `~/repo/secrets`) is already mature:

- Dual-recipient SOPS on every file: GPG `F1F60517…` (interactive/recovery) +
  one age key per machine (pavg15 `age12gyy…`, sfx14 `age1j6fl…`).
- Scripts: `import.sh` (bootstrap a machine), `export.sh` (re-encrypt live ssh +
  gpg material back into the vault), `decrypt.sh`/`encrypt.sh` (edit text
  secrets).
- Unlock chain: gpg-root (symmetric `gpg/personal.asc.gpg`) → age key
  (`age/keys.txt.gpg`, asymmetric to gpg-root) → SOPS blobs.
- Holds: ssh `config`/`known_hosts`/`authorized_keys` + `yes2infra` deploy key
  (personal ssh identity is the GPG `[A]` auth subkey, not stored); gpg keys
  personal/blankon/password-store/2 deploy; age recovery backup.
- The README notes `import.sh` "Replaces what HM sops-nix used to do at boot" —
  the vault moved off sops-nix to imperative import.

`universe` currently has **zero** nix-managed secrets: `users.nix` sets no
password, wifi PSKs live in NetworkManager imperatively. Tailscale stays a manual
connect (`tailscale up`) — its auth keys go stale every 90 days, so wiring an
authkey secret is not worth the churn.

Fleet: all Linux hosts → NixOS (cachy-os kernel); a MacBook is likely ~2026-09
(nix-darwin); no Windows for dev/work.

## Architecture — three layers

Each layer has a single source of truth and a distinct management mechanism.

| Layer | Contents | Managed by | Cadence |
|-------|----------|-----------|---------|
| **L0 bootstrap** | gpg-root passphrase → age key → gpg keyring + ssh files | imperative (`import.sh`), irreducible | once per new machine |
| **L1 system secrets** | user `hashedPassword` | sops-nix (universe), decrypted at activation | every rebuild, headless |
| **L2 user-session sync** | ssh config/known_hosts/deploy-key, gpg keys, password-store | timer pull + `nix run` push | daily + on-login |

Why the split: a gpg keyring cannot be nix-managed (passphrase / S2K), so L0
stays imperative. Material that is "just a file at a path" and that the system
reads at boot becomes declarative sops-nix (L1). Everything else is user
material that changes over time and rides the sync loop (L2).

## L1 decryptor — host-ssh-age

System secrets must be readable by root at activation **without** waiting on the
user gpg bootstrap. Use the host SSH key (`/etc/ssh/ssh_host_ed25519_key`)
converted to an age recipient via `ssh-to-age`, added to `.sops.yaml` per host.
The host key exists from first boot, so L1 secrets decrypt headlessly with no
dependence on L0. This extends the vault's existing per-device-recipient model
(it already lists one age key per machine; host-ssh-age is simply a recipient
that needs no bootstrap).

Rejected alternative: reuse the user age key (`~/.config/sops/age/keys.txt`).
Works, adds no recipient, but makes system secrets depend on the user gpg
bootstrap completing first — strictly worse for first-boot.

## Components in `universe`

- `flake.nix` — add the `sops-nix` input.
- `modules/nixos/secrets.nix` — sops-nix config: point `sops.age` at the
  host-ssh-age key; declare
  - `sops.secrets.atqa-password` → `users.users.atqa.hashedPasswordFile`
- `modules/home/secrets-sync.nix` — HM systemd **user** timer + service:
  - `secrets-sync.timer`: daily + on-login, `Persistent = true`.
  - `secrets-sync.service`: `git -C ~/repo/secrets pull --ff-only`, then an
    idempotent import of vault → local. Safety rule: if the local working tree
    has un-exported divergence, **skip and notify** rather than clobber.
- flake apps:
  - `nix run .#secrets-export` — wraps `export.sh` + `git commit` + `git push`.
    Deliberate; run after creating/rotating a key.
  - `nix run .#secrets-bootstrap` — clone the vault if absent + run `import.sh`.
    The single entrypoint on a fresh machine.

## Vault changes (`atqamz/secrets`)

Restructuring the vault is explicitly in scope.

- Add `atqa-password.sops.*` (a `mkpasswd` hash).
- `.sops.yaml`: add the host-ssh-age recipient per host; `sops updatekeys` the
  files universe reads.
- Add a `~/.password-store` clone helper (the password-store gpg key
  `E901DCD6…` is already in the vault and imported by `import.sh`); wire it into
  bootstrap + sync.
- Optionally expose a single `sync` entrypoint so universe calls a stable
  interface rather than individual scripts.

## Data flow

- **New machine**: `nix run .#secrets-bootstrap` → prompts for the gpg-root
  passphrase once → age key + gpg keyring + ssh files land → `nixos-rebuild` →
  L1 secrets auto-decrypt via host-ssh-age → the sync timer takes over. One
  manual step; the rest is automatic.
- **Steady state**: create/rotate a key → `nix run .#secrets-export` → push.
  Other devices auto-pull (daily / on-login) and converge.
- **Recipient rotation**: edit `.sops.yaml` + `sops updatekeys` + export. Fast.

## macOS (~2026-09) — forward-compat only

The shell scripts are already portable. When the MacBook arrives, nix-darwin +
home-manager replaces the systemd user timer with a launchd agent; sops-nix has
darwin support. Not built now (YAGNI) — recorded here so the design does not
paint into a Linux-only corner.

## Error handling

- Pull uses `--ff-only` (fails loudly on divergence). Local un-exported
  divergence → skip + desktop notify, never clobber.
- L1 first-boot caveat: the host SSH key is generated during openssh activation,
  so on the very first switch of a brand-new machine the password secret may fail
  to decrypt and succeed on the second switch. Because the only L1 secret is the
  login password, a first-boot decrypt failure could leave the account without a
  password — keep a fallback (`initialHashedPassword` or a one-time recovery
  path) until the host-ssh-age recipient is confirmed working, or pre-generate
  the host key in the installer.

## Testing

- `nix flake check` green.
- CI builds the full toplevel (already in place).
- Verify `sops -d` of an L1 secret succeeds using the host-ssh-age key on the
  target host.
- Dry-run the `secrets-sync.service` and confirm the skip-on-divergence path
  does not overwrite local files.

## Out of scope

- `raw` repo — dropped; tracked by a separate universe audit issue.
- Approach B (full auto bidirectional push) — rejected for concurrent-rotation
  blob conflicts and private-key blast radius.
- A networked/self-hosted vault over tailnet — git + SOPS is the standard and
  already in place.
