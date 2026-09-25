# pavg15

pavg15 is the only NixOS host managed by Universe.

## Secrets

System secrets under `modules/nixos/secrets` decrypt headlessly from the persistent SSH host key via sops-nix. The personal GPG key remains a recovery/edit recipient. The host key must therefore be restored before rebuilding a replacement server; Vault owns its recovery copy.

## Cache

`atqamz-universe.cachix.org` is the only extra Nix substituter. CI builds the pavg15 toplevel and pushes through the matching Cachix workflow. Do not add a competing GitHub Actions store cache that can make CI green without producing Cachix paths.

## Runner isolation

`hosts/pavg15/runner.nix` owns the self-hosted GitHub runner fleet.

Each runner has its own system user, subordinate IDs, rootless Podman service/socket, work directory, and container state. Workflow jobs do not receive a rootful host container socket. The GitHub App private key stays with the authentication user; runner users receive only short-lived registration material.

Heavy runners may retain trusted warm state. Light runners are disposable. Shared immutable payloads may be reused read-only, while writable tool/container state remains isolated per runner. NVMe under `/var/lib/ci` holds latency-sensitive state; the existing bulk disk holds seek-tolerant disposable state.

Changing the rootless isolation or long-lived credential boundary requires an explicit architecture decision.

## Runner image bumps

GitHub stops sending jobs to a runner version 30 days after the next `actions/runner` release. `hosts/pavg15/runner.nix` pins `myoung34/github-runner` by `imageTag` and `linux/amd64` `imageDigest` and runs it with `DISABLE_AUTO_UPDATE=true`. Self-update cannot replace the pin: the image runs `Runner.Listener run --startuptype service`, so an update exits the listener, `--rm` removes the container, and systemd restarts the old image in a loop.

`.github/workflows/runner-image.yaml` checks daily for a new release and opens or updates one pull request from `bump/runner-image`. It validates the edit with `nix fmt` and `nix flake check` itself, because pull requests made with the workflow token do not trigger `ci.yaml`. It then squash-merges the pull request and deletes the branch; the pull request stays as the audit trail. It fails without merging when `main` moved during the run, because the checks did not cover that merge; the next run rebuilds the bump on the new `main`. It needs "Allow GitHub Actions to create and approve pull requests" enabled in the repository's Actions settings.

The merged image reaches the runners through the auto-upgrade below. The first start of each runner loads the new image, which `TimeoutStartSec = "30min"` covers.

## Auto-upgrade

A CI host must never restart a running job to apply an update, and a Unity build runs for hours. `nixos-upgrade.service` therefore runs hourly with `operation = "boot"`: it builds `main` and makes it the default boot entry. Measured on pavg15, a run with no new commit costs 1.2 to 1.5 s CPU over 5 to 7 s wall time and at most 121 MB memory. A run after `main` moved re-evaluates the flake and costs about 8.7 s CPU over 12 to 14 s and 830 MB.

On success it starts `nixos-live-apply.service`. When `/nix/var/nix/profiles/system` differs from `/run/current-system` and no `Runner.Worker` process exists, it stops every runner unit and runs `nixos-rebuild switch --store-path` on that profile. The switch, and an exit trap if the switch fails, start the runners again. While a runner has a job, it exits successfully without switching, and the next hourly run tries again. The check runs after the build, so the build time is not part of the race window.

`Runner.Worker` exists only while a job runs; an idle runner has only `Runner.Listener`. The check matches the process name with `pgrep -x`, because `pgrep -f` also matches any command line that mentions `Runner.Worker`, such as an SSH session running the check.

One race remains. A job that a listener accepts in the milliseconds between the `pgrep` check and `systemctl stop`, before it starts `Runner.Worker`, is cancelled.

The switch restarts `tailscale-bootstrap.service` when the `tailscaled-autoconnect` or `tailscaled-set` unit changes, because a switch does not otherwise re-apply `services.tailscale.extraSetFlags`.

A kernel, initrd, or kernel module change applies only at the next reboot. `readlink /run/booted-system/kernel /run/current-system/kernel` shows whether one is pending. Reboot only while no runner has a job.

To apply `main` now, on pavg15:

```sh
sudo systemctl start --no-block nixos-upgrade.service
journalctl -fu nixos-upgrade -u nixos-live-apply
```
