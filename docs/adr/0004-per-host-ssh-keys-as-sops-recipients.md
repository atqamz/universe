# 0004. Per-host SSH keys decrypt system secrets headlessly

## Context

`atqa-password` must be decrypted at activation, before any user has logged in.
A user-held age or GPG key cannot be used, because nothing can unlock it at that point.

## Decision

Recipients for `modules/nixos/secrets/*.sops.yaml` are the per-host SSH host keys via `ssh-to-age`, plus the GPG primary key for interactive edit and lockout recovery.
This is deliberately a different recipient set from the vault repo, which uses user-age keys.

Host keys are persistent per host, backed up in `~/vault/hosts/<host>/`, and re-injected on reinstall with `--extra-files`, so a secret is encrypted to a host once and never rekeyed.

## Consequence

A reinstall that skips the key injection leaves the machine unable to decrypt the login password, which surfaces as a failed first login.
`docs/runbooks/install.md` step 3 exists for this, and its troubleshooting section keys on it.
Recipient and rotation detail lives at the top of `.sops.yaml`.
