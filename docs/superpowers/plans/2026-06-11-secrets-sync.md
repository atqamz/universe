# secrets-sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap and keep ssh/gpg/password-store secrets in sync across devices from one canonical vault, with the login password decrypted headlessly at activation via sops-nix.

**Architecture:** Three layers. **L0** imperative bootstrap (`nix run .#secrets-bootstrap` → clone vault + `import.sh`, one gpg-root passphrase per machine). **L1** sops-nix system secret: `atqa-password` → `hashedPasswordFile`, decrypted at activation by the **host SSH key** converted to an age recipient (`ssh-to-age`), so it needs no user bootstrap. **L2** user-session sync: an HM systemd user timer pulls the vault and runs an idempotent `import.sh` (never clobbers un-exported local changes); pushing is the deliberate `nix run .#secrets-export`.

**Tech Stack:** Nix flakes (flake-parts), sops-nix, SOPS (age + GPG dual recipient), ssh-to-age, home-manager systemd user units, bash.

**Repo split:** L1 password blob lives in **universe** (private repo → sops-encrypted hash is double-protected; pavg15 cannot fetch github at rebuild time, so a committed blob is the only robust option — a private flake input would fail to fetch on-host). The vault `atqamz/secrets` holds L2 user material only and keeps its existing user-age recipients; universe gets a separate `.sops.yaml` with **host-ssh-age** recipients.

---

## File structure

| Path | Repo | Responsibility |
|------|------|----------------|
| `flake.nix` | universe | add `sops-nix` input; import `./parts/apps.nix` |
| `lib/mkHost.nix` | universe | pass `sops-nix.nixosModules.sops` into every host |
| `.sops.yaml` | universe | creation rule for the L1 password blob (host-ssh-age + GPG recovery) |
| `modules/nixos/secrets.nix` | universe | sops-nix: host-key age, `atqa-password` secret → `hashedPasswordFile` |
| `modules/nixos/secrets/atqa-password.sops.yaml` | universe | committed sops-encrypted yescrypt hash |
| `modules/nixos/users.nix` | universe | `hashedPasswordFile` wiring + first-boot fallback |
| `modules/nixos/default.nix` | universe | import `secrets.nix` |
| `modules/home/secrets-sync.nix` | universe | HM user timer + service (pull + idempotent import, skip-on-divergence) |
| `modules/home/default.nix` | universe | import `secrets-sync.nix` |
| `parts/apps.nix` | universe | flake apps `secrets-export`, `secrets-bootstrap` |
| `scripts/import.sh` | vault | add password-store clone-if-absent |

---

## Task 1: Add the sops-nix input and wire it into hosts

**Files:**
- Modify: `flake.nix`
- Modify: `lib/mkHost.nix`

- [ ] **Step 1: Add the input**

In `flake.nix`, add inside `inputs`, after the `home-manager` block (before `caelestia-shell`):

```nix
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

- [ ] **Step 2: Wire the nixos module into every host**

In `lib/mkHost.nix`, add the sops module to the `modules` list, after the home-manager line:

```nix
  modules = [
    ../hosts/${hostname}
    ../modules/nixos
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    {
      nixpkgs.hostPlatform = system;
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        extraSpecialArgs = { inherit inputs; };
        users.atqa = ../modules/home;
      };
    }
  ];
```

- [ ] **Step 3: Lock the input**

Run: `nix flake lock`
Expected: `flake.lock` gains `sops-nix` (+ its `nixpkgs` follows). No other input changes.

- [ ] **Step 4: Commit**

```bash
git add flake.nix flake.lock lib/mkHost.nix
git commit -m "add sops-nix input and wire it into hosts"
```

---

## Task 2: Compute the host-ssh-age recipient and write universe `.sops.yaml`

The L1 password blob must be decryptable by root on pavg15 at activation. The host SSH key (`/etc/ssh/ssh_host_ed25519_key`) exists from first boot; its public half converts to an age recipient with `ssh-to-age`. The GPG primary key `F1F60517` is added as a recovery recipient (interactive edits / lockout recovery).

**Files:**
- Create: `.sops.yaml`

- [ ] **Step 1: Derive the pavg15 host age recipient**

The host pubkey is not secret. Get it and convert (run from sfx14; the pubkey can also be copied off the host):

```bash
ssh atqa@pavg15 'cat /etc/ssh/ssh_host_ed25519_key.pub' \
  | nix run nixpkgs#ssh-to-age
```

Expected: one line `age1...`. Record it as `<PAVG15_HOST_AGE>` for the next step. If the ssh hop is Tailscale-SSH gated, run the `ssh-to-age` pipe directly on pavg15 instead and copy the line back.

- [ ] **Step 2: Write `.sops.yaml`**

Create `.sops.yaml` at the universe repo root. Replace `<PAVG15_HOST_AGE>` with the value from Step 1:

```yaml
# universe holds only L1 system secrets (the login-password hash). Recipients:
# the GPG primary key F1F60517 for interactive edit / lockout recovery, plus one
# HOST ssh key per machine (via ssh-to-age) so root decrypts headlessly at
# activation with no user-gpg bootstrap. This is intentionally a DIFFERENT
# recipient set from the vault's user-age keys.
# Re-run `sops updatekeys <file>` after changing recipients.
creation_rules:
  - path_regex: modules/nixos/secrets/.*\.sops\.yaml$
    pgp: F1F60517602888C8D5E486EB8AD7D4A302EE6771
    age: <PAVG15_HOST_AGE>
```

- [ ] **Step 3: Commit**

```bash
git add .sops.yaml
git commit -m "add sops recipients for host-decrypted system secrets"
```

---

## Task 3: Generate and commit the encrypted login-password hash

**Files:**
- Create: `modules/nixos/secrets/atqa-password.sops.yaml`

- [ ] **Step 1: Generate a yescrypt hash**

Run (you will type the desired login password twice; nothing is echoed):

```bash
nix run nixpkgs#mkpasswd -- -m yescrypt
```

Expected: a `$y$...` string on stdout. Copy it.

- [ ] **Step 2: Create the plaintext, then encrypt in place**

Write the plaintext yaml to a tmp file, encrypt it into the repo path (the creation rule from Task 2 matches the destination path), then shred the plaintext:

```bash
mkdir -p modules/nixos/secrets
umask 077
printf 'atqa-password: %s\n' '<PASTE_YESCRYPT_HASH>' > /tmp/atqa-pw.yaml
sops encrypt --input-type yaml --output-type yaml \
  --filename-override modules/nixos/secrets/atqa-password.sops.yaml \
  /tmp/atqa-pw.yaml > modules/nixos/secrets/atqa-password.sops.yaml
shred -u /tmp/atqa-pw.yaml
```

Note: encrypting requires access to one of the recipients' secret keys is NOT needed (encryption uses public recipients only). It does need the GPG public key `F1F60517` in your keyring and the age recipient string from `.sops.yaml`.

- [ ] **Step 3: Verify the blob is encrypted and well-formed**

Run: `grep -q 'sops:' modules/nixos/secrets/atqa-password.sops.yaml && grep -L '\$y\$' modules/nixos/secrets/atqa-password.sops.yaml`
Expected: both succeed — the file contains a `sops:` metadata block and the cleartext `$y$` hash does NOT appear.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/secrets/atqa-password.sops.yaml
git commit -m "add encrypted login password hash"
```

---

## Task 4: sops-nix module for the login password (L1)

**Files:**
- Create: `modules/nixos/secrets.nix`
- Modify: `modules/nixos/default.nix`
- Modify: `modules/nixos/users.nix`

- [ ] **Step 1: Write `modules/nixos/secrets.nix`**

```nix
_: {
  sops = {
    # Root decrypts with the host SSH key (present from first boot), converted
    # to an age identity internally by sops-nix. No user gpg bootstrap needed.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets.atqa-password = {
      sopsFile = ./secrets/atqa-password.sops.yaml;
      # Decrypted before users are created so it can back hashedPasswordFile.
      neededForUsers = true;
    };
  };
}
```

- [ ] **Step 2: Import it**

In `modules/nixos/default.nix`, add `./secrets.nix` to the `imports` list (after `./users.nix`):

```nix
_: {
  imports = [
    ./nix.nix
    ./boot.nix
    ./network.nix
    ./gpu.nix
    ./desktop.nix
    ./audio.nix
    ./power.nix
    ./users.nix
    ./secrets.nix
    ./locale.nix
  ];
}
```

- [ ] **Step 3: Wire the password file + first-boot fallback in `users.nix`**

The fallback guards the documented first-boot caveat: on a brand-new machine the host key may not yet exist on the very first switch, so the secret could fail to decrypt. `initialHashedPassword` only applies when the account has no password yet, and `hashedPasswordFile` overrides it once decryption works — so it is a safe net, not a permanent backdoor. Generate the fallback hash the same way as Task 3 Step 1 (a throwaway value you change after first login is fine).

```nix
{ config, ... }:
{
  users.users.atqa = {
    isNormalUser = true;
    description = "Atqa Munzir";
    hashedPasswordFile = config.sops.secrets.atqa-password.path;
    # First-boot net: host key may be absent on the very first switch of a new
    # machine, so the sops secret can fail to decrypt once. Remove after the
    # host-ssh-age recipient is confirmed working on every host.
    initialHashedPassword = "<FALLBACK_YESCRYPT_HASH>";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
    ];
  };

  security.sudo.wheelNeedsPassword = false;
}
```

- [ ] **Step 4: Build the host config**

Run: `nix build .#nixosConfigurations.pavg15.config.system.build.toplevel --no-link`
Expected: builds clean (sops-nix activation script is part of the closure). No eval error about missing `sops` options.

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/secrets.nix modules/nixos/default.nix modules/nixos/users.nix
git commit -m "decrypt login password via host key at activation"
```

---

## Task 5: Add the password-store clone to the vault `import.sh`

This runs in the **vault repo** (`~/repo/secrets`), not universe. The password-store GPG key `E901DCD6…` is already imported by `import.sh`; this adds the repo checkout so `pass` works after bootstrap.

**Files:**
- Modify: `~/repo/secrets/scripts/import.sh`

- [ ] **Step 1: Append the clone block**

Before the final `echo "Done."` in `scripts/import.sh`, add:

```bash
# 4. password-store — the signing/encryption gpg key (E901DCD6) is imported
#    above; clone the store itself if it is not already present. Idempotent.
PASS_DIR="$HOME/.password-store"
if [ -d "$PASS_DIR/.git" ]; then
  echo "==> password-store present, skip"
else
  echo "==> cloning password-store"
  git clone git@github.com:atqamz/password-store "$PASS_DIR"
fi
```

- [ ] **Step 2: Syntax-check**

Run: `bash -n scripts/import.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Commit (in the vault repo)**

```bash
git -C ~/repo/secrets add scripts/import.sh
git -C ~/repo/secrets commit -m "clone password-store during import"
git -C ~/repo/secrets push
```

---

## Task 6: HM user timer + service for L2 sync

**Files:**
- Create: `modules/home/secrets-sync.nix`
- Modify: `modules/home/default.nix`

- [ ] **Step 1: Write `modules/home/secrets-sync.nix`**

The service refuses to clobber: if the vault working tree has un-exported local changes it notifies and exits 0. Otherwise it fast-forwards both repos and re-runs the idempotent `import.sh`. `import.sh` exports `SOPS_AGE_KEY_FILE` itself and skips already-present gpg/age roots, so steady-state runs are fully headless.

```nix
{ pkgs, ... }:
let
  vault = "$HOME/repo/secrets";
  sync = pkgs.writeShellApplication {
    name = "secrets-sync";
    runtimeInputs = with pkgs; [
      git
      gnupg
      sops
      age
      coreutils
      libnotify
    ];
    text = ''
      vault="${vault}"
      if [ ! -d "$vault/.git" ]; then
        echo "vault not bootstrapped; run: nix run .#secrets-bootstrap" >&2
        exit 0
      fi

      # Never clobber un-exported local key material.
      if [ -n "$(git -C "$vault" status --porcelain)" ]; then
        notify-send "secrets-sync" "local vault changes — run 'nix run .#secrets-export'" || true
        echo "vault dirty, skipping pull" >&2
        exit 0
      fi

      git -C "$vault" pull --ff-only
      ( cd "$vault" && ./scripts/import.sh )

      # Fast-forward the password store too, if present.
      if [ -d "$HOME/.password-store/.git" ]; then
        git -C "$HOME/.password-store" pull --ff-only || true
      fi
    '';
  };
in
{
  systemd.user.services.secrets-sync = {
    Unit.Description = "Pull canonical vault and import secrets";
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/secrets-sync";
    };
  };

  systemd.user.timers.secrets-sync = {
    Unit.Description = "Periodic secrets vault sync";
    Timer = {
      OnStartupSec = "2min";
      OnUnitActiveSec = "1d";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
```

- [ ] **Step 2: Import it**

In `modules/home/default.nix`, add `./secrets-sync.nix` to `imports` (after `./yazi.nix`):

```nix
  imports = [
    ./packages.nix
    ./caelestia.nix
    ./clipboard.nix
    ./hypr.nix
    ./cursor.nix
    ./yazi.nix
    ./secrets-sync.nix
  ];
```

- [ ] **Step 3: Build and inspect the generated unit**

Run:
```bash
nix build .#nixosConfigurations.pavg15.config.system.build.toplevel --no-link && \
nix eval --raw .#nixosConfigurations.pavg15.config.home-manager.users.atqa.systemd.user.services.secrets-sync.Service.ExecStart
```
Expected: builds clean; prints a `/nix/store/...secrets-sync/bin/secrets-sync` path.

- [ ] **Step 4: Commit**

```bash
git add modules/home/secrets-sync.nix modules/home/default.nix
git commit -m "add user timer to sync secrets vault"
```

---

## Task 7: Flake apps — `secrets-export` and `secrets-bootstrap`

**Files:**
- Create: `parts/apps.nix`
- Modify: `flake.nix`

- [ ] **Step 1: Write `parts/apps.nix`**

`secrets-export` is the deliberate push (re-encrypt live material, commit, push). `secrets-bootstrap` is the single fresh-machine entrypoint (clone vault if absent, then `import.sh`, which prompts for the gpg-root passphrase once).

```nix
_: {
  perSystem =
    { pkgs, ... }:
    let
      vault = "$HOME/repo/secrets";
      rt = with pkgs; [
        git
        gnupg
        sops
        age
        coreutils
      ];

      export = pkgs.writeShellApplication {
        name = "secrets-export";
        runtimeInputs = rt;
        text = ''
          vault="${vault}"
          cd "$vault" || exit 1
          ./scripts/export.sh
          git add -A
          if git diff --cached --quiet; then
            echo "nothing to export"
            exit 0
          fi
          git commit -m "export live secrets"
          git push
        '';
      };

      bootstrap = pkgs.writeShellApplication {
        name = "secrets-bootstrap";
        runtimeInputs = rt;
        text = ''
          vault="${vault}"
          if [ ! -d "$vault/.git" ]; then
            echo "==> cloning vault"
            mkdir -p "$(dirname "$vault")"
            git clone git@github.com:atqamz/secrets "$vault"
          fi
          cd "$vault" || exit 1
          ./scripts/import.sh
        '';
      };
    in
    {
      apps.secrets-export = {
        type = "app";
        program = "${export}/bin/secrets-export";
      };
      apps.secrets-bootstrap = {
        type = "app";
        program = "${bootstrap}/bin/secrets-bootstrap";
      };
    };
}
```

- [ ] **Step 2: Import the part**

In `flake.nix`, add `./parts/apps.nix` to the `imports` list (after `./parts/hosts.nix`):

```nix
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks-nix.flakeModule
        ./parts/formatter.nix
        ./parts/checks.nix
        ./parts/devshells.nix
        ./parts/hosts.nix
        ./parts/apps.nix
      ];
```

- [ ] **Step 3: Verify the apps resolve**

Run: `nix flake show 2>/dev/null | grep -A3 apps`
Expected: lists `secrets-export` and `secrets-bootstrap` under `apps.x86_64-linux`.

- [ ] **Step 4: Commit**

```bash
git add parts/apps.nix flake.nix
git commit -m "add secrets-export and secrets-bootstrap apps"
```

---

## Task 8: Integration verification and deploy

**Files:** none (verification + deploy only).

- [ ] **Step 1: Full flake check**

Run: `nix flake check`
Expected: green (treefmt/statix/deadnix clean, all configs evaluate). Fix any formatting the pre-commit hooks flag, then re-commit.

- [ ] **Step 2: Build the toplevel**

Run: `nix build .#nixosConfigurations.pavg15.config.system.build.toplevel --no-link`
Expected: clean build.

- [ ] **Step 3: Deploy to pavg15** (per the canonical offline path — host cannot fetch github)

```bash
rsync -a --delete /home/atqa/universe/.git/ atqa@pavg15:/home/atqa/universe/.git/
ssh atqa@pavg15 'git -C /home/atqa/universe reset --hard HEAD'
ssh atqa@pavg15 'sudo nixos-rebuild switch --flake /home/atqa/universe#pavg15'
```
Expected: switch succeeds; a new generation is created.

- [ ] **Step 4: Verify L1 decrypts on the host**

Run: `ssh atqa@pavg15 'sudo cat /run/secrets-for-users/atqa-password'`
Expected: prints the `$y$...` yescrypt hash (sops-nix decrypted it with the host key). If it fails on a brand-new machine, run the switch a second time (host key now present) — the `initialHashedPassword` fallback keeps the account usable in between.

- [ ] **Step 5: Verify the login password actually works**

On the pavg15 console (or `su atqa` from another session), confirm the chosen password authenticates. Only after this is confirmed on every host, remove `initialHashedPassword` from `users.nix` in a follow-up commit.

- [ ] **Step 6: Dry-run the sync service (must not clobber)**

```bash
ssh atqa@pavg15 'systemctl --user start secrets-sync.service && journalctl --user -u secrets-sync.service -n 20 --no-pager'
```
Expected: either a clean fast-forward + import, or — if the vault tree is dirty — the "local vault changes" skip message and exit 0. Confirm `~/.ssh/config` etc. were not overwritten when dirty.

- [ ] **Step 7: Open the PR**

```bash
git push -u origin 4-secrets-sync
gh pr create --assignee atqamz \
  --title "handle secrets and password-store sync after fresh install" \
  --body "$(cat <<'EOF'
## Summary
- Bootstrap + cross-device sync for ssh/gpg/password-store from the canonical `atqamz/secrets` vault (auto-pull, deliberate-push).
- Login password decrypted headlessly at activation via sops-nix + host-ssh-age (`atqa-password` → `hashedPasswordFile`).
- Flake apps `secrets-bootstrap` (fresh machine) and `secrets-export` (deliberate push); HM user timer for daily/on-login pull with skip-on-divergence.

Fixes #4

## Test plan
- `nix flake check` green; toplevel builds.
- Deployed to pavg15; `sops`-decrypted `atqa-password` present at `/run/secrets-for-users/atqa-password`; login password authenticates.
- `secrets-sync.service` dry-run fast-forwards or skips-on-divergence without clobbering local files.
EOF
)"
```
Expected: PR opens against `master`, assigned to atqamz, CI starts.

---

## Notes for the implementer

- **Do not** `--no-verify` or `--no-gpg-sign` any commit. Pre-commit hooks (treefmt/statix/deadnix) run on commit; if they reformat, `git add` the result and re-commit.
- The host age recipient (Task 2) is per-host. When a second host (sfx14, future MacBook) joins, add its host-ssh-age line to `.sops.yaml`, run `sops updatekeys modules/nixos/secrets/atqa-password.sops.yaml`, and commit.
- macOS later: replace the systemd user timer with a launchd agent (sops-nix + nix-darwin support it); the apps and scripts are already portable. Out of scope now.
- The `raw` repo is intentionally excluded; its removal is a separate universe audit issue.
